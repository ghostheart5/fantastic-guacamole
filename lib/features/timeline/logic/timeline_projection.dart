import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';

/// Derives Timeline entries only for work that still needs attention.
List<TimelineEventEntity> projectTimelineEvents({
  required DateTime now,
  required List<Task> tasks,
  required List<GoalEntity> goals,
}) {
  final List<TimelineEventEntity> events = <TimelineEventEntity>[];

  for (final Task task in tasks) {
    if (task.isCompleted || task.isSkipped || task.isCanceled) {
      continue;
    }
    final DateTime? deadline = task.dueDate;
    if (deadline != null) {
      final bool overdue = deadline.isBefore(now);
      events.add(
        TimelineEventEntity(
          id: 'timeline-projected-task-${task.id}',
          type: TimelineEventType.deadline,
          title: task.title,
          detail: overdue
              ? 'Task deadline missed. Re-plan this task immediately.'
              : 'Task deadline is upcoming.',
          timestamp: now,
          status: overdue
              ? TimelineEventStatus.overdue
              : TimelineEventStatus.planned,
          dueAt: deadline,
          phase: 'task',
          relatedId: task.id,
        ),
      );
      continue;
    }

    final DateTime? scheduled = task.scheduledFor;
    if (scheduled == null) {
      continue;
    }
    events.add(
      TimelineEventEntity(
        id: 'timeline-projected-task-${task.id}',
        type: TimelineEventType.task,
        title: task.title,
        detail: scheduled.isBefore(now)
            ? 'Scheduled work time has passed. The task remains open; no deadline was missed.'
            : 'Task is scheduled for a planned work time.',
        timestamp: now,
        status: scheduled.isBefore(now)
            ? TimelineEventStatus.active
            : TimelineEventStatus.planned,
        dueAt: scheduled,
        phase: 'task',
        relatedId: task.id,
      ),
    );
  }

  for (final GoalEntity goal in goals) {
    if (!goal.isActive) {
      continue;
    }
    final DateTime? target = goal.targetDate;
    if (target == null) {
      continue;
    }
    final bool overdue = target.isBefore(now);
    events.add(
      TimelineEventEntity(
        id: 'timeline-projected-goal-${goal.id}',
        type: TimelineEventType.goal,
        title: goal.title,
        detail: overdue
            ? 'Goal target date has passed. Recovery plan needed.'
            : 'Goal target date is upcoming.',
        timestamp: now,
        status: overdue
            ? TimelineEventStatus.overdue
            : TimelineEventStatus.active,
        dueAt: target,
        phase: 'goal',
        relatedId: goal.id,
      ),
    );
  }

  return events;
}
