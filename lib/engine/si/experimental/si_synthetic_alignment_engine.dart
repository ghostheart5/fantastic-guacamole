class AlignmentState {
  const AlignmentState({
    required this.wellbeing,
    required this.growth,
    required this.goals,
    required this.emotionalSafety,
    required this.multiverseRules,
    required this.appConstraints,
    required this.total,
  });

  final double wellbeing;
  final double growth;
  final double goals;
  final double emotionalSafety;
  final double multiverseRules;
  final double appConstraints;
  final double total;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'wellbeing': wellbeing,
      'growth': growth,
      'goals': goals,
      'emotional_safety': emotionalSafety,
      'multiverse_rules': multiverseRules,
      'app_constraints': appConstraints,
      'total': total,
    };
  }
}

class SyntheticAlignmentEngine {
  const SyntheticAlignmentEngine();

  AlignmentState evaluate({
    required bool safe,
    required double goalFit,
    required double growth,
    required double emotionalSafety,
  }) {
    final double wellbeing = safe ? 0.84 : 0.4;
    final double multiverseRules = 0.76;
    final double appConstraints = safe ? 0.82 : 0.5;
    final double total =
        ((wellbeing * 0.24) +
                (growth * 0.18) +
                (goalFit * 0.2) +
                (emotionalSafety * 0.2) +
                (multiverseRules * 0.09) +
                (appConstraints * 0.09))
            .clamp(0.0, 1.0);

    return AlignmentState(
      wellbeing: wellbeing,
      growth: growth,
      goals: goalFit,
      emotionalSafety: emotionalSafety,
      multiverseRules: multiverseRules,
      appConstraints: appConstraints,
      total: total,
    );
  }
}
