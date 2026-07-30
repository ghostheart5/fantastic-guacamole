import 'package:flutter_tts/flutter_tts.dart';

class VoiceService {
  VoiceService({FlutterTts? tts}) : _tts = tts ?? FlutterTts() {
    _tts.setStartHandler(() {
      _isSpeaking = true;
    });

    _tts.setCompletionHandler(() {
      _isSpeaking = false;
    });

    _tts.setCancelHandler(() {
      _isSpeaking = false;
    });

    _tts.setPauseHandler(() {
      _isSpeaking = false;
    });

    _tts.setErrorHandler((message) {
      _isSpeaking = false;
    });
  }

  final FlutterTts _tts;

  bool _isSpeaking = false;
  String _language = 'en-US';
  double _volume = 1.0;
  double _rate = 0.48;
  double _pitch = 1.0;

  bool get isSpeaking => _isSpeaking;

  Future<void> speak(String text) async {
    final String message = text.trim();
    if (message.isEmpty) {
      return;
    }

    await stop();
    await _tts.setLanguage(_language);
    await _tts.setVolume(_volume.clamp(0.0, 1.0));
    await _tts.setSpeechRate(_rate.clamp(0.1, 1.0));
    await _tts.setPitch(_pitch.clamp(0.5, 2.0));
    await _tts.speak(message);
  }

  Future<void> speakSummary({
    required String title,
    required List<String> points,
  }) async {
    final String summary = <String>[
      title,
      ...points,
    ].where((String value) => value.trim().isNotEmpty).join('. ');

    await speak(summary);
  }

  Future<void> speakAccessibilityHint({
    required String surface,
    required List<String> controls,
  }) async {
    final String hint = <String>[
      surface,
      ...controls,
    ].where((String value) => value.trim().isNotEmpty).join('. ');

    await speak(hint);
  }

  Future<void> stop() async {
    _isSpeaking = false;
    await _tts.stop();
  }

  Future<void> pause() async {
    _isSpeaking = false;
    await _tts.pause();
  }

  Future<void> setLanguage(String language) async {
    final String next = language.trim();
    if (next.isEmpty) {
      return;
    }

    _language = next;
    await _tts.setLanguage(_language);
  }

  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    await _tts.setVolume(_volume);
  }

  Future<void> setRate(double rate) async {
    _rate = rate.clamp(0.1, 1.0);
    await _tts.setSpeechRate(_rate);
  }

  Future<void> setPitch(double pitch) async {
    _pitch = pitch.clamp(0.5, 2.0);
    await _tts.setPitch(_pitch);
  }
}
