class UserGrowthSnapshot {
  const UserGrowthSnapshot({
    required this.skills,
    required this.habits,
    required this.confidence,
    required this.resilience,
    required this.productivity,
    required this.creativity,
    required this.nextGrowthAction,
  });

  final double skills;
  final double habits;
  final double confidence;
  final double resilience;
  final double productivity;
  final double creativity;
  final String nextGrowthAction;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'skills': skills,
      'habits': habits,
      'confidence': confidence,
      'resilience': resilience,
      'productivity': productivity,
      'creativity': creativity,
      'next_growth_action': nextGrowthAction,
    };
  }
}

class UserGrowthEngine {
  const UserGrowthEngine();

  UserGrowthSnapshot track({
    required double confidence,
    required bool hasRitual,
    required String mood,
    required String intent,
  }) {
    final double habits = hasRitual ? 0.78 : 0.52;
    final double resilience = mood == 'stressed' ? 0.5 : 0.72;
    final double creativity = intent.contains('idea') ? 0.8 : 0.62;

    return UserGrowthSnapshot(
      skills: (confidence * 0.8 + 0.2).clamp(0.0, 1.0),
      habits: habits,
      confidence: confidence,
      resilience: resilience,
      productivity: (confidence * 0.7 + habits * 0.3).clamp(0.0, 1.0),
      creativity: creativity,
      nextGrowthAction: hasRitual
          ? 'Increase challenge slightly in the next session.'
          : 'Start a small daily ritual to stabilize momentum.',
    );
  }
}
