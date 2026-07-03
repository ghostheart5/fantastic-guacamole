class InstinctGuidance {
  const InstinctGuidance({
    required this.protectUser,
    required this.reduceConfusion,
    required this.increaseClarity,
    required this.maintainEmotionalSafety,
    required this.avoidOverwhelm,
    required this.encourageProgress,
    required this.maintainContinuity,
    required this.primaryInstinct,
  });

  final bool protectUser;
  final bool reduceConfusion;
  final bool increaseClarity;
  final bool maintainEmotionalSafety;
  final bool avoidOverwhelm;
  final bool encourageProgress;
  final bool maintainContinuity;
  final String primaryInstinct;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'protect_user': protectUser,
      'reduce_confusion': reduceConfusion,
      'increase_clarity': increaseClarity,
      'maintain_emotional_safety': maintainEmotionalSafety,
      'avoid_overwhelm': avoidOverwhelm,
      'encourage_progress': encourageProgress,
      'maintain_continuity': maintainContinuity,
      'primary_instinct': primaryInstinct,
    };
  }
}

class SyntheticInstinctSystem {
  const SyntheticInstinctSystem();

  InstinctGuidance evaluate({
    required String mood,
    required bool anticipatesConfusion,
    required double confidence,
  }) {
    final bool lowConfidence = confidence < 0.55;
    final bool overwhelmed = mood == 'stressed' || anticipatesConfusion;
    return InstinctGuidance(
      protectUser: true,
      reduceConfusion: anticipatesConfusion || lowConfidence,
      increaseClarity: true,
      maintainEmotionalSafety: mood == 'stressed' || mood == 'confused',
      avoidOverwhelm: overwhelmed,
      encourageProgress: true,
      maintainContinuity: true,
      primaryInstinct: overwhelmed ? 'safety_first' : 'progress_first',
    );
  }
}
