import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

class VoiceService {
  const VoiceService();

  static final FlutterTts _tts = FlutterTts();
  static bool _initialized = false;
  static bool _isSpeaking = false;

  bool get isSpeaking => _isSpeaking;

  Future<void> speak(String text) async {
    final String value = text.trim();
    if (value.isEmpty) {
      return;
    }
    if (!await _ensureInitialized()) {
      return;
    }
    try {
      await _tts.stop();
      await _tts.speak(value);
    } catch (_) {
      // Do not crash UI flows when TTS is unavailable.
    }
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
    if (!await _ensureInitialized()) {
      return;
    }
    try {
      await _tts.stop();
      _isSpeaking = false;
    } catch (_) {
      // Ignore plugin-level failures.
    }
  }

  Future<void> pause() async {
    if (!await _ensureInitialized()) {
      return;
    }
    try {
      await _tts.pause();
      _isSpeaking = false;
    } catch (_) {
      // Ignore plugin-level failures.
    }
  }

  Future<void> setLanguage(String language) async {
    if (!await _ensureInitialized()) {
      return;
    }
    try {
      await _tts.setLanguage(language);
    } catch (_) {
      // Ignore plugin-level failures.
    }
  }

  Future<void> setVolume(double volume) async {
    if (!await _ensureInitialized()) {
      return;
    }
    try {
      await _tts.setVolume(volume.clamp(0.0, 1.0));
    } catch (_) {
      // Ignore plugin-level failures.
    }
  }

  Future<void> setRate(double rate) async {
    if (!await _ensureInitialized()) {
      return;
    }
    try {
      await _tts.setSpeechRate(rate.clamp(0.0, 1.0));
    } catch (_) {
      // Ignore plugin-level failures.
    }
  }

  Future<void> setPitch(double pitch) async {
    if (!await _ensureInitialized()) {
      return;
    }
    try {
      await _tts.setPitch(pitch.clamp(0.5, 2.0));
    } catch (_) {
      // Ignore plugin-level failures.
    }
  }

  Future<bool> _ensureInitialized() async {
    if (_initialized) {
      return true;
    }
    try {
      _tts.setStartHandler(() {
        _isSpeaking = true;
      });
      _tts.setCompletionHandler(() {
        _isSpeaking = false;
      });
      _tts.setCancelHandler(() {
        _isSpeaking = false;
      });
      _tts.setErrorHandler((_) {
        _isSpeaking = false;
      });
      try {
        await _tts.awaitSpeakCompletion(true);
      } catch (_) {
        // Some devices/plugins throw on completion wiring; continue with best effort.
      }
      try {
        await _tts.setLanguage('en-US');
      } catch (_) {
        // Keep default engine language if explicit locale is unavailable.
      }
      _initialized = true;
      return true;
    } on MissingPluginException {
      return false;
    } on PlatformException catch (error) {
      debugPrint('VoiceService unavailable: $error');
      return false;
    } catch (_) {
      return false;
    }
  }
}
