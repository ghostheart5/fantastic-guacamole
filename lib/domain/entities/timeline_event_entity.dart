enum TimelineEventType { reflection, levelUp, goalComplete, streak }

class TimelineEventEntity {
  const TimelineEventEntity({
    required this.id,
    required this.type,
    required this.title,
    required this.detail,
    required this.timestamp,
  });

  final String id;
  final TimelineEventType type;
  final String title;
  final String detail;
  final DateTime timestamp;

  // Semantic helpers
  bool get isReflection => type == TimelineEventType.reflection;
  bool get isLevelUp => type == TimelineEventType.levelUp;
  bool get isGoalComplete => type == TimelineEventType.goalComplete;
  bool get isStreak => type == TimelineEventType.streak;

  // Recency logic
  Duration get age => DateTime.now().difference(timestamp);
  bool get isRecent => age.inHours < 24;

  // Display helpers
  String get shortLabel {
    switch (type) {
      case TimelineEventType.reflection:
        return 'Reflection';
      case TimelineEventType.levelUp:
        return 'Level Up';
      case TimelineEventType.goalComplete:
        return 'Goal Complete';
      case TimelineEventType.streak:
        return 'Streak';
    }
  }

  // Invariants
  void validate() {
    if (title.trim().isEmpty) {
      throw StateError('TimelineEventEntity must have a title');
    }
    if (detail.trim().isEmpty) {
      throw StateError('TimelineEventEntity must have detail text');
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'title': title,
    'detail': detail,
    'timestamp': timestamp.toIso8601String(),
  };

  factory TimelineEventEntity.fromJson(Map<String, dynamic> j) =>
      TimelineEventEntity(
        id: j['id'] as String,
        type: TimelineEventType.values.firstWhere(
          (e) => e.name == j['type'],
          orElse: () => TimelineEventType.reflection,
        ),
        title: j['title'] as String,
        detail: j['detail'] as String,
        timestamp: DateTime.parse(j['timestamp'] as String),
      );
}
