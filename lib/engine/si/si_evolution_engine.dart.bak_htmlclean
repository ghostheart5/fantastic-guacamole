// lib/engine/si/si_evolution_engine.dart

import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/engine/si/si_adaptive_learning.dart';
import 'package:fantastic_guacamole/engine/si/si_temporal_awareness_engine.dart';

class SIEvolutionState {
  const SIEvolutionState({
    required this.stage,
    required this.growthScore,
    required this.regressionRisk,
    required this.recommendation,
    required this.memory,
  });

  final String stage;
  final double growthScore;
  final double regressionRisk;
  final String recommendation;
  final SIMemoryStore memory;
}

class SIEvolutionEngine {
  const SIEvolutionEngine();

  SIEvolutionState evolve({
    required SIContext context,
    required SIMemoryStore memory,
    AdaptiveLearningWeights learning = const AdaptiveLearningWeights(),
    TemporalAwarenessReport? temporal,
    DateTime? now,
  }) {
    final DateTime t = now ?? DateTime.now();
    final double growth = siClamp01(
      context.userState.motivation * .25 +
          context.userState.engagement * .25 +
          learning.momentum * .25 +
          (temporal?.momentum ?? .5) * .25,
    );
    final double risk = siClamp01(
      context.userState.stress * .3 +
          context.userState.cognitiveLoad * .25 +
          context.userState.fatigue * .25 +
          learning.resistance * .2,
    );
    final String stage = risk >= .68
        ? 'recovery'
        : growth >= .72
        ? 'growth'
        : growth >= .52
        ? 'stabilizing'
        : 'orientation';

    final SIMemoryStore next = memory
        .pushRecord(
          MemoryTier.longTerm,
          MemoryRecord(
            content:
                'evolution|stage=$stage|growth=${growth.toStringAsFixed(2)}|risk=${risk.toStringAsFixed(2)}',
            timestamp: t,
            relevance: growth,
            confidence: .72,
            emotionalWeight: risk,
            reinforcement: stage == 'growth' ? 2 : 1,
          ),
        )
        .dedupe()
        .decay(t);

    return SIEvolutionState(
      stage: stage,
      growthScore: growth,
      regressionRisk: risk,
      recommendation: _recommend(stage),
      memory: next,
    );
  }

  String _recommend(String stage) {
    switch (stage) {
      case 'growth':
        return 'Use momentum for one focused action.';
      case 'recovery':
        return 'Reduce scope and protect capacity.';
      case 'stabilizing':
        return 'Keep the next action small and consistent.';
      default:
        return 'Clarify the next useful step.';
    }
  }
}
