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
      await _tts.awaitSpeakCompletion(true);
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
