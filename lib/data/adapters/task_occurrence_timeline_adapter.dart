import 'package:fantastic_guacamole/domain/entities/task_occurrence_entity.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_timeline_repository.dart';

/// Projects durable task-occurrence transitions into Timeline.
///
/// Timeline is a read model here: the typed occurrence transition remains the
/// sole source of outcome semantics and this adapter is safe to invoke again
/// after a projection failure or restart.
class TaskOccurrenceTimelineAdapter {
  const TaskOccurrenceTimelineAdapter(this._timeline);

  final ITimelineRepository _timeline;

  Future<void> record(TaskOccurrence occurrence, {String? taskTitle}) async {
    for (final TaskOccurrenceTransition transition in occurrence.transitions) {
      await recordTransition(occurrence, transition, taskTitle: taskTitle);
    }
  }

  Future<void> recordTransition(
    TaskOccurrence occurrence,
    TaskOccurrenceTransition transition, {
    String? taskTitle,
  }) async {
    final String id = eventIdFor(occurrence, transition);
    if (_timeline.getEvents().any(
      (TimelineEventEntity event) => event.id == id,
    )) {
      return;
    }
    await _timeline.addEvent(
      TimelineEventEntity(
        id: id,
        type: _timelineTypeFor(transition.outcome),
        title: _titleFor(transition.outcome),
        detail: _detailFor(occurrence, transition, taskTitle),
        timestamp: transition.at,
        status: transition.outcome == TaskOccurrenceOutcome.completed
            ? TimelineEventStatus.completed
            : TimelineEventStatus.info,
        relatedId: occurrence.taskId,
      ),
    );
  }

  static String eventIdFor(
    TaskOccurrence occurrence,
    TaskOccurrenceTransition transition,
  ) => 'task-occurrence:${occurrence.id}:${transition.operationId}';

  static TimelineEventType _timelineTypeFor(TaskOccurrenceOutcome outcome) =>
      switch (outcome) {
        TaskOccurrenceOutcome.completed => TimelineEventType.taskCompleted,
        TaskOccurrenceOutcome.skipped => TimelineEventType.taskSkipped,
        TaskOccurrenceOutcome.rescheduled => TimelineEventType.taskRescheduled,
      };

  static String _titleFor(TaskOccurrenceOutcome outcome) => switch (outcome) {
    TaskOccurrenceOutcome.completed => 'Task completed',
    TaskOccurrenceOutcome.skipped => 'Task skipped',
    TaskOccurrenceOutcome.rescheduled => 'Task rescheduled',
  };

  static String _detailFor(
    TaskOccurrence occurrence,
    TaskOccurrenceTransition transition,
    String? taskTitle,
  ) {
    final String label = taskTitle?.trim().isNotEmpty == true
        ? taskTitle!.trim()
        : occurrence.taskId;
    return 'task=$label; occurrenceId=${occurrence.id}; '
        'operationId=${transition.operationId}; outcome=${transition.outcome.name}; '
        'rescheduledTo=${transition.rescheduledFor?.toUtc().toIso8601String() ?? ''}';
  }
}
