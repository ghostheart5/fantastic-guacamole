import 'package:audioplayers/audioplayers.dart';
import 'package:fantastic_guacamole/ui/constants/app_assets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AudioService {
  static final AudioPlayer _player = AudioPlayer();
  static final AudioPlayer _typingPlayer = AudioPlayer();
  static bool _configured = false;
  static bool _soundEffectsEnabled = true;
  static bool _advancedProfileEnabled = false;
  static bool _hapticsEnabled = true;
  static bool _typingSoundAvailable = true;
  static final Set<String> _unavailableAssets = <String>{};
  static final Map<String, DateTime> _lastEventPlaybackAt =
      <String, DateTime>{};
  static DateTime _lastTypingAt = DateTime.fromMillisecondsSinceEpoch(0);

  static const Duration _kCreateCooldown = Duration(milliseconds: 180);
  static const Duration _kSkipCooldown = Duration(milliseconds: 260);
  static const Duration _kErrorCooldown = Duration(milliseconds: 300);
  static const Duration _kReminderCooldown = Duration(milliseconds: 500);
  static const Duration _kMilestoneCooldown = Duration(milliseconds: 700);
  static const Duration _kAchievementCooldown = Duration(milliseconds: 700);

  static void setSoundEffectsEnabled(bool enabled) {
    _soundEffectsEnabled = enabled;
  }

  static void setAdvancedProfileEnabled(bool enabled) {
    _advancedProfileEnabled = enabled;
  }

  static void setHapticsEnabled(bool enabled) {
    _hapticsEnabled = enabled;
  }

  static bool _canPlayEvent(String key, Duration cooldown) {
    if (cooldown <= Duration.zero) {
      return true;
    }

    final DateTime now = DateTime.now();
    final DateTime? last = _lastEventPlaybackAt[key];
    if (last != null && now.difference(last) < cooldown) {
      return false;
    }

    _lastEventPlaybackAt[key] = now;
    return true;
  }

  static Duration _scaledCooldown(Duration base) {
    final double scale = switch (defaultTargetPlatform) {
      TargetPlatform.iOS => 1.25,
      TargetPlatform.android => 1.15,
      _ => 1.10,
    };
    return Duration(milliseconds: (base.inMilliseconds * scale).round());
  }

  static double _platformVolumeScale() {
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS => 0.92,
      TargetPlatform.android => 0.88,
      _ => 0.86,
    };
  }

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
      if (path == 'audio/ai_decision.wav') AppAssets.audioFocusStart,
      if (path == 'audio/ai_decision.wav') 'audio/task_complete.wav',
      if (path == 'audio/ai_decision.wav') AppAssets.audioTaskComplete,
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

  static Future<void> play(
    String path,
    bool enabled, {
    String eventKey = 'generic',
    Duration cooldown = Duration.zero,
    double subtleVolume = 0.18,
    double advancedVolume = 0.24,
    bool? advancedProfileEnabled,
  }) async {
    if (!enabled ||
        !_soundEffectsEnabled ||
        _unavailableAssets.contains(path)) {
      return;
    }

    final Duration effectiveCooldown = _scaledCooldown(cooldown);
    if (!_canPlayEvent(eventKey, effectiveCooldown)) {
      return;
    }

    try {
      await _ensureConfigured();
      await _player.stop();
      final bool advanced = advancedProfileEnabled ?? _advancedProfileEnabled;
      final double volumeScale = _platformVolumeScale();
      final double targetVolume =
          (advanced ? advancedVolume : subtleVolume) * volumeScale;
      await _player.setVolume(targetVolume.clamp(0.0, 1.0));
      final bool ok = await _playWithFallback(_player, path);
      if (!ok) {
        _unavailableAssets.add(path);
      }
    } catch (_) {
      _unavailableAssets.add(path);
    }
  }

  static Future<void> playTyping() async {
    if (!_typingSoundAvailable || !_soundEffectsEnabled) {
      return;
    }

    final bool advanced = _advancedProfileEnabled;
    final int minIntervalMs = advanced ? 90 : 170;

    final DateTime now = DateTime.now();
    if (now.difference(_lastTypingAt).inMilliseconds < minIntervalMs) {
      return;
    }
    _lastTypingAt = now;

    try {
      await _ensureConfigured();
      await _typingPlayer.stop();
      final double volumeScale = _platformVolumeScale();
      final double targetVolume = (advanced ? 0.2 : 0.1) * volumeScale;
      await _typingPlayer.setVolume(targetVolume.clamp(0.0, 1.0));
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

  static Future<void> _safeHaptic(Future<void> Function() action) async {
    if (!_hapticsEnabled) {
      return;
    }
    try {
      await action();
    } catch (_) {
      // Ignore haptic platform failures to avoid user-facing disruption.
    }
  }

  static Future<void> playCreate(bool enabled, {bool? advancedProfileEnabled}) {
    return play(
      AppAssets.audioFocusStart,
      enabled,
      eventKey: 'create',
      cooldown: _kCreateCooldown,
      subtleVolume: 0.14,
      advancedVolume: 0.22,
      advancedProfileEnabled: advancedProfileEnabled,
    );
  }

  static Future<void> playSkip(bool enabled, {bool? advancedProfileEnabled}) {
    return play(
      AppAssets.audioAiDecision,
      enabled,
      eventKey: 'skip',
      cooldown: _kSkipCooldown,
      subtleVolume: 0.12,
      advancedVolume: 0.18,
      advancedProfileEnabled: advancedProfileEnabled,
    );
  }

  static Future<void> playError(bool enabled, {bool? advancedProfileEnabled}) {
    return play(
      AppAssets.audioErrorSoft,
      enabled,
      eventKey: 'error',
      cooldown: _kErrorCooldown,
      subtleVolume: 0.16,
      advancedVolume: 0.24,
      advancedProfileEnabled: advancedProfileEnabled,
    );
  }

  static Future<void> playAchievement(
    bool enabled, {
    bool? advancedProfileEnabled,
    bool? hapticsEnabled,
  }) async {
    setHapticsEnabled(hapticsEnabled ?? _hapticsEnabled);
    await play(
      AppAssets.audioTaskComplete,
      enabled,
      eventKey: 'achievement',
      cooldown: _kAchievementCooldown,
      subtleVolume: 0.2,
      advancedVolume: 0.32,
      advancedProfileEnabled: advancedProfileEnabled,
    );
    await _safeHaptic(HapticFeedback.mediumImpact);
  }

  static Future<void> playNotification(
    bool enabled, {
    bool? advancedProfileEnabled,
  }) {
    return play(
      AppAssets.audioAiDecision,
      enabled,
      eventKey: 'notification',
      cooldown: _kReminderCooldown,
      subtleVolume: 0.14,
      advancedVolume: 0.2,
      advancedProfileEnabled: advancedProfileEnabled,
    );
  }

  static Future<void> playReminderRoutine(
    bool enabled, {
    bool? advancedProfileEnabled,
  }) {
    return play(
      AppAssets.audioFocusStart,
      enabled,
      eventKey: 'reminder_routine',
      cooldown: const Duration(milliseconds: 620),
      subtleVolume: 0.11,
      advancedVolume: 0.17,
      advancedProfileEnabled: advancedProfileEnabled,
    );
  }

  static Future<void> playReminderDaily(
    bool enabled, {
    bool? advancedProfileEnabled,
  }) {
    return play(
      AppAssets.audioAiDecision,
      enabled,
      eventKey: 'reminder_daily',
      cooldown: const Duration(milliseconds: 760),
      subtleVolume: 0.1,
      advancedVolume: 0.16,
      advancedProfileEnabled: advancedProfileEnabled,
    );
  }

  static Future<void> playMilestone(
    bool enabled, {
    bool? advancedProfileEnabled,
    bool? hapticsEnabled,
  }) async {
    setHapticsEnabled(hapticsEnabled ?? _hapticsEnabled);
    await play(
      AppAssets.audioFocusStart,
      enabled,
      eventKey: 'milestone',
      cooldown: _kMilestoneCooldown,
      subtleVolume: 0.16,
      advancedVolume: 0.26,
      advancedProfileEnabled: advancedProfileEnabled,
    );
    await _safeHaptic(HapticFeedback.lightImpact);
  }

  static Future<void> dispose() async {
    await _player.dispose();
    await _typingPlayer.dispose();
    _configured = false;
    _typingSoundAvailable = true;
    _unavailableAssets.clear();
    _lastEventPlaybackAt.clear();
  }
}
