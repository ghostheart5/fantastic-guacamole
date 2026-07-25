enum TimelineConnectionType { goal, task, project, habit }

class TimelineConnectionEntity {
  const TimelineConnectionEntity({
    required this.id,
    required this.timelineEventId,
    required this.targetId,
    required this.type,
    required this.createdAt,
    this.label,
  });

  final String id;
  final String timelineEventId;
  final String targetId;
  final TimelineConnectionType type;
  final DateTime createdAt;
  final String? label;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'timelineEventId': timelineEventId,
      'targetId': targetId,
      'type': type.name,
      'createdAt': createdAt.toIso8601String(),
      'label': label,
    };
  }

  factory TimelineConnectionEntity.fromJson(Map<String, dynamic> json) {
    return TimelineConnectionEntity(
      id: json['id']?.toString() ?? '',
      timelineEventId: json['timelineEventId']?.toString() ?? '',
      targetId: json['targetId']?.toString() ?? '',
      type: TimelineConnectionType.values.firstWhere(
        (TimelineConnectionType value) =>
            value.name == json['type']?.toString(),
        orElse: () => TimelineConnectionType.goal,
      ),
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      label: json['label']?.toString(),
    );
  }
}

class GoalTimelineLink extends TimelineConnectionEntity {
  const GoalTimelineLink({
    required super.id,
    required super.timelineEventId,
    required super.targetId,
    required super.createdAt,
    super.label,
  }) : super(type: TimelineConnectionType.goal);
}

class TaskTimelineLink extends TimelineConnectionEntity {
  const TaskTimelineLink({
    required super.id,
    required super.timelineEventId,
    required super.targetId,
    required super.createdAt,
    super.label,
  }) : super(type: TimelineConnectionType.task);
}

class ProjectTimelineLink extends TimelineConnectionEntity {
  const ProjectTimelineLink({
    required super.id,
    required super.timelineEventId,
    required super.targetId,
    required super.createdAt,
    super.label,
  }) : super(type: TimelineConnectionType.project);
}

class HabitTimelineLink extends TimelineConnectionEntity {
  const HabitTimelineLink({
    required super.id,
    required super.timelineEventId,
    required super.targetId,
    required super.createdAt,
    super.label,
  }) : super(type: TimelineConnectionType.habit);
}
