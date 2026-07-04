import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:flutter_tts/flutter_tts.dart';

class VoiceService {
  final FlutterTts _tts = FlutterTts();
  bool _speaking = false;
  Future<void>? _initFuture;

  bool get isSpeaking => _speaking;

  Future<void> _ensureInit() => _initFuture ??= _doInit();

  Future<void> _doInit() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.45);
    await _tts.setPitch(1.05);
    await _tts.setVolume(1.0);
    await _tts.awaitSpeakCompletion(true);
    _tts.setStartHandler(() => _speaking = true);
    _tts.setCompletionHandler(() => _speaking = false);
    _tts.setCancelHandler(() => _speaking = false);
    _tts.setErrorHandler((msg) {
      _speaking = false;
      Logger.error('[VoiceService] TTS error', msg);
    });
  }

  Future<void> speak(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    await _ensureInit();
    if (_speaking) await _tts.stop();
    await _tts.speak(trimmed);
  }

  Future<void> stop() async {
    await _ensureInit();
    await _tts.stop();
    _speaking = false;
  }

  Future<void> pause() async {
    await _ensureInit();
    await _tts.pause();
  }

  Future<void> setLanguage(String language) async {
    await _ensureInit();
    await _tts.setLanguage(language);
  }

  Future<void> setVolume(double volume) async {
    await _ensureInit();
    await _tts.setVolume(volume);
  }

  Future<void> setRate(double rate) async {
    await _ensureInit();
    await _tts.setSpeechRate(rate);
  }

  Future<void> setPitch(double pitch) async {
    await _ensureInit();
    await _tts.setPitch(pitch);
  }
}
