class MetaEmotionState {
  const MetaEmotionState({
    required this.stance,
    required this.drift,
    required this.consistency,
    required this.resonance,
    required this.mismatch,
  });

  final String stance;
  final double drift;
  final double consistency;
  final double resonance;
  final bool mismatch;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'stance': stance,
      'drift': drift,
      'consistency': consistency,
      'resonance': resonance,
      'mismatch': mismatch,
    };
  }
}

class SyntheticMetaEmotionEngine {
  const SyntheticMetaEmotionEngine();

  MetaEmotionState evaluate({
    required String userMood,
    required String previousMood,
    required double confidence,
  }) {
    final double drift = userMood == previousMood ? 0.12 : 0.48;
    final double consistency = (1 - drift).clamp(0.0, 1.0);
    final double resonance =
        ((confidence * 0.6) + (userMood == previousMood ? 0.3 : 0.15)).clamp(
          0.0,
          1.0,
        );
    final bool mismatch = userMood == 'stressed' && resonance < 0.55;

    return MetaEmotionState(
      stance: mismatch ? 'regulating_support' : 'aligned_support',
      drift: drift,
      consistency: consistency,
      resonance: resonance,
      mismatch: mismatch,
    );
  }
}
