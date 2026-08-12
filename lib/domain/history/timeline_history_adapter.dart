import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/domain/history/history_event.dart';

/// Compatibility boundary between the legacy Timeline read model and facts.
class TimelineHistoryAdapter {
  const TimelineHistoryAdapter._();

  static HistoryEvent toHistory(TimelineEventEntity event) {
    final String title = event.title.trim().toLowerCase();
    final String legacyType = event.type.name;
    return HistoryEvent(
      id: event.id,
      kind: _kindFor(event.type, title),
      occurredAt: event.timestamp.toUtc(),
      entityType: _entityTypeFor(event.type),
      entityId: _emptyToNull(event.relatedId),
      source: HistoryEventSource.unknown,
      legacyKind: _isProjection(event.type) ? legacyType : null,
      payload: <String, dynamic>{
        'timelineType': legacyType,
        'title': event.title,
        'detail': event.detail,
        'status': event.status.name,
        'dueAt': event.dueAt?.toUtc().toIso8601String(),
        'phase': event.phase,
      },
    );
  }

  static HistoryEvent fromLegacyJson(Map<String, dynamic> json) {
    final TimelineEventEntity event = TimelineEventEntity.fromJson(json);
    final String rawType = json['type']?.toString() ?? 'unknown';
    final HistoryEvent converted = toHistory(event);
    final bool known = TimelineEventType.values.any(
      (TimelineEventType type) => type.name == rawType,
    );
    if (known) return converted;
    return HistoryEvent(
      id: converted.id,
      kind: HistoryEventKind.legacyTimeline,
      occurredAt: converted.occurredAt,
      entityType: converted.entityType,
      entityId: converted.entityId,
      source: HistoryEventSource.unknown,
      legacyKind: rawType,
      payload: <String, dynamic>{...converted.payload, 'legacyTimeline': json},
    );
  }

  static TimelineEventEntity toTimeline(HistoryEvent event) {
    final Map<String, dynamic> payload = event.payload;
    final String rawType = event.isLegacy
        ? (event.legacyKind ?? payload['timelineType']?.toString() ?? '')
        : payload['timelineType']?.toString() ?? _timelineTypeFor(event.kind).name;
    return TimelineEventEntity(
      id: event.id,
      type: TimelineEventType.values.firstWhere(
        (TimelineEventType type) => type.name == rawType,
        orElse: () => TimelineEventType.reflection,
      ),
      title: payload['title']?.toString() ?? event.kind.name,
      detail: payload['detail']?.toString() ?? '',
      timestamp: event.occurredAt.toLocal(),
      status: TimelineEventStatus.values.firstWhere(
        (TimelineEventStatus status) => status.name == payload['status']?.toString(),
        orElse: () => TimelineEventStatus.info,
      ),
      dueAt: DateTime.tryParse(payload['dueAt']?.toString() ?? '')?.toLocal(),
      phase: payload['phase']?.toString(),
      relatedId: event.entityId,
    );
  }

  static HistoryEventKind _kindFor(TimelineEventType type, String title) {
    if (type == TimelineEventType.reflection) {
      if (title.startsWith('task completed')) return HistoryEventKind.taskCompleted;
      if (title.startsWith('task skipped')) return HistoryEventKind.taskSkipped;
      if (title.startsWith('task added')) return HistoryEventKind.taskCreated;
      if (title.startsWith('task delayed') || title.startsWith('task not completed')) {
        return HistoryEventKind.taskRescheduled;
      }
      return HistoryEventKind.reflectionRecorded;
    }
    return switch (type) {
      TimelineEventType.goalComplete => HistoryEventKind.goalCompleted,
      TimelineEventType.levelUp || TimelineEventType.milestone => HistoryEventKind.milestoneReached,
      TimelineEventType.streak => HistoryEventKind.streakRecorded,
      TimelineEventType.deadline => HistoryEventKind.deadlineScheduled,
      TimelineEventType.task => HistoryEventKind.taskScheduled,
      TimelineEventType.goal => HistoryEventKind.goalScheduled,
      TimelineEventType.habit => HistoryEventKind.habitScheduled,
      TimelineEventType.project => HistoryEventKind.projectUpdated,
      TimelineEventType.forecast || TimelineEventType.snapshot || TimelineEventType.risk || TimelineEventType.recommendation => HistoryEventKind.legacyTimeline,
      TimelineEventType.reflection => HistoryEventKind.reflectionRecorded,
    };
  }

  static HistoryEntityType _entityTypeFor(TimelineEventType type) => switch (type) {
    TimelineEventType.task || TimelineEventType.deadline => HistoryEntityType.task,
    TimelineEventType.goal || TimelineEventType.goalComplete => HistoryEntityType.goal,
    TimelineEventType.habit => HistoryEntityType.habit,
    TimelineEventType.project => HistoryEntityType.project,
    TimelineEventType.milestone || TimelineEventType.levelUp => HistoryEntityType.milestone,
    TimelineEventType.reflection => HistoryEntityType.reflection,
    _ => HistoryEntityType.unknown,
  };

  static TimelineEventType _timelineTypeFor(HistoryEventKind kind) => switch (kind) {
    HistoryEventKind.goalCompleted => TimelineEventType.goalComplete,
    HistoryEventKind.milestoneReached => TimelineEventType.milestone,
    HistoryEventKind.streakRecorded => TimelineEventType.streak,
    HistoryEventKind.deadlineScheduled => TimelineEventType.deadline,
    HistoryEventKind.taskScheduled => TimelineEventType.task,
    HistoryEventKind.goalScheduled => TimelineEventType.goal,
    HistoryEventKind.habitScheduled => TimelineEventType.habit,
    HistoryEventKind.projectUpdated => TimelineEventType.project,
    _ => TimelineEventType.reflection,
  };

  static bool _isProjection(TimelineEventType type) => switch (type) {
    TimelineEventType.forecast || TimelineEventType.snapshot || TimelineEventType.risk || TimelineEventType.recommendation => true,
    _ => false,
  };

  static String? _emptyToNull(String? value) {
    final String trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }
}
