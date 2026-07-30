import 'package:audioplayers/audioplayers.dart';
import 'package:fantastic_guacamole/ui/constants/app_assets.dart';

class AudioService {
  static final AudioPlayer _player = AudioPlayer();
  static final AudioPlayer _typingPlayer = AudioPlayer();
  static bool _configured = false;
  static bool _typingSoundAvailable = true;
  static final Set<String> _unavailableAssets = <String>{};
  static DateTime _lastTypingAt = DateTime.fromMillisecondsSinceEpoch(0);

  static Future<void> _ensureConfigured() async {
    if (_configured) {
      return;
    }

    await _player.setReleaseMode(ReleaseMode.stop);
    await _typingPlayer.setReleaseMode(ReleaseMode.stop);
    _configured = true;
  }

  static Future<bool> _playWithFallback(AudioPlayer player, String path) async {
    final List<String> candidates = <String>[
      path,
      if (!path.startsWith('assets/')) 'assets/$path',
      if (path == 'audio/ai_decision.wav') 'audio/focus_start.wav',
      if (path == 'audio/ai_decision.wav') 'assets/audio/focus_start.wav',
      if (path == 'audio/ai_decision.wav') 'audio/task_complete.wav',
      if (path == 'audio/ai_decision.wav') 'assets/audio/task_complete.wav',
    ];

    for (final String candidate in candidates) {
      try {
        await player.play(AssetSource(candidate));
        return true;
      } catch (_) {
        // Try the next candidate source silently.
      }
    }

    return false;
  }

  static Future<void> play(String path, bool enabled) async {
    if (!enabled || _unavailableAssets.contains(path)) {
      return;
    }
    try {
      await _ensureConfigured();
      await _player.stop();
      final bool ok = await _playWithFallback(_player, path);
      if (!ok) {
        _unavailableAssets.add(path);
      }
    } catch (_) {
      _unavailableAssets.add(path);
    }
  }

  static Future<void> playTyping() async {
    if (!_typingSoundAvailable) {
      return;
    }

    final DateTime now = DateTime.now();
    if (now.difference(_lastTypingAt).inMilliseconds < 65) {
      return;
    }
    _lastTypingAt = now;

    try {
      await _ensureConfigured();
      await _typingPlayer.stop();
      await _typingPlayer.setVolume(0.2);
      final bool ok = await _playWithFallback(
        _typingPlayer,
        'audio/ai_decision.wav',
      );
      if (!ok) {
        _typingSoundAvailable = false;
      }
    } catch (_) {
      _typingSoundAvailable = false;
    }
  }

  static Future<void> playAchievement(bool enabled) {
    return play(AppAssets.audioTaskComplete, enabled);
  }

  static Future<void> playNotification(bool enabled) {
    return play(AppAssets.audioAiDecision, enabled);
  }

  static Future<void> playMilestone(bool enabled) {
    return play(AppAssets.audioFocusStart, enabled);
  }

  static Future<void> dispose() async {
    await _player.dispose();
    await _typingPlayer.dispose();
    _configured = false;
    _typingSoundAvailable = true;
    _unavailableAssets.clear();
  }
}
