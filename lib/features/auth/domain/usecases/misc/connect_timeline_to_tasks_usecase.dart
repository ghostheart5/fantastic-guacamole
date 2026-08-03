import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_connection_entity.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_timeline_repository.dart';
import 'package:fantastic_guacamole/domain/usecases/add_timeline_event.dart';

class ConnectTimelineToTasksUsecase {
  const ConnectTimelineToTasksUsecase(this._repository);

  final ITimelineRepository _repository;

  Future<TaskTimelineLink> call(TaskEntity task) async {
    final DateTime now = DateTime.now();
    final String eventId = 'task_link_${task.id}_${now.microsecondsSinceEpoch}';
    final String projectionKind = _projectionKindFor(task.kind);
    final TimelineEventType eventType = _eventTypeFor(projectionKind);

    final TimelineEventStatus status = task.isCompleted
        ? TimelineEventStatus.completed
        : task.isOverdue
        ? TimelineEventStatus.overdue
        : TimelineEventStatus.active;

    final TimelineEventEntity event = TimelineEventEntity(
      id: eventId,
      type: eventType,
      title: _projectionTitleFor(task.title, projectionKind),
      detail: _projectionDetailFor(task.description, projectionKind),
      timestamp: now,
      status: status,
      dueAt: task.dueDate ?? task.scheduledFor,
      relatedId: task.id,
    );

    await AddTimelineEvent(_repository).call(event);

    return TaskTimelineLink(
      id: 'task_timeline_link_${task.id}_${now.microsecondsSinceEpoch}',
      timelineEventId: eventId,
      targetId: task.id,
      createdAt: now,
      label: event.title,
    );
  }

  String _projectionKindFor(String? kind) {
    return (kind ?? '').trim().toLowerCase();
  }

  TimelineEventType _eventTypeFor(String projectionKind) {
    return switch (projectionKind) {
      'habit' => TimelineEventType.habit,
      'routine' => TimelineEventType.habit,
      'note' => TimelineEventType.task,
      _ => TimelineEventType.task,
    };
  }

  String _projectionTitleFor(String title, String projectionKind) {
    final String normalizedTitle = title.trim().isEmpty
        ? 'Task linked'
        : title.trim();

    return switch (projectionKind) {
      'routine' || 'habit' => 'Habit: $normalizedTitle',
      'note' => 'Note: $normalizedTitle',
      _ => normalizedTitle,
    };
  }

  String _projectionDetailFor(String? description, String projectionKind) {
    final String normalizedDetail = (description ?? '').trim();
    if (normalizedDetail.isNotEmpty) {
      return normalizedDetail;
    }

    return switch (projectionKind) {
      'routine' || 'habit' => 'Habit connected to timeline.',
      'note' => 'Note connected to timeline.',
      _ => 'Task connected to timeline.',
    };
  }
}
