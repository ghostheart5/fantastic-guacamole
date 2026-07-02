enum CognitiveStyle {
  analytical,
  creative,
  emotional,
  directive,
  reflective,
  playful,
  technical,
}

class CognitiveStyleEngine {
  const CognitiveStyleEngine();

  CognitiveStyle choose({
    required String mood,
    required String intent,
    required String conversationType,
    required String appContext,
  }) {
    if (intent == 'insight_request' || conversationType == 'debug') {
      return CognitiveStyle.technical;
    }
    if (intent == 'start_focus') {
      return CognitiveStyle.directive;
    }
    if (mood == 'stressed' || mood == 'confused') {
      return CognitiveStyle.emotional;
    }
    if (intent == 'reflect') {
      return CognitiveStyle.reflective;
    }
    if (appContext.contains('creative') || intent.contains('idea')) {
      return CognitiveStyle.creative;
    }
    if (conversationType == 'casual') {
      return CognitiveStyle.playful;
    }
    return CognitiveStyle.analytical;
  }

  String shape(String text, CognitiveStyle style) {
    switch (style) {
      case CognitiveStyle.analytical:
        return '1) Analyze 2) Decide 3) Act\n$text';
      case CognitiveStyle.creative:
        return '$text\n\nTry a bold variation and iterate quickly.';
      case CognitiveStyle.emotional:
        return '$text\n\nYou are not behind. We can do this one step at a time.';
      case CognitiveStyle.directive:
        return '$text\n\nNext: execute now.';
      case CognitiveStyle.reflective:
        return '$text\n\nPause for 20 seconds and note what worked.';
      case CognitiveStyle.playful:
        return '$text\n\nTiny win unlocked. Keep your streak alive.';
      case CognitiveStyle.technical:
        return '$text\n\nTechnical mode: concise and implementation-focused.';
    }
  }
}
