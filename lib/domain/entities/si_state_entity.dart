/// CHRONOSPARK-CLASS: SHIPPING | Feature: SI Console
///
/// In-memory only; no data-layer persistence yet.
class SiStateEntity {
  SiStateEntity({
    required this.energy,
    required this.attention,
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
  final double attention;
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
    double? attention,
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
      attention: attention ?? this.attention,
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
  SiStateEntity withConfidenceDelta(double delta, {DateTime? at}) =>
      copyWith(confidence: confidence + delta, lastUpdated: at);

  SiStateEntity withEnergyDelta(double delta, {DateTime? at}) =>
      copyWith(energy: (energy + delta).clamp(0.0, 1.0), lastUpdated: at);

  SiStateEntity withAttentionDelta(double delta, {DateTime? at}) =>
      copyWith(attention: (attention + delta).clamp(0.0, 1.0), lastUpdated: at);

  SiStateEntity withFatigueDelta(double delta, {DateTime? at}) =>
      copyWith(fatigue: (fatigue + delta).clamp(0.0, 1.0), lastUpdated: at);

  // Semantic helpers
  bool get isLowEnergy => energy < 0.3;
  bool get isHighEnergy => energy > 0.7;

  bool get isLowAttention => attention < 0.3;
  bool get isHighAttention => attention > 0.7;

  bool get isFatigued => fatigue > 0.6;

  bool get isPositiveMood => mood == 'positive';
  bool get isNegativeMood => mood == 'negative';
  bool get isNeutralMood => mood == 'neutral';

  bool get isHighFrictionState => highFriction || frictionScore > 0.7;
  bool get isLowFrictionState => frictionScore < 0.3;

  bool get instinctProgressFirst => primaryInstinct == 'progress_first';
  bool get instinctSafetyFirst => primaryInstinct == 'safety_first';
  bool get instinctExplore => primaryInstinct == 'explore';

  bool isStaleAt(DateTime reference) =>
      reference.difference(lastUpdated).inMinutes > 10;

  bool get isStale => isStaleAt(DateTime.now());

  void validate() {
    if (energy < 0 || energy > 1) {
      throw StateError('Energy must be between 0 and 1');
    }
    if (attention < 0 || attention > 1) {
      throw StateError('Attention must be between 0 and 1');
    }
    if (fatigue < 0 || fatigue > 1) {
      throw StateError('Fatigue must be between 0 and 1');
    }
  }
}
