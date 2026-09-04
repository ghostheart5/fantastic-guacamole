import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:flutter/services.dart';

class VoiceService {
  const VoiceService();

  static const MethodChannel _tts = MethodChannel('chronospark/tts');
  static bool _initialized = false;
  static bool _isSpeaking = false;

  /// Serialises [speak] so two utterances cannot interleave.
  ///
  /// Native TTS completes the `speak` method when the utterance finishes, so
  /// two rapid taps otherwise race stop/speak(A)/stop/speak(B) with A's
  /// completer still pending. Every call site is fire-and-forget, so nothing
  /// else rate-limits them.
  static Future<void> _speakQueue = Future<void>.value();

  bool get isSpeaking => _isSpeaking;

  Future<void> speak(String text) async {
    await speakChecked(text);
  }

  Future<bool> speakChecked(String text) async {
    final String value = text.trim();
    if (value.isEmpty) {
      return false;
    }
    if (!await _ensureInitialized()) {
      return false;
    }
    bool succeeded = true;
    // Chain onto the previous utterance rather than racing it. Errors are
    // absorbed so one bad utterance cannot poison the queue for the session.
    final Future<void> queued = _speakQueue.then((_) async {
      try {
        await _tts.invokeMethod<void>('stop');
        _isSpeaking = true;
        await _tts.invokeMethod<void>('speak', <String, Object?>{
          'text': value,
        });
      } catch (error) {
        succeeded = false;
        Logger.errorCode(
          code: AppDiagnosticCode.voicePlaybackFailed,
          debugMessage: 'VoiceService playback failed.',
          exception: error,
        );
      } finally {
        _isSpeaking = false;
      }
    });
    _speakQueue = queued.catchError((Object _) {});
    await queued;
    return succeeded;
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
    if (!_initialized) {
      return;
    }
    try {
      await _tts.invokeMethod<void>('stop');
      _isSpeaking = false;
    } catch (_) {
      // Ignore platform-level failures.
    }
  }

  Future<void> pause() async {
    if (!_initialized) {
      return;
    }
    try {
      await _tts.invokeMethod<void>('pause');
      _isSpeaking = false;
    } catch (_) {
      // Ignore platform-level failures.
    }
  }

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
