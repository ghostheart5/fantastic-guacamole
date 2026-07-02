class CognitiveEntropy {
  const CognitiveEntropy({
    required this.value,
    required this.mode,
    required this.stabilizeReasoning,
  });

  final double value;
  final String mode;
  final bool stabilizeReasoning;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'value': value,
      'mode': mode,
      'stabilize_reasoning': stabilizeReasoning,
    };
  }
}

class CognitiveEntropyController {
  const CognitiveEntropyController();

  CognitiveEntropy regulate({
    required String intent,
    required double urgency,
    required String mood,
  }) {
    if (urgency > 0.75 || intent == 'start_focus') {
      return const CognitiveEntropy(
        value: 0.22,
        mode: 'precision',
        stabilizeReasoning: true,
      );
    }
    if (intent.contains('idea') || intent == 'insight_request') {
      return const CognitiveEntropy(
        value: 0.72,
        mode: 'brainstorm',
        stabilizeReasoning: false,
      );
    }
    if (mood == 'stressed') {
      return const CognitiveEntropy(
        value: 0.38,
        mode: 'stabilize',
        stabilizeReasoning: true,
      );
    }
    return const CognitiveEntropy(
      value: 0.52,
      mode: 'balanced',
      stabilizeReasoning: true,
    );
  }
}
