import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class AudioService {
  static final AudioPlayer _player = AudioPlayer();
  static final AudioPlayer _typingPlayer = AudioPlayer();
  static bool _configured = false;
  static DateTime _lastTypingAt = DateTime.fromMillisecondsSinceEpoch(0);

  static Future<void> _ensureConfigured() async {
    if (_configured) {
      return;
    }

    await _player.setReleaseMode(ReleaseMode.stop);
    await _typingPlayer.setReleaseMode(ReleaseMode.stop);
    _configured = true;
  }

  static Future<void> play(String path, bool enabled) async {
    if (!enabled) {
      return;
    }
    try {
      await _ensureConfigured();
      await _player.stop();
      await _player.play(AssetSource(path));
    } catch (e, s) {
      debugPrint('AudioService: failed to play $path: $e');
      debugPrintStack(stackTrace: s);
    }
  }

  static Future<void> playTyping() async {
    final DateTime now = DateTime.now();
    if (now.difference(_lastTypingAt).inMilliseconds < 65) {
      return;
    }
    _lastTypingAt = now;

    try {
      await _ensureConfigured();
      await _typingPlayer.stop();
      await _typingPlayer.setVolume(0.2);
      await _typingPlayer.play(AssetSource('audio/ai_decision.wav'));
    } catch (e, s) {
      debugPrint('AudioService: failed to play typing sound: $e');
      debugPrintStack(stackTrace: s);
    }
  }

  static Future<void> dispose() async {
    await _player.dispose();
    await _typingPlayer.dispose();
    _configured = false;
  }
}
