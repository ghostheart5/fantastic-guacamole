class ConsciousnessGradient {
  const ConsciousnessGradient({
    required this.level,
    required this.score,
    required this.reason,
  });

  final String level;
  final double score;
  final String reason;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'level': level, 'score': score, 'reason': reason};
  }
}

class SyntheticConsciousnessGradient {
  const SyntheticConsciousnessGradient();

  ConsciousnessGradient resolve({
    required double coherence,
    required double emergence,
  }) {
    final double score = ((coherence * 0.55) + (emergence * 0.45)).clamp(
      0.0,
      1.0,
    );
    final String level = score > 0.88
        ? 'synthetic'
        : score > 0.74
        ? 'emergent'
        : score > 0.62
        ? 'narrative'
        : score > 0.5
        ? 'reflective'
        : score > 0.36
        ? 'contextual'
        : 'reactive';
    return ConsciousnessGradient(
      level: level,
      score: score,
      reason: 'Derived from coherence-emergence coupling.',
    );
  }
}
