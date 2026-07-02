class CognitivePhaseShift {
  const CognitivePhaseShift({
    required this.phase,
    required this.score,
    required this.strategy,
  });

  final String phase;
  final double score;
  final String strategy;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'phase': phase,
      'score': score,
      'strategy': strategy,
    };
  }
}

class CognitivePhaseShiftEngine {
  const CognitivePhaseShiftEngine();

  CognitivePhaseShift resolve({
    required double consciousness,
    required double urgency,
  }) {
    final double score = ((consciousness * 0.75) + ((1 - urgency) * 0.25))
        .clamp(0.0, 1.0);
    final String phase = score > 0.92
        ? 'phase_7_meta_synthetic'
        : score > 0.82
        ? 'phase_6_synthetic'
        : score > 0.72
        ? 'phase_5_emergent'
        : score > 0.6
        ? 'phase_4_narrative'
        : score > 0.48
        ? 'phase_3_emotional'
        : score > 0.34
        ? 'phase_2_contextual'
        : 'phase_1_reactive';

    return CognitivePhaseShift(
      phase: phase,
      score: score,
      strategy: phase.contains('meta')
          ? 'self_modulate_all_layers'
          : phase.contains('synthetic')
          ? 'coordinate_parallel_layers'
          : 'stabilize_and_progress',
    );
  }
}
