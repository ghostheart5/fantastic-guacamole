class SiStateEntity {
  SiStateEntity({
    required this.energy,
    required this.focus,
    required this.fatigue,
    this.mood = 'neutral',
    this.confidence = 0.5,
    this.anticipatesConfusion = false,
    this.primaryInstinct = 'progress_first',
    this.avoidOverwhelm = false,
    this.frictionScore = 0.0,
    this.highFriction = false,
    DateTime? lastUpdated,
  }) : lastUpdated = lastUpdated ?? _epoch;

  static final DateTime _epoch = DateTime.fromMillisecondsSinceEpoch(0);

  final double energy;
  final double focus;
  final double fatigue;
  final String mood;
  final double confidence;
  final bool anticipatesConfusion;
  final String primaryInstinct;
  final bool avoidOverwhelm;
  final double frictionScore;
  final bool highFriction;
  final DateTime lastUpdated;

  SiStateEntity copyWith({
    double? energy,
    double? focus,
    double? fatigue,
    String? mood,
    double? confidence,
    bool? anticipatesConfusion,
    String? primaryInstinct,
    bool? avoidOverwhelm,
    double? frictionScore,
    bool? highFriction,
    DateTime? lastUpdated,
  }) {
    return SiStateEntity(
      energy: energy ?? this.energy,
      focus: focus ?? this.focus,
      fatigue: fatigue ?? this.fatigue,
      mood: mood ?? this.mood,
      confidence: (confidence ?? this.confidence).clamp(0.0, 1.0),
      anticipatesConfusion: anticipatesConfusion ?? this.anticipatesConfusion,
      primaryInstinct: primaryInstinct ?? this.primaryInstinct,
      avoidOverwhelm: avoidOverwhelm ?? this.avoidOverwhelm,
      frictionScore: (frictionScore ?? this.frictionScore).clamp(0.0, 1.0),
      highFriction: highFriction ?? this.highFriction,
      lastUpdated: lastUpdated ?? DateTime.now(),
    );
  }

  SiStateEntity withConfidenceDelta(double delta) {
    return copyWith(confidence: confidence + delta);
  }
}
