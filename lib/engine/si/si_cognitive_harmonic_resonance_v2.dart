class HarmonicResonanceV2 {
  const HarmonicResonanceV2({
    required this.emotional,
    required this.narrative,
    required this.cognitive,
    required this.multiverse,
    required this.total,
  });

  final double emotional;
  final double narrative;
  final double cognitive;
  final double multiverse;
  final double total;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'emotional': emotional,
      'narrative': narrative,
      'cognitive': cognitive,
      'multiverse': multiverse,
      'total': total,
    };
  }
}

class CognitiveHarmonicResonanceV2 {
  const CognitiveHarmonicResonanceV2();

  HarmonicResonanceV2 align({
    required double emotional,
    required double narrative,
    required double cognitive,
    required double multiverse,
  }) {
    final double total =
        ((emotional * 0.27) +
                (narrative * 0.25) +
                (cognitive * 0.28) +
                (multiverse * 0.2))
            .clamp(0.0, 1.0);
    return HarmonicResonanceV2(
      emotional: emotional,
      narrative: narrative,
      cognitive: cognitive,
      multiverse: multiverse,
      total: total,
    );
  }
}
