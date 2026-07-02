class MicroPatternSignal {
  const MicroPatternSignal({
    required this.phrasing,
    required this.timing,
    required this.emotionalShift,
    required this.decisionStyle,
    required this.hesitation,
    required this.confidence,
  });

  final String phrasing;
  final String timing;
  final String emotionalShift;
  final String decisionStyle;
  final double hesitation;
  final double confidence;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'phrasing': phrasing,
      'timing': timing,
      'emotional_shift': emotionalShift,
      'decision_style': decisionStyle,
      'hesitation': hesitation,
      'confidence': confidence,
    };
  }
}

class CognitiveMicroPatternEngine {
  const CognitiveMicroPatternEngine();

  MicroPatternSignal detect({
    required String input,
    required String mood,
    required double hesitation,
    required double confidence,
    required DateTime now,
  }) {
    final String lowered = input.toLowerCase();
    return MicroPatternSignal(
      phrasing: lowered.contains('?') ? 'inquisitive' : 'directive',
      timing: now.hour < 12
          ? 'morning'
          : now.hour < 18
          ? 'afternoon'
          : 'evening',
      emotionalShift: mood,
      decisionStyle: lowered.contains('maybe') || lowered.contains('not sure')
          ? 'exploratory'
          : 'committed',
      hesitation: hesitation,
      confidence: confidence,
    );
  }
}
