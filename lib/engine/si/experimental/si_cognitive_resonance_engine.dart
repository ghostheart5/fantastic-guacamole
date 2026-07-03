class CognitiveResonance {
  const CognitiveResonance({
    required this.value,
    required this.level,
    required this.adjustment,
  });

  final double value;
  final String level;
  final String adjustment;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'value': value,
      'level': level,
      'adjustment': adjustment,
    };
  }
}

class CognitiveResonanceEngine {
  const CognitiveResonanceEngine();

  CognitiveResonance compute({
    required double goalFit,
    required double emotionFit,
    required double patternFit,
    required double personaFit,
  }) {
    final double value =
        ((goalFit * 0.3) +
                (emotionFit * 0.25) +
                (patternFit * 0.2) +
                (personaFit * 0.25))
            .clamp(0.0, 1.0);
    final String level = value > 0.72
        ? 'high'
        : value > 0.48
        ? 'medium'
        : 'low';
    final String adjustment = level == 'high'
        ? 'maintain approach'
        : level == 'medium'
        ? 'fine-tune tone and structure'
        : 'recalibrate persona and simplify';
    return CognitiveResonance(
      value: value,
      level: level,
      adjustment: adjustment,
    );
  }
}
