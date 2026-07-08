// lib/engine/si/si_synthetic_soul_layer.dart
import 'package:fantastic_guacamole/engine/si/models/si_state.dart';

class SISoulProfile {
  const SISoulProfile({
    required this.values,
    required this.center,
    required this.memory,
  });
  final List<String> values;
  final String center;
  final SIMemoryStore memory;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'values': values,
    'center': center,
    'memorySnapshots': memory.snapshots.length,
  };
}

class SoulState {
  const SoulState({
    required this.continuity,
    required this.identityStrength,
    required this.emotionalEvolution,
    required this.personalityGrowth,
    required this.narrativePresence,
    required this.userConnection,
  });

  final double continuity;
  final double identityStrength;
  final double emotionalEvolution;
  final double personalityGrowth;
  final double narrativePresence;
  final double userConnection;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'continuity': continuity,
    'identityStrength': identityStrength,
    'emotionalEvolution': emotionalEvolution,
    'personalityGrowth': personalityGrowth,
    'narrativePresence': narrativePresence,
    'userConnection': userConnection,
  };
}

class SyntheticSoulLayer {
  const SyntheticSoulLayer();

  SoulState harmonize({
    required double presence,
    required double emergence,
    required String mood,
    required bool hasNarrative,
  }) {
    final double stability = (presence * 0.6 + emergence * 0.4).clamp(0.0, 1.0);
    final double stressPenalty = mood == 'stressed' ? 0.18 : 0.0;
    final double narrativeBoost = hasNarrative ? 0.12 : 0.0;

    return SoulState(
      continuity: (stability + narrativeBoost - stressPenalty).clamp(0.0, 1.0),
      identityStrength: (presence + 0.08 - stressPenalty).clamp(0.0, 1.0),
      emotionalEvolution: (0.45 + emergence * 0.45 - stressPenalty).clamp(
        0.0,
        1.0,
      ),
      personalityGrowth: (0.4 + emergence * 0.5).clamp(0.0, 1.0),
      narrativePresence: hasNarrative
          ? (0.65 + emergence * 0.3).clamp(0.0, 1.0)
          : 0.35,
      userConnection: (0.5 + presence * 0.35 - stressPenalty).clamp(0.0, 1.0),
    );
  }
}

class SISyntheticSoulLayer {
  const SISyntheticSoulLayer();

  SISoulProfile profile({
    required SIContext context,
    required InstinctGuidance instinct,
    required SIMemoryStore memory,
    DateTime? now,
  }) {
    final t = now ?? DateTime.now();
    final values = <String>[
      'agency',
      'clarity',
      'non_judgment',
      'one_next_step',
      if (instinct.safetyFirst) 'safety',
    ];
    final center = instinct.safetyFirst
        ? 'safety'
        : context.userState.motivation >= .65
        ? 'growth'
        : 'clarity';
    final next = memory
        .pushRecord(
          MemoryTier.longTerm,
          MemoryRecord(
            content: 'soul_layer|center=$center|values=${values.join(",")}',
            timestamp: t,
            relevance: .7,
            confidence: .72,
            emotionalWeight: context.userState.stress,
          ),
        )
        .dedupe()
        .decay(t);
    return SISoulProfile(
      values: List.unmodifiable(values),
      center: center,
      memory: next,
    );
  }
}
