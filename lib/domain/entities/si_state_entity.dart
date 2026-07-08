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

  // Domain transitions
  SiStateEntity withConfidenceDelta(double delta) =>
      copyWith(confidence: confidence + delta);

  SiStateEntity withEnergyDelta(double delta) =>
      copyWith(energy: (energy + delta).clamp(0.0, 1.0));

  SiStateEntity withFocusDelta(double delta) =>
      copyWith(focus: (focus + delta).clamp(0.0, 1.0));

  SiStateEntity withFatigueDelta(double delta) =>
      copyWith(fatigue: (fatigue + delta).clamp(0.0, 1.0));

  // Semantic helpers
  bool get isLowEnergy => energy < 0.3;
  bool get isHighEnergy => energy > 0.7;

  bool get isLowFocus => focus < 0.3;
  bool get isHighFocus => focus > 0.7;

  bool get isFatigued => fatigue > 0.6;

  bool get isPositiveMood => mood == 'positive';
  bool get isNegativeMood => mood == 'negative';
  bool get isNeutralMood => mood == 'neutral';

  bool get isHighFrictionState => highFriction || frictionScore > 0.7;
  bool get isLowFrictionState => frictionScore < 0.3;

  bool get instinctProgressFirst => primaryInstinct == 'progress_first';
  bool get instinctSafetyFirst => primaryInstinct == 'safety_first';
  bool get instinctExplore => primaryInstinct == 'explore';

  bool get isStale => DateTime.now().difference(lastUpdated).inMinutes > 10;

  void validate() {
    if (energy < 0 || energy > 1) {
      throw StateError('Energy must be between 0 and 1');
    }
    if (focus < 0 || focus > 1) {
      throw StateError('Focus must be between 0 and 1');
    }
    if (fatigue < 0 || fatigue > 1) {
      throw StateError('Fatigue must be between 0 and 1');
    }
  }
}
