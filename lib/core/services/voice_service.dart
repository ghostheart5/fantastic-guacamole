import 'package:flutter_tts/flutter_tts.dart';

class VoiceService {
  final FlutterTts _tts = FlutterTts();
  bool _speaking = false;

  bool get isSpeaking => _speaking;

  Future<void> init() async {
    await _tts.awaitSpeakCompletion(true);
    _tts.setStartHandler(() => _speaking = true);
    _tts.setCompletionHandler(() => _speaking = false);
    _tts.setCancelHandler(() => _speaking = false);
    _tts.setErrorHandler((_) => _speaking = false);
  }

  Future<void> speak(String text) async {
    await _tts.speak(text);
  }

  Future<void> stop() async {
    await _tts.stop();
  }

  Future<void> pause() async {
    await _tts.pause();
  }

  Future<void> setLanguage(String language) async {
    await _tts.setLanguage(language);
  }

  Future<void> setVolume(double volume) async {
    await _tts.setVolume(volume);
  }

  Future<void> setRate(double rate) async {
    await _tts.setSpeechRate(rate);
  }

  Future<void> setPitch(double pitch) async {
    await _tts.setPitch(pitch);
  }
}
