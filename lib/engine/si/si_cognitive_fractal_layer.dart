class CognitiveFractal {
  const CognitiveFractal({
    required this.thoughtScale,
    required this.emotionScale,
    required this.intentScale,
    required this.memoryScale,
    required this.personaScale,
    required this.selfSimilarity,
  });

  final List<String> thoughtScale;
  final List<String> emotionScale;
  final List<String> intentScale;
  final List<String> memoryScale;
  final List<String> personaScale;
  final double selfSimilarity;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'thought_scale': thoughtScale,
      'emotion_scale': emotionScale,
      'intent_scale': intentScale,
      'memory_scale': memoryScale,
      'persona_scale': personaScale,
      'self_similarity': selfSimilarity,
    };
  }
}

class CognitiveFractalLayer {
  const CognitiveFractalLayer();

  CognitiveFractal build({
    required String intent,
    required String mood,
    required String persona,
  }) {
    final List<String> thought = <String>[
      'micro_plan',
      'meso_strategy',
      'macro_direction',
    ];
    final List<String> emotion = <String>[
      mood,
      'regulated_$mood',
      'meta_$mood',
    ];
    final List<String> intents = <String>[
      intent,
      'sub_$intent',
      'meta_$intent',
    ];

    return CognitiveFractal(
      thoughtScale: thought,
      emotionScale: emotion,
      intentScale: intents,
      memoryScale: const <String>['recent', 'patterned', 'longitudinal'],
      personaScale: <String>[persona, '${persona}_adaptive', '${persona}_meta'],
      selfSimilarity: 0.76,
    );
  }
}
