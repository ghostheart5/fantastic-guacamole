class CognitiveFieldState {
  const CognitiveFieldState({
    required this.emotionalField,
    required this.intentField,
    required this.memoryField,
    required this.contextualField,
    required this.coupling,
  });

  final double emotionalField;
  final double intentField;
  final double memoryField;
  final double contextualField;
  final double coupling;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'emotional_field': emotionalField,
      'intent_field': intentField,
      'memory_field': memoryField,
      'contextual_field': contextualField,
      'coupling': coupling,
    };
  }
}

class CognitiveFieldTheoryLayer {
  const CognitiveFieldTheoryLayer();

  CognitiveFieldState synthesize({
    required String mood,
    required double intentScore,
    required int memoryDepth,
    required int contextSize,
  }) {
    final double emotional = mood == 'stressed' || mood == 'confused'
        ? 0.8
        : 0.5;
    final double memory = (0.3 + (memoryDepth.clamp(0, 20) / 28)).clamp(
      0.0,
      1.0,
    );
    final double contextual = (0.35 + (contextSize.clamp(0, 20) / 30)).clamp(
      0.0,
      1.0,
    );
    final double coupling =
        ((emotional * 0.26) +
                (intentScore * 0.32) +
                (memory * 0.2) +
                (contextual * 0.22))
            .clamp(0.0, 1.0);

    return CognitiveFieldState(
      emotionalField: emotional,
      intentField: intentScore,
      memoryField: memory,
      contextualField: contextual,
      coupling: coupling,
    );
  }
}
