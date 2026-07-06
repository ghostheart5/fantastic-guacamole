abstract class DomainEvent {
  DomainEvent({DateTime? occurredAt}) : occurredAt = occurredAt ?? DateTime.now();

  final DateTime occurredAt;
}

class TaskLifecycleEvent extends DomainEvent {
  TaskLifecycleEvent({
    required this.taskId,
    required this.title,
    required this.action,
    super.occurredAt,
  });

  final String taskId;
  final String title;
  final String action;
}

class GoalLifecycleEvent extends DomainEvent {
  GoalLifecycleEvent({
    required this.goalId,
    required this.title,
    required this.action,
    super.occurredAt,
  });

  final String goalId;
  final String title;
  final String action;
}

class InsightLifecycleEvent extends DomainEvent {
  InsightLifecycleEvent({required this.summary, required this.titles, super.occurredAt});

  final String summary;
  final List<String> titles;
}

class FlowmapLifecycleEvent extends DomainEvent {
  FlowmapLifecycleEvent({
    required this.nodeId,
    required this.title,
    required this.action,
    super.occurredAt,
  });

  final String nodeId;
  final String title;
  final String action;
}

class LogLifecycleEvent extends DomainEvent {
  LogLifecycleEvent({
    required this.logId,
    required this.source,
    required this.message,
    super.occurredAt,
  });

  final String logId;
  final String source;
  final String message;
}

class TimelineLifecycleEvent extends DomainEvent {
  TimelineLifecycleEvent({
    required this.eventId,
    required this.title,
    required this.type,
    super.occurredAt,
  });

  final String eventId;
  final String title;
  final String type;
}

class ProgressionLifecycleEvent extends DomainEvent {
  ProgressionLifecycleEvent({
    required this.xp,
    required this.level,
    required this.streak,
    required this.action,
    super.occurredAt,
  });

  final int xp;
  final int level;
  final int streak;
  final String action;
}

class MemoryLifecycleEvent extends DomainEvent {
  MemoryLifecycleEvent({required this.memoryId, required this.text, super.occurredAt});

  final String memoryId;
  final String text;
}

class NotificationLifecycleEvent extends DomainEvent {
  NotificationLifecycleEvent({
    required this.notificationId,
    required this.title,
    required this.action,
    super.occurredAt,
  });

  final String notificationId;
  final String title;
  final String action;
}
