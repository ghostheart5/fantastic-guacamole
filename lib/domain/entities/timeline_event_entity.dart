enum TimelineEventType {
  focusSession,
  reflection,
  levelUp,
  goalComplete,
  streak,
}

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
          orElse: () => TimelineEventType.focusSession,
        ),
        title: j['title'] as String,
        detail: j['detail'] as String,
        timestamp: DateTime.parse(j['timestamp'] as String),
      );
}
