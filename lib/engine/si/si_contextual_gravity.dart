class ContextualGravity {
  const ContextualGravity({
    required this.emotionalWeight,
    required this.intentStrength,
    required this.goalRelevance,
    required this.urgency,
    required this.novelty,
    required this.score,
    required this.priority,
  });

  final double emotionalWeight;
  final double intentStrength;
  final double goalRelevance;
  final double urgency;
  final double novelty;
  final double score;
  final String priority;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'emotional_weight': emotionalWeight,
      'intent_strength': intentStrength,
      'goal_relevance': goalRelevance,
      'urgency': urgency,
      'novelty': novelty,
      'score': score,
      'priority': priority,
    };
  }
}

class ContextualGravityEngine {
  const ContextualGravityEngine();

  ContextualGravity compute({
    required String input,
    required String intent,
    required String mood,
    required List<String> goals,
    required List<String> history,
    required double intentScore,
  }) {
    final String lowered = input.toLowerCase();
    final double emotionalWeight = (mood == 'stressed' || mood == 'confused')
        ? 0.85
        : 0.45;
    final double urgency =
        (lowered.contains('urgent') ||
            lowered.contains('asap') ||
            lowered.contains('now'))
        ? 0.9
        : 0.4;

    double goalRelevance = 0.35;
    for (final String g in goals) {
      if (lowered.contains(g.toLowerCase())) {
        goalRelevance = 0.9;
        break;
      }
    }

    final int seenCount = history
        .where((String h) => h.toLowerCase().trim() == lowered.trim())
        .length;
    final double novelty = seenCount == 0
        ? 0.85
        : (0.25 / seenCount).clamp(0.05, 0.3);

    final double score =
        ((emotionalWeight * 0.22) +
                (intentScore * 0.28) +
                (goalRelevance * 0.22) +
                (urgency * 0.2) +
                (novelty * 0.08))
            .clamp(0.0, 1.0);

    final String priority;
    if (score >= 0.75 || intent == 'start_focus') {
      priority = 'critical';
    } else if (score >= 0.55) {
      priority = 'elevated';
    } else {
      priority = 'normal';
    }

    return ContextualGravity(
      emotionalWeight: emotionalWeight,
      intentStrength: intentScore,
      goalRelevance: goalRelevance,
      urgency: urgency,
      novelty: novelty,
      score: score,
      priority: priority,
    );
  }
}
