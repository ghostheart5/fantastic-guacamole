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

class PluginSpeechRecognitionService implements SpeechRecognitionService {
  final SpeechToText _speech = SpeechToText();
  bool _initialized = false;
  void Function()? _onDone;

  // A forgotten-open mic must not run indefinitely.
  static const Duration _listenFor = Duration(seconds: 30);
  static const Duration _pauseFor = Duration(seconds: 3);

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
        onError: (_) => _onDone?.call(),
        onStatus: (String status) {
          if (status == 'done' || status == 'notListening') {
            _onDone?.call();
          }
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
    if (!_initialized) {
      onDone();
      return;
    }
    _onDone = onDone;
    try {
      await _speech.listen(
        onResult: (SpeechRecognitionResult result) {
          onResult(result.recognizedWords, result.finalResult);
        },
        listenOptions: SpeechListenOptions(
          listenMode: ListenMode.confirmation,
          listenFor: _listenFor,
          pauseFor: _pauseFor,
        ),
      );
    } catch (_) {
      onDone();
    }
  }

  @override
  Future<void> stop() async {
    _onDone = null;
    if (!_initialized) {
      return;
    }
    try {
      await _speech.stop();
    } catch (_) {
      // Ignore plugin-level failures.
    }
  }

  @override
  Future<void> cancel() async {
    _onDone = null;
    if (!_initialized) {
      return;
    }
    try {
      await _speech.cancel();
    } catch (_) {
      // Ignore plugin-level failures.
    }
  }
}
