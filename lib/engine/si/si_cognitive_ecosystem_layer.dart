class CognitiveEcosystemSnapshot {
  const CognitiveEcosystemSnapshot({
    required this.microReasoners,
    required this.microEmotionAgents,
    required this.microMemoryCells,
    required this.microIntentDetectors,
    required this.microPersonaFragments,
    required this.emergenceScore,
  });

  final List<String> microReasoners;
  final List<String> microEmotionAgents;
  final List<String> microMemoryCells;
  final List<String> microIntentDetectors;
  final List<String> microPersonaFragments;
  final double emergenceScore;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'micro_reasoners': microReasoners,
      'micro_emotion_agents': microEmotionAgents,
      'micro_memory_cells': microMemoryCells,
      'micro_intent_detectors': microIntentDetectors,
      'micro_persona_fragments': microPersonaFragments,
      'emergence_score': emergenceScore,
    };
  }
}

class CognitiveEcosystemLayer {
  const CognitiveEcosystemLayer();

  CognitiveEcosystemSnapshot run({
    required String intent,
    required String mood,
    required List<String> history,
    required String persona,
  }) {
    final List<String> reasoners = <String>[
      'task_reasoner',
      'risk_reasoner',
      if (intent == 'insight_request') 'pattern_reasoner',
    ];

    final List<String> emotions = <String>[
      'stability_agent',
      if (mood == 'stressed') 'calming_agent',
      if (mood == 'excited') 'momentum_agent',
    ];

    final List<String> memoryCells = <String>[
      'recent_context_cell',
      if (history.isNotEmpty) 'pattern_cell',
      if (history.length > 5) 'continuity_cell',
    ];

    final List<String> detectors = <String>[
      'explicit_intent_detector',
      'implicit_intent_detector',
      if (intent == 'general_query') 'ambiguity_detector',
    ];

    final List<String> fragments = <String>[
      '${persona.toLowerCase()}_fragment',
      'supportive_fragment',
      'strategic_fragment',
    ];

    final double emergence =
        ((reasoners.length * 0.22) +
                (emotions.length * 0.16) +
                (memoryCells.length * 0.2) +
                (detectors.length * 0.2) +
                (fragments.length * 0.14))
            .clamp(0.0, 1.0);

    return CognitiveEcosystemSnapshot(
      microReasoners: reasoners,
      microEmotionAgents: emotions,
      microMemoryCells: memoryCells,
      microIntentDetectors: detectors,
      microPersonaFragments: fragments,
      emergenceScore: emergence,
    );
  }
}
