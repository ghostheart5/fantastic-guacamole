class CognitiveCompression {
  const CognitiveCompression({
    required this.reasoningShort,
    required this.ideaSimple,
    required this.emotionTone,
  });

  final String reasoningShort;
  final String ideaSimple;
  final String emotionTone;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'reasoning_short': reasoningShort,
      'idea_simple': ideaSimple,
      'emotion_tone': emotionTone,
    };
  }
}

class CognitiveCompressionEngine {
  const CognitiveCompressionEngine();

  CognitiveCompression compress({
    required String reasoning,
    required String mood,
    required int maxChars,
  }) {
    final String normalized = reasoning.replaceAll(RegExp(r'\s+'), ' ').trim();
    final String shortText = normalized.length <= maxChars
        ? normalized
        : '${normalized.substring(0, maxChars)}...';
    return CognitiveCompression(
      reasoningShort: shortText,
      ideaSimple: 'Do one clear next step, then review and iterate.',
      emotionTone: mood == 'stressed' ? 'calm_reassuring' : 'steady_confident',
    );
  }
}
