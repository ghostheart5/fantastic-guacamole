class MetaReasoning {
  const MetaReasoning({
    required this.misunderstandingRisk,
    required this.askClarification,
    required this.slowDown,
    required this.switchPersona,
    required this.adjustTone,
    required this.rationale,
  });

  final double misunderstandingRisk;
  final bool askClarification;
  final bool slowDown;
  final bool switchPersona;
  final bool adjustTone;
  final String rationale;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'misunderstanding_risk': misunderstandingRisk,
      'ask_clarification': askClarification,
      'slow_down': slowDown,
      'switch_persona': switchPersona,
      'adjust_tone': adjustTone,
      'rationale': rationale,
    };
  }
}

class MetaReasoningLayer {
  const MetaReasoningLayer();

  MetaReasoning evaluate({
    required double confidence,
    required bool anticipatesConfusion,
    required String mood,
    required String intent,
  }) {
    final double risk =
        ((1 - confidence) * 0.7 + (anticipatesConfusion ? 0.3 : 0.0)).clamp(
          0,
          1,
        );
    final bool ask = risk > 0.45;
    final bool slow = mood == 'stressed' || mood == 'confused';
    final bool switchPersona =
        intent == 'insight_request' && mood == 'confused';

    return MetaReasoning(
      misunderstandingRisk: risk,
      askClarification: ask,
      slowDown: slow,
      switchPersona: switchPersona,
      adjustTone: slow || ask,
      rationale: ask
          ? 'High ambiguity detected; clarification improves precision.'
          : 'Reasoning confidence is adequate for direct guidance.',
    );
  }
}
