import 'dart:async';

import 'package:fantastic_guacamole/config/env.dart';
import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Speech-to-text abstraction, mirroring [VoiceService]'s wrap-and-degrade
/// pattern so callers never crash when no recognition
/// engine is present, and so tests can substitute a fake instead of driving
/// the real platform channel.
abstract class SpeechRecognitionService {
  bool get isListening;

  Future<bool> initialize();

  /// Starts listening. [onResult] fires with the current best transcript.
  /// [onDone] fires exactly once when listening stops for any reason other
  /// than a caller-driven [stop]/[cancel] — e.g. the bounded timeout or
  /// silence window elapsing — so a caller can reset UI state even if the
  /// user never taps again.
  Future<void> listen({
    required void Function(String text, bool isFinal) onResult,
    required void Function() onDone,
  });

  Future<void> stop();

  Future<void> cancel();
}

/// Deliberately excludes native messages, recognizer details, and transcripts.
class SpeechRecognitionFailure implements Exception {
  const SpeechRecognitionFailure(this.operation);

  final String operation;

  @override
  String toString() => 'Speech recognition $operation failed.';
}

class PluginSpeechRecognitionService implements SpeechRecognitionService {
  factory PluginSpeechRecognitionService({SpeechToText? speech}) =>
      speech == null ? _shared : PluginSpeechRecognitionService._(speech);

  PluginSpeechRecognitionService._(this._speech);

  // SpeechToText itself is a singleton and retains the first initialize
  // callbacks. Keep its production adapter alive with those callbacks too.
  static final PluginSpeechRecognitionService _shared =
      PluginSpeechRecognitionService._(SpeechToText());

  final SpeechToText _speech;
  bool _initialized = false;
  bool _starting = false;
  bool _ending = false;
  bool _cleanupRequired = false;
  Future<void>? _endPending;
  _RecognitionSession? _session;

  // A forgotten-open mic must not run indefinitely.
  static const Duration _listenFor = Duration(seconds: 30);
  static const Duration _pauseFor = Duration(seconds: 3);
  static const Duration _terminalTimeout = Duration(seconds: 5);
  static const Duration _startupTimeout = Duration(seconds: 5);

  @override
  bool get isListening => _speech.isListening;

  @override
  Future<bool> initialize() async {
    if (!Env.cloudServicesEnabled) return false;
    if (_initialized) {
      return true;
    }
    try {
      final bool available = await _speech.initialize(
        onError: (_) {
          final session = _session;
          if (session == null) return;
          session.failed = true;
          _finish(session);
        },
        onStatus: (String status) {
          final session = _session;
          if (session == null) return;
          if (status == SpeechToText.listeningStatus) {
            session.acknowledge();
            return;
          }
          // notListening precedes the final transcript. The package emits
          // done after the final result, or when there is no result to deliver.
          if (status != SpeechToText.doneStatus) return;
          _finish(session);
        },
      );
      _initialized = available;
      return available;
    } on MissingPluginException {
      return false;
    } on PlatformException catch (error, stackTrace) {
      Logger.errorCode(
        code: AppDiagnosticCode.speechRecognitionInitializationUnavailable,
        debugMessage: 'Speech recognition is unavailable.',
        exception: error,
        stackTrace: stackTrace,
      );
      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> listen({
    required void Function(String text, bool isFinal) onResult,
    required void Function() onDone,
  }) async {
    if (!_initialized ||
        _starting ||
        _ending ||
        _cleanupRequired ||
        _session != null) {
      throw const SpeechRecognitionFailure('listen');
    }
    final session = _RecognitionSession(onResult, onDone);
    _session = session;
    _starting = true;
    try {
      await _speech.listen(
        onResult: (SpeechRecognitionResult result) {
          if (!identical(_session, session)) return;
          session.acknowledge();
          if (session.suppressed) return;
          session.onResult(result.recognizedWords, result.finalResult);
        },
        listenOptions: SpeechListenOptions(
          listenMode: ListenMode.confirmation,
          listenFor: _listenFor,
          pauseFor: _pauseFor,
        ),
      );
      // speech_to_text discards a native `listen: false` return. Require a
      // listening/result/terminal acknowledgement instead of trusting the
      // completed platform method or checking a possibly delayed status once.
      await session.acknowledged.future.timeout(_startupTimeout);
      if (session.failed) throw const SpeechRecognitionFailure('listen');
      if (session.suppressed) {
        // A stop/cancel can settle before an in-flight native listen activates.
        // Cancel that late activation before allowing another adapter session.
        await _speech.cancel();
      }
    } catch (_) {
      session.suppressed = true;
      try {
        await _speech.cancel();
        _cleanupRequired = false;
      } catch (_) {
        // Do not allow another session after an unconfirmed native cleanup.
        // The controller receives the startup failure and can retry cancel.
        _cleanupRequired = true;
      }
      _finish(session);
      throw const SpeechRecognitionFailure('listen');
    } finally {
      _starting = false;
    }
  }

  @override
  Future<void> stop() => _end(cancel: false);

  @override
  Future<void> cancel() => _end(cancel: true);

  Future<void> _end({required bool cancel}) {
    return _endPending ??= _endNative(cancel: cancel).whenComplete(() {
      _endPending = null;
    });
  }

  Future<void> _endNative({required bool cancel}) async {
    _ending = true;
    final session = _session;
    if (session != null) session.suppressed = true;
    try {
      if (!_initialized) return;
      if (cancel) {
        await _speech.cancel();
        _cleanupRequired = false;
        if (session != null) _finish(session);
      } else {
        await _speech.stop();
        // A stop acknowledgement is not the final-result acknowledgement.
        // Keep callbacks attached to this session until its terminal event.
        if (session != null) {
          await session.terminal.future.timeout(_terminalTimeout);
        }
        if (_cleanupRequired) throw const SpeechRecognitionFailure('stop');
      }
    } catch (_) {
      _cleanupRequired = true;
      throw SpeechRecognitionFailure(cancel ? 'cancel' : 'stop');
    } finally {
      _ending = false;
    }
  }

  void _finish(_RecognitionSession session) {
    if (session.terminal.isCompleted) return;
    session.acknowledge();
    session.terminal.complete();
    if (identical(_session, session)) _session = null;
    if (!session.suppressed) session.onDone();
  }
}

class _RecognitionSession {
  _RecognitionSession(this.onResult, this.onDone);

  final void Function(String text, bool isFinal) onResult;
  final void Function() onDone;
  final Completer<void> terminal = Completer<void>();
  final Completer<void> acknowledged = Completer<void>();
  bool suppressed = false;
  bool failed = false;

  void acknowledge() {
    if (!acknowledged.isCompleted) acknowledged.complete();
  }
}
