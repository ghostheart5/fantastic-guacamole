import 'package:flutter/foundation.dart';
import 'package:fantastic_guacamole/features/emotion/emotional_state.dart';

@immutable
class UserState {
  final EmotionalState emotional;
  final double energy;
  final double focus;
  final double cognitiveLoad;
  final String cycle;
  final DateTime lastActionAt;
  final List<String> recentActions;
  final Map<String, dynamic> flags;
  final String? activeSessionId;
  final Duration planningHorizon;

  const UserState({
    required this.emotional,
    required this.energy,
    required this.focus,
    required this.cognitiveLoad,
    required this.cycle,
    required this.lastActionAt,
    required this.recentActions,
    required this.flags,
    required this.activeSessionId,
    required this.planningHorizon,
  });

  factory UserState.initial() {
    return UserState(
      emotional: EmotionalState.neutral,
      energy: 0.5,
      focus: 0.5,
      cognitiveLoad: 0.3,
      cycle: _cycleFromTime(DateTime.now()),
      lastActionAt: DateTime.now(),
      recentActions: const [],
      flags: const {},
      activeSessionId: null,
      planningHorizon: const Duration(hours: 6),
    );
  }

  factory UserState.fromJson(Map<String, dynamic> json) {
    final emotionalStr = json['emotional'] as String? ?? 'neutral';
    final emotional = EmotionalState.values.firstWhere(
      (e) => e.name == emotionalStr,
      orElse: () => EmotionalState.neutral,
    );
    return UserState(
      emotional: emotional,
      energy: (json['energy'] as num?)?.toDouble() ?? 0.5,
      focus: (json['focus'] as num?)?.toDouble() ?? 0.5,
      cognitiveLoad: (json['cognitiveLoad'] as num?)?.toDouble() ?? 0.3,
      cycle: json['cycle'] as String? ?? 'morning',
      lastActionAt: json['lastActionAt'] != null
          ? DateTime.tryParse(json['lastActionAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      recentActions:
          (json['recentActions'] as List<dynamic>?)?.cast<String>() ?? [],
      flags: (json['flags'] as Map<String, dynamic>?) ?? {},
      activeSessionId: json['activeSessionId'] as String?,
      planningHorizon: Duration(
        milliseconds: (json['planningHorizonMs'] as num?)?.toInt() ?? 21600000,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'emotional': emotional.name,
    'energy': energy,
    'focus': focus,
    'cognitiveLoad': cognitiveLoad,
    'cycle': cycle,
    'lastActionAt': lastActionAt.toIso8601String(),
    'recentActions': recentActions,
    'flags': flags,
    'activeSessionId': activeSessionId,
    'planningHorizonMs': planningHorizon.inMilliseconds,
  };

  UserState copyWith({
    EmotionalState? emotional,
    double? energy,
    double? focus,
    double? cognitiveLoad,
    String? cycle,
    DateTime? lastActionAt,
    List<String>? recentActions,
    Map<String, dynamic>? flags,
    String? activeSessionId,
    Duration? planningHorizon,
  }) {
    return UserState(
      emotional: emotional ?? this.emotional,
      energy: energy ?? this.energy,
      focus: focus ?? this.focus,
      cognitiveLoad: cognitiveLoad ?? this.cognitiveLoad,
      cycle: cycle ?? this.cycle,
      lastActionAt: lastActionAt ?? this.lastActionAt,
      recentActions: recentActions ?? this.recentActions,
      flags: flags ?? this.flags,
      activeSessionId: activeSessionId ?? this.activeSessionId,
      planningHorizon: planningHorizon ?? this.planningHorizon,
    );
  }

  static String _cycleFromTime(DateTime now) {
    final hour = now.hour;
    if (hour >= 5 && hour < 12) return 'morning';
    if (hour >= 12 && hour < 17) return 'afternoon';
    if (hour >= 17 && hour < 22) return 'evening';
    return 'night';
  }

  UserState updateCycle() => copyWith(cycle: _cycleFromTime(DateTime.now()));

  UserState addAction(String action) {
    final updated = List<String>.from(recentActions)..add(action);
    return copyWith(recentActions: updated, lastActionAt: DateTime.now());
  }

  UserState setFlag(String key, dynamic value) {
    final updated = Map<String, dynamic>.from(flags)..[key] = value;
    return copyWith(flags: updated);
  }

  UserState clearFlag(String key) {
    final updated = Map<String, dynamic>.from(flags)..remove(key);
    return copyWith(flags: updated);
  }

  bool hasFlag(String key) => flags.containsKey(key);

  UserState adjustEnergy(double delta) =>
      copyWith(energy: (energy + delta).clamp(0.0, 1.0));

  UserState adjustFocus(double delta) =>
      copyWith(focus: (focus + delta).clamp(0.0, 1.0));

  UserState adjustCognitiveLoad(double delta) =>
      copyWith(cognitiveLoad: (cognitiveLoad + delta).clamp(0.0, 1.0));

  UserState startSession(String sessionId) =>
      copyWith(activeSessionId: sessionId);

  UserState endSession() => copyWith(activeSessionId: null);

  UserState updatePlanningHorizon(Duration horizon) =>
      copyWith(planningHorizon: horizon);
}
