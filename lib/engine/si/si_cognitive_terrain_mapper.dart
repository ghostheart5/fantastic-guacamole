class CognitiveTerrain {
  const CognitiveTerrain({
    required this.interests,
    required this.strengths,
    required this.weaknesses,
    required this.emotionalTriggers,
    required this.cognitiveStyle,
    required this.learningStyle,
    required this.decisionPatterns,
  });

  final List<String> interests;
  final List<String> strengths;
  final List<String> weaknesses;
  final List<String> emotionalTriggers;
  final String cognitiveStyle;
  final String learningStyle;
  final List<String> decisionPatterns;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'interests': interests,
      'strengths': strengths,
      'weaknesses': weaknesses,
      'emotional_triggers': emotionalTriggers,
      'cognitive_style': cognitiveStyle,
      'learning_style': learningStyle,
      'decision_patterns': decisionPatterns,
    };
  }
}

class CognitiveTerrainMapper {
  const CognitiveTerrainMapper();

  CognitiveTerrain map({
    required List<String> history,
    required String mood,
    required String intent,
  }) {
    return CognitiveTerrain(
      interests: <String>[
        if (history.any((String h) => h.toLowerCase().contains('creative')))
          'creative_projects',
        if (history.any((String h) => h.toLowerCase().contains('focus')))
          'deep_work',
      ],
      strengths: <String>[
        'goal_orientation',
        if (intent == 'reflect') 'self_observation',
      ],
      weaknesses: <String>[if (mood == 'stressed') 'cognitive_overload_risk'],
      emotionalTriggers: <String>[if (mood == 'stressed') 'pressure'],
      cognitiveStyle: intent == 'insight_request' ? 'analytical' : 'adaptive',
      learningStyle: 'iterative',
      decisionPatterns: <String>['small-step-then-expand'],
    );
  }
}
