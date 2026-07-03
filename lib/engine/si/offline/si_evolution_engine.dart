class EvolutionState {
  const EvolutionState({
    required this.stage,
    required this.newBehaviors,
    required this.reasoningShortcuts,
    required this.preferenceUpdates,
    required this.traitAdjustments,
  });

  final String stage;
  final List<String> newBehaviors;
  final List<String> reasoningShortcuts;
  final List<String> preferenceUpdates;
  final Map<String, double> traitAdjustments;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'stage': stage,
      'new_behaviors': newBehaviors,
      'reasoning_shortcuts': reasoningShortcuts,
      'preference_updates': preferenceUpdates,
      'trait_adjustments': traitAdjustments,
    };
  }
}

class SyntheticEvolutionEngine {
  const SyntheticEvolutionEngine();

  EvolutionState evolve({
    required int interactionCount,
    required List<String> emotionalHistory,
    required List<String> goals,
  }) {
    final String stage = interactionCount > 120
        ? 'adaptive_mature'
        : interactionCount > 40
        ? 'adaptive_growth'
        : 'adaptive_seed';

    final bool frequentStress =
        emotionalHistory
            .where((String e) => e == 'stressed' || e == 'confused')
            .length >=
        3;

    return EvolutionState(
      stage: stage,
      newBehaviors: <String>[
        if (frequentStress) 'frontload_simplification',
        if (goals.isNotEmpty) 'goal_linked_followups',
        'adaptive_question_timing',
      ],
      reasoningShortcuts: <String>[
        'intent_to_action_templates',
        if (interactionCount > 60) 'high-confidence-response-compression',
      ],
      preferenceUpdates: <String>[
        if (frequentStress) 'prefer_calm_tone',
        if (goals.isNotEmpty) 'prioritize_goal_relevance',
      ],
      traitAdjustments: <String, double>{
        'warmth': frequentStress ? 0.08 : 0.03,
        'directness': goals.isNotEmpty ? 0.06 : 0.02,
      },
    );
  }
}
