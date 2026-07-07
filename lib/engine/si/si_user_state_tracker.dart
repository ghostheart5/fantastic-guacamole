// lib/engine/si/si_user_state_tracker.dart

import 'package:fantastic_guacamole/engine/si/models/si_state.dart';

class UserStateSnapshot {
  const UserStateSnapshot({
    required this.userState,
    required this.intent,
    required this.confidence,
    required this.recentSignals,
    required this.trend,
    required this.timestamp,
  });

  final SIUserState userState;
  final String intent;
  final double confidence;
  final List<String> recentSignals;
  final String trend;
  final DateTime timestamp;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'user_state': userState.toJson(),
    'intent': intent,
    'confidence': siClamp01(confidence),
    'recent_signals': recentSignals,
    'trend': trend,
    'timestamp': timestamp.toIso8601String(),
  };
}

class SIUserStateTracker {
  const SIUserStateTracker();

  UserStateSnapshot track({
    required SIContext context,
    required String intent,
    required double confidence,
    required List<String> recentSignals,
    required SIMemoryStore memory,
    DateTime? now,
  }) {
    final DateTime timestamp = now ?? DateTime.now();

    final SIUserState base = context.userState;

    final double stress = _computeStress(base, recentSignals);
    final double cognitiveLoad = _computeLoad(base, recentSignals);
    final double engagement = _computeEngagement(base, confidence);
    final double fatigue = _computeFatigue(base, memory);
    final double motivation = _computeMotivation(base, confidence, engagement);

    final SIUserState refined = SIUserState(
      emotion: _emotion(base, stress, cognitiveLoad, fatigue),
      stress: stress,
      cognitiveLoad: cognitiveLoad,
      engagement: engagement,
      fatigue: fatigue,
      motivation: motivation,
      frustration: siClamp01(base.frustration),
      excitement: siClamp01(base.excitement),
      stability: _stability(stress, cognitiveLoad, engagement),
    );

    final String trend = _trend(memory, refined);

    memory
        .pushRecord(
          MemoryTier.shortTerm,
          MemoryRecord(
            content:
                'user_state|${refined.emotion}|stress=${stress.toStringAsFixed(2)}|load=${cognitiveLoad.toStringAsFixed(2)}|trend=$trend',
            timestamp: timestamp,
            relevance: confidence,
            confidence: siClamp01(confidence),
            emotionalWeight: stress,
            reinforcement: confidence >= 0.7 ? 1 : 0,
          ),
        )
        .dedupe()
        .decay(timestamp);

    return UserStateSnapshot(
      userState: refined,
      intent: intent,
      confidence: confidence,
      recentSignals: List<String>.unmodifiable(recentSignals),
      trend: trend,
      timestamp: timestamp,
    );
  }

  double _computeStress(SIUserState base, List<String> signals) {
    double value = base.stress;

    if (signals.any((String s) => s.contains('overwhelmed'))) value += 0.2;
    if (signals.any((String s) => s.contains('blocked'))) value += 0.15;

    return siClamp01(value);
  }

  double _computeLoad(SIUserState base, List<String> signals) {
    double value = base.cognitiveLoad;

    if (signals.length >= 4) value += 0.15;
    if (signals.any((String s) => s.contains('confused'))) value += 0.2;

    return siClamp01(value);
  }

  double _computeEngagement(SIUserState base, double confidence) {
    return siClamp01((base.engagement + confidence) / 2);
  }

  double _computeFatigue(SIUserState base, SIMemoryStore memory) {
    final int recent = memory.tiered.shortTerm.length;
    double value = base.fatigue;

    if (recent >= 6) value += 0.15;

    return siClamp01(value);
  }

  double _computeMotivation(
    SIUserState base,
    double confidence,
    double engagement,
  ) {
    return siClamp01((base.motivation + confidence + engagement) / 3);
  }

  String _emotion(
    SIUserState base,
    double stress,
    double load,
    double fatigue,
  ) {
    if (stress >= 0.7) return 'stressed';
    if (load >= 0.7) return 'confused';
    if (fatigue >= 0.7) return 'tired';
    return siNormalizeMood(base.emotion);
  }

  String _stability(double stress, double load, double engagement) {
    if (stress >= 0.7 || load >= 0.75) return 'fragile';
    if (engagement >= 0.65 && stress <= 0.45) return 'stable';
    return 'volatile';
  }

  String _trend(SIMemoryStore memory, SIUserState current) {
    if (memory.snapshots.length < 2) return 'unknown';

    final SISnapshot last = memory.snapshots.first;
    final double previousEnergy = siClamp01(last.energy);
    final double currentEnergy = siClamp01(current.engagement);

    final double delta = currentEnergy - previousEnergy;

    if (delta >= 0.08) return 'improving';
    if (delta <= -0.08) return 'declining';
    return 'stable';
  }
}
