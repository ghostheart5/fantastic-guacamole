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

    final TimelineEventStatus status = task.isCompleted
        ? TimelineEventStatus.completed
        : task.isOverdue
        ? TimelineEventStatus.overdue
        : TimelineEventStatus.active;

    final TimelineEventEntity event = TimelineEventEntity(
      id: eventId,
      type: TimelineEventType.task,
      title: task.title.trim().isEmpty ? 'Task linked' : task.title.trim(),
      detail: (task.description ?? 'Task connected to timeline.').trim(),
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
}
