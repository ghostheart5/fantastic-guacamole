class CognitiveLoadDecision {
  const CognitiveLoadDecision({
    required this.level,
    required this.simplify,
    required this.expansionAllowed,
    required this.maxSteps,
    required this.explanationStyle,
  });

  final String level;
  final bool simplify;
  final bool expansionAllowed;
  final int maxSteps;
  final String explanationStyle;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'level': level,
      'simplify': simplify,
      'expansion_allowed': expansionAllowed,
      'max_steps': maxSteps,
      'explanation_style': explanationStyle,
    };
  }
}

class CognitiveLoadBalancer {
  const CognitiveLoadBalancer();

  CognitiveLoadDecision balance({
    required String mood,
    required double stress,
    required double fatigue,
    required double confusion,
    required int messageLength,
  }) {
    final double loadScore =
        ((stress * 0.35) +
                (fatigue * 0.3) +
                (confusion * 0.25) +
                ((messageLength > 220 ? 1.0 : 0.35) * 0.1))
            .clamp(0.0, 1.0);

    if (mood == 'stressed' || loadScore >= 0.7) {
      return const CognitiveLoadDecision(
        level: 'high',
        simplify: true,
        expansionAllowed: false,
        maxSteps: 2,
        explanationStyle: 'minimal',
      );
    }
    if (loadScore >= 0.45) {
      return const CognitiveLoadDecision(
        level: 'medium',
        simplify: false,
        expansionAllowed: true,
        maxSteps: 3,
        explanationStyle: 'balanced',
      );
    }
    return const CognitiveLoadDecision(
      level: 'low',
      simplify: false,
      expansionAllowed: true,
      maxSteps: 5,
      explanationStyle: 'expanded',
    );
  }
}
