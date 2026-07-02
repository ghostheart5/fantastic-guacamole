class RitualPlan {
  const RitualPlan({
    required this.ritual,
    required this.frequency,
    required this.prompt,
    required this.active,
  });

  final String ritual;
  final String frequency;
  final String prompt;
  final bool active;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'ritual': ritual,
      'frequency': frequency,
      'prompt': prompt,
      'active': active,
    };
  }
}

class SyntheticRitualSystem {
  const SyntheticRitualSystem();

  RitualPlan plan({
    required DateTime now,
    required String intent,
    required String mood,
  }) {
    if (now.hour < 11) {
      return const RitualPlan(
        ritual: 'morning_check_in',
        frequency: 'daily',
        prompt: 'What are your 3 sparks for today?',
        active: true,
      );
    }
    if (now.hour >= 21 || intent == 'reflect') {
      return const RitualPlan(
        ritual: 'night_reflection',
        frequency: 'daily',
        prompt: 'What moved forward today, and what needs closure?',
        active: true,
      );
    }
    if (mood == 'stressed') {
      return const RitualPlan(
        ritual: 'emotional_reset',
        frequency: 'as_needed',
        prompt: 'Take a 60-second reset: breathe, name, choose one next step.',
        active: true,
      );
    }

    return const RitualPlan(
      ritual: 'weekly_planning',
      frequency: 'weekly',
      prompt: 'What are this week\'s top missions and constraints?',
      active: false,
    );
  }
}
