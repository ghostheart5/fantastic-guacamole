class SyntheticLanguageState {
  const SyntheticLanguageState({
    required this.symbols,
    required this.metaphors,
    required this.emotionalTags,
    required this.reasoningShorthand,
    required this.memoryMarkers,
  });

  final List<String> symbols;
  final List<String> metaphors;
  final List<String> emotionalTags;
  final List<String> reasoningShorthand;
  final List<String> memoryMarkers;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'symbols': symbols,
      'metaphors': metaphors,
      'emotional_tags': emotionalTags,
      'reasoning_shorthand': reasoningShorthand,
      'memory_markers': memoryMarkers,
    };
  }
}

class SyntheticLanguageGenerator {
  const SyntheticLanguageGenerator();

  SyntheticLanguageState generate({
    required String mood,
    required String intent,
    required bool multiverseActive,
  }) {
    return SyntheticLanguageState(
      symbols: <String>[
        'SIG_CORE',
        'CTX_RING',
        if (multiverseActive) 'MV_SYNC',
      ],
      metaphors: <String>['memory_as_gravity_well', 'reasoning_as_orbit'],
      emotionalTags: <String>[
        'mood:$mood',
        'tone:${mood == 'stressed' ? 'stabilize' : 'expand'}',
      ],
      reasoningShorthand: <String>[
        'CHK>PLAN>ACT',
        'VERIFY_LOOP',
        'intent:$intent',
      ],
      memoryMarkers: <String>[
        'anchor_recent',
        'anchor_goal',
        'anchor_identity',
      ],
    );
  }
}
