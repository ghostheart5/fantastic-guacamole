class CognitiveRhythm {
  const CognitiveRhythm({
    required this.window,
    required this.tone,
    required this.isCreativeHour,
    required this.isProductiveHour,
    required this.isReflectiveHour,
  });

  final String window;
  final String tone;
  final bool isCreativeHour;
  final bool isProductiveHour;
  final bool isReflectiveHour;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'window': window,
      'tone': tone,
      'is_creative_hour': isCreativeHour,
      'is_productive_hour': isProductiveHour,
      'is_reflective_hour': isReflectiveHour,
    };
  }
}

class CognitiveRhythmEngine {
  const CognitiveRhythmEngine();

  CognitiveRhythm evaluate(DateTime now) {
    final int hour = now.hour;
    final bool creative = hour < 6 || hour >= 21;
    final bool productive = hour >= 9 && hour <= 16;
    final bool reflective = hour >= 19 || hour < 7;

    return CognitiveRhythm(
      window: productive
          ? 'productive_window'
          : creative
          ? 'creative_window'
          : 'transition_window',
      tone: productive
          ? 'directive'
          : reflective
          ? 'reflective'
          : 'exploratory',
      isCreativeHour: creative,
      isProductiveHour: productive,
      isReflectiveHour: reflective,
    );
  }
}
