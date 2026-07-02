class CognitiveDimensions {
  const CognitiveDimensions({
    required this.emotional,
    required this.temporal,
    required this.narrative,
    required this.logical,
    required this.multiverse,
  });

  final double emotional;
  final double temporal;
  final double narrative;
  final double logical;
  final double multiverse;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'emotional': emotional,
      'temporal': temporal,
      'narrative': narrative,
      'logical': logical,
      'multiverse': multiverse,
    };
  }
}

class CognitiveDimensionalityLayer {
  const CognitiveDimensionalityLayer();

  CognitiveDimensions map({
    required String mood,
    required String intent,
    required double confidence,
    required bool multiverseMode,
  }) {
    return CognitiveDimensions(
      emotional: mood == 'stressed' ? 0.85 : 0.55,
      temporal: intent == 'reflect' ? 0.78 : 0.58,
      narrative: intent == 'insight_request' ? 0.74 : 0.52,
      logical: confidence,
      multiverse: multiverseMode ? 0.82 : 0.45,
    );
  }
}
