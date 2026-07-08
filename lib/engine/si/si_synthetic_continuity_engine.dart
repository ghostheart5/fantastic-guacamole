// lib/engine/si/si_synthetic_continuity_engine.dart

import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/engine/si/si_adaptive_learning.dart';
import 'package:fantastic_guacamole/engine/si/si_cognitive_micro_pattern_engine.dart';

class ContinuityProfile {
  const ContinuityProfile({
    required this.identityLabel,
    required this.goals,
    required this.behaviorPatterns,
    required this.continuityScore,
    required this.driftRisk,
    required this.memory,
  });

  final String identityLabel;
  final List<String> goals;
  final List<String> behaviorPatterns;
  final double continuityScore;
  final double driftRisk;
  final SIMemoryStore memory;
}

class SISyntheticContinuityEngine {
  const SISyntheticContinuityEngine();

  ContinuityProfile update({
    required SIContext context,
    required SIMemoryStore memory,
    MicroPatternReport? patterns,
    AdaptiveLearningWeights? learning,
    DateTime? now,
  }) {
    final DateTime t = now ?? DateTime.now();
    final List<String> goals = _goals(context, memory);
    final List<String> behaviors = _behaviors(patterns, memory);
    final String identity = _identity(context, learning, behaviors);

    final double score = siClamp01(
      (context.userState.stability == 'stable' ? 0.25 : 0.1) +
          (goals.isNotEmpty ? 0.25 : 0.1) +
          (behaviors.isNotEmpty ? 0.25 : 0.1) +
          ((learning?.momentum ?? 0.5) * 0.25),
    );

    final double drift = siClamp01(1 - score + context.userState.stress * 0.15);

    final SIMemoryStore nextMemory = memory
        .pushRecord(
          MemoryTier.longTerm,
          MemoryRecord(
            content:
                'continuity|identity=$identity|goals=${goals.join(",")}|patterns=${behaviors.join(",")}|score=${score.toStringAsFixed(2)}',
            timestamp: t,
            relevance: score,
            confidence: 0.74,
            emotionalWeight: drift,
            reinforcement: score >= 0.7 ? 2 : 1,
          ),
        )
        .dedupe()
        .decay(t);

    return ContinuityProfile(
      identityLabel: identity,
      goals: List<String>.unmodifiable(goals),
      behaviorPatterns: List<String>.unmodifiable(behaviors),
      continuityScore: score,
      driftRisk: drift,
      memory: nextMemory,
    );
  }

  List<String> _goals(SIContext context, SIMemoryStore memory) {
    final List<String> out = <String>[];
    final Object? goal =
        context.input.context['goal'] ?? context.input.metadata['goal'];
    final String clean = siClean(goal?.toString());
    if (clean.isNotEmpty) out.add(clean);

    for (final MemoryRecord r in memory.tiered.longTerm) {
      if (r.content.startsWith('goal|')) {
        out.add(r.content.split('|').skip(1).join('|'));
      }
    }
    return out.toSet().take(8).toList();
  }

  List<String> _behaviors(MicroPatternReport? patterns, SIMemoryStore memory) {
    final List<String> out = <String>[
      ...?patterns?.patterns.map((MicroPattern p) => p.type.name),
      ...memory.tiered.midTerm
          .where((MemoryRecord r) => r.content.startsWith('pattern|'))
          .map(
            (MemoryRecord r) => r.content.split('|').length > 1
                ? r.content.split('|')[1]
                : r.content,
          ),
    ];
    return out.toSet().take(10).toList();
  }

  String _identity(
    SIContext context,
    AdaptiveLearningWeights? learning,
    List<String> behaviors,
  ) {
    if (context.userState.fatigue >= 0.68) return 'recovering_planner';
    if ((learning?.momentum ?? 0.5) >= 0.68) return 'momentum_builder';
    if (behaviors.contains('skipResistance')) return 'resistance_reframer';
    if (context.userState.motivation >= 0.65) return 'focused_builder';
    return 'steady_operator';
  }
}
