class CognitiveHarmonics {
  const CognitiveHarmonics({
    required this.emotionalHarmony,
    required this.narrativeHarmony,
    required this.cognitiveHarmony,
    required this.intentHarmony,
    required this.total,
  });

  final double emotionalHarmony;
  final double narrativeHarmony;
  final double cognitiveHarmony;
  final double intentHarmony;
  final double total;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'emotional_harmony': emotionalHarmony,
      'narrative_harmony': narrativeHarmony,
      'cognitive_harmony': cognitiveHarmony,
      'intent_harmony': intentHarmony,
      'total': total,
    };
  }
}

class CognitiveHarmonicsSystem {
  const CognitiveHarmonicsSystem();

  CognitiveHarmonics align({
    required double resonance,
    required double consistency,
    required double continuity,
    required double intentStrength,
  }) {
    final double total =
        ((resonance * 0.32) +
                (consistency * 0.26) +
                (continuity * 0.22) +
                (intentStrength * 0.2))
            .clamp(0.0, 1.0);
    return CognitiveHarmonics(
      emotionalHarmony: resonance,
      narrativeHarmony: continuity,
      cognitiveHarmony: consistency,
      intentHarmony: intentStrength,
      total: total,
    );
  }
}
