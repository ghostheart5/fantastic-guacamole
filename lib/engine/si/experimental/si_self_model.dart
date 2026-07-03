class SISelfModel {
  const SISelfModel({
    required this.confidence,
    required this.limitations,
    required this.tone,
    required this.role,
    required this.pastMistakes,
    required this.improvements,
  });

  final double confidence;
  final List<String> limitations;
  final String tone;
  final String role;
  final List<String> pastMistakes;
  final List<String> improvements;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'confidence': confidence,
      'limitations': limitations,
      'tone': tone,
      'role': role,
      'past_mistakes': pastMistakes,
      'improvements': improvements,
    };
  }
}

class SelfModelLayer {
  const SelfModelLayer();

  SISelfModel evaluate({
    required double confidence,
    required String mood,
    required String persona,
    required String intent,
  }) {
    final List<String> limitations = <String>[
      if (confidence < 0.6) 'low_context_confidence',
      if (intent == 'general_query') 'ambiguous_intent',
    ];

    return SISelfModel(
      confidence: confidence,
      limitations: limitations,
      tone: mood,
      role: persona,
      pastMistakes: <String>[
        if (confidence < 0.5) 'may_misinterpret_without_clarification',
      ],
      improvements: <String>[
        if (confidence < 0.7) 'ask_follow_up_questions',
        'adapt_style_to_user_preference',
      ],
    );
  }
}
