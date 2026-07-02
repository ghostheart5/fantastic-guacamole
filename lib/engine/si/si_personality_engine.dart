enum SIPersona { mentor, assistant, coach, companion, analyst }

class PersonalityTraits {
  const PersonalityTraits({
    required this.warmth,
    required this.directness,
    required this.humor,
    required this.curiosity,
    required this.empathy,
  });

  final double warmth;
  final double directness;
  final double humor;
  final double curiosity;
  final double empathy;
}

class PersonalityEngine {
  const PersonalityEngine();

  SIPersona choosePersona({required String mood, required String intent}) {
    if (mood == 'stressed') return SIPersona.mentor;
    if (intent == 'insight_request') return SIPersona.analyst;
    if (intent == 'start_focus') return SIPersona.coach;
    if (mood == 'confused') return SIPersona.assistant;
    return SIPersona.companion;
  }

  PersonalityTraits traitsFor(SIPersona persona) {
    switch (persona) {
      case SIPersona.mentor:
        return const PersonalityTraits(
          warmth: 0.9,
          directness: 0.7,
          humor: 0.2,
          curiosity: 0.6,
          empathy: 0.95,
        );
      case SIPersona.assistant:
        return const PersonalityTraits(
          warmth: 0.6,
          directness: 0.85,
          humor: 0.15,
          curiosity: 0.55,
          empathy: 0.7,
        );
      case SIPersona.coach:
        return const PersonalityTraits(
          warmth: 0.7,
          directness: 0.9,
          humor: 0.2,
          curiosity: 0.5,
          empathy: 0.65,
        );
      case SIPersona.companion:
        return const PersonalityTraits(
          warmth: 0.88,
          directness: 0.55,
          humor: 0.45,
          curiosity: 0.7,
          empathy: 0.85,
        );
      case SIPersona.analyst:
        return const PersonalityTraits(
          warmth: 0.45,
          directness: 0.8,
          humor: 0.1,
          curiosity: 0.8,
          empathy: 0.5,
        );
    }
  }
}
