import 'package:fantastic_guacamole/config/env.dart';
import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class VoiceService {
  const VoiceService();

  static const MethodChannel _tts = MethodChannel('chronospark/tts');
  static bool _initialized = false;
  static final ValueNotifier<bool> _playback = ValueNotifier<bool>(false);
  static int _generation = 0;

  // Serialize native operations, not whole utterances. Stop must never wait
  // for a long response to finish, and superseded requests must not restart.
  static Future<void> _operations = Future<void>.value();

  bool get isSpeaking => _playback.value;
  ValueListenable<bool> get playback => _playback;

  Future<void> _enqueue(Future<void> Function() operation) {
    final Future<void> pending = _operations.then((_) => operation());
    _operations = pending.catchError((Object _) {});
    return pending;
  }

  Future<void> speak(String text) async {
    await speakChecked(text);
  }

  Future<bool> speakChecked(String text) async {
    final String value = text.trim();
    if (value.isEmpty) {
      return false;
    }
    final int generation = ++_generation;
    _playback.value = true;
    Future<bool>? completion;
    try {
      await _enqueue(() async {
        if (generation != _generation || !await _ensureInitialized()) return;
        if (generation != _generation) return;
        await _tts.invokeMethod<void>('stop');
        if (generation != _generation) return;
        completion = _tts
            .invokeMethod<void>('speak', <String, Object?>{'text': value})
            .then(
              (_) => true,
              onError: (Object error) {
                _reportPlaybackFailure(error);
                return false;
              },
            );
      });
      // Cancellation is a successful user action, not an unavailable engine.
      // Existing speakChecked callers show an error when this returns false.
      if (generation != _generation) return true;
      return completion == null ? false : await completion!;
    } catch (error) {
      _reportPlaybackFailure(error);
      return false;
    } finally {
      if (generation == _generation) _playback.value = false;
    }
  }

  void _reportPlaybackFailure(Object error) {
    Logger.errorCode(
      code: AppDiagnosticCode.voicePlaybackFailed,
      debugMessage: 'VoiceService playback failed.',
      exception: error,
    );
  }

  Future<void> speakSummary({
    required String title,
    required List<String> points,
  }) {
    final String cleanedTitle = title.trim();
    final List<String> cleanedPoints = points
        .map((String item) => item.trim())
        .where((String item) => item.isNotEmpty)
        .toList(growable: false);
    if (cleanedPoints.isEmpty) {
      return speak(
        cleanedTitle.isEmpty
            ? 'No summary available.'
            : '$cleanedTitle. No summary available.',
      );
    }
    final StringBuffer buffer = StringBuffer();
    if (cleanedTitle.isNotEmpty) {
      buffer.write('$cleanedTitle. ');
    }
    for (int i = 0; i < cleanedPoints.length; i++) {
      buffer.write('Point ${i + 1}. ${cleanedPoints[i]}. ');
    }
    return speak(buffer.toString());
  }

  Future<void> speakAccessibilityHint({
    required String surface,
    required List<String> controls,
  }) {
    final String surfaceName = surface.trim().isEmpty
        ? 'this screen'
        : surface.trim();
    final List<String> items = controls
        .map((String item) => item.trim())
        .where((String item) => item.isNotEmpty)
        .toList(growable: false);
    if (items.isEmpty) {
      return speak('Accessibility guide for $surfaceName is unavailable.');
    }
    return speakSummary(
      title: 'Accessibility guide for $surfaceName',
      points: items,
    );
  }

  Future<void> stop() async {
    ++_generation;
    _playback.value = false;
    try {
      await _enqueue(() async {
        if (_initialized) await _tts.invokeMethod<void>('stop');
      });
    } catch (_) {
      // Ignore platform-level failures.
    }
  }

  Future<void> pause() => stop();

  Future<void> setLanguage(String language) async {
    if (!await _ensureInitialized()) {
      return;
    }
    try {
      await _tts.invokeMethod<void>('setLanguage', language);
    } catch (_) {
      // Ignore platform-level failures.
    }
  }

  Future<void> setVolume(double volume) async {
    if (!await _ensureInitialized()) {
      return;
    }
    try {
      await _tts.invokeMethod<void>('setVolume', volume.clamp(0.0, 1.0));
    } catch (_) {
      // Ignore platform-level failures.
    }
  }

  Future<void> setRate(double rate) async {
    if (!await _ensureInitialized()) {
      return;
    }
    try {
      await _tts.invokeMethod<void>('setRate', rate.clamp(0.0, 1.0));
    } catch (_) {
      // Ignore platform-level failures.
    }
  }

  Future<void> setPitch(double pitch) async {
    if (!await _ensureInitialized()) {
      return;
    }
    try {
      await _tts.invokeMethod<void>('setPitch', pitch.clamp(0.5, 2.0));
    } catch (_) {
      // Ignore platform-level failures.
    }
  }

  Future<bool> _ensureInitialized() async {
    if (!Env.cloudServicesEnabled) return false;
    if (_initialized) {
      return true;
    }
    try {
      await _tts.invokeMethod<void>('initialize');
      await _tts.invokeMethod<void>('setLanguage', 'en-US');
      _initialized = true;
      return true;
    } on MissingPluginException {
      return false;
    } on PlatformException catch (error, stackTrace) {
      Logger.errorCode(
        code: AppDiagnosticCode.voiceInitializationUnavailable,
        debugMessage: 'VoiceService is unavailable.',
        exception: error,
        stackTrace: stackTrace,
      );
      return false;
    } catch (_) {
      return false;
    }
  }
}
