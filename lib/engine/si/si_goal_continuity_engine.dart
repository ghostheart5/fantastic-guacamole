// lib/engine/si/si_goal_continuity_engine.dart

import 'package:fantastic_guacamole/engine/si/models/si_state.dart';

class GoalContinuityProfile {
  const GoalContinuityProfile({
    required this.goals,
    required this.activeGoal,
    required this.continuityScore,
    required this.driftRisk,
    required this.memory,
  });

  final List<String> goals;
  final String? activeGoal;
  final double continuityScore;
  final double driftRisk;
  final SIMemoryStore memory;
}

class SIGoalContinuityEngine {
  const SIGoalContinuityEngine();

  GoalContinuityProfile update({
    required SIContext context,
    required SIMemoryStore memory,
    List<String> goals = const <String>[],
    DateTime? now,
  }) {
    final DateTime t = now ?? DateTime.now();
    final Set<String> merged = <String>{...goals.map(siClean)};
    final Object? rawGoal =
        context.input.context['goal'] ?? context.input.metadata['goal'];
    final String contextual = siClean(rawGoal?.toString());
    if (contextual.isNotEmpty) merged.add(contextual);

    for (final MemoryRecord r in memory.tiered.longTerm) {
      if (r.content.startsWith('goal|')) {
        merged.add(r.content.split('|').skip(1).join('|'));
      }
    }

    final String? active = merged.isEmpty ? null : merged.first;
    final double score = siClamp01(
      (merged.isNotEmpty ? .45 : .15) +
          context.userState.engagement * .35 +
          context.userState.motivation * .2,
    );
    final double drift = siClamp01(1 - score + context.userState.stress * .15);

    final SIMemoryStore next = active == null
        ? memory
        : memory
              .pushRecord(
                MemoryTier.longTerm,
                MemoryRecord(
                  content:
                      'goal|$active|continuity=${score.toStringAsFixed(2)}|drift=${drift.toStringAsFixed(2)}',
                  timestamp: t,
                  relevance: score,
                  confidence: .7,
                  emotionalWeight: drift,
                  reinforcement: score >= .7 ? 2 : 1,
                ),
              )
              .dedupe()
              .decay(t);

    return GoalContinuityProfile(
      goals: List<String>.unmodifiable(
        merged.where((String g) => g.isNotEmpty),
      ),
      activeGoal: active,
      continuityScore: score,
      driftRisk: drift,
      memory: next,
    );
  }
}
