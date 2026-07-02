class ArchetypeState {
  const ArchetypeState({
    required this.archetype,
    required this.tone,
    required this.emotionalStyle,
    required this.reasoningStyle,
    required this.traits,
  });

  final String archetype;
  final String tone;
  final String emotionalStyle;
  final String reasoningStyle;
  final List<String> traits;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'archetype': archetype,
      'tone': tone,
      'emotional_style': emotionalStyle,
      'reasoning_style': reasoningStyle,
      'traits': traits,
    };
  }
}

class SyntheticArchetypeSystem {
  const SyntheticArchetypeSystem();

  ArchetypeState select({
    required String intent,
    required String mood,
    required bool urgency,
  }) {
    if (urgency) {
      return const ArchetypeState(
        archetype: 'strategist',
        tone: 'precise',
        emotionalStyle: 'steady',
        reasoningStyle: 'structured',
        traits: <String>['prioritized', 'decisive'],
      );
    }
    if (mood == 'stressed') {
      return const ArchetypeState(
        archetype: 'guardian',
        tone: 'calm',
        emotionalStyle: 'protective',
        reasoningStyle: 'de-escalating',
        traits: <String>['safe', 'supportive'],
      );
    }
    if (intent == 'insight_request') {
      return const ArchetypeState(
        archetype: 'analyst',
        tone: 'clear',
        emotionalStyle: 'neutral_supportive',
        reasoningStyle: 'evidence_first',
        traits: <String>['diagnostic', 'systematic'],
      );
    }
    return const ArchetypeState(
      archetype: 'companion',
      tone: 'warm',
      emotionalStyle: 'encouraging',
      reasoningStyle: 'balanced',
      traits: <String>['present', 'adaptive'],
    );
  }
}
