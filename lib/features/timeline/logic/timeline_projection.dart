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
      final bool overdue = task.isOverdueAt(now);
      final DateTime? scheduled = task.scheduledFor?.toLocal();
      final String scheduleContext = scheduled == null
          ? ''
          : ' Planned work time: ${scheduled.year}-${scheduled.month.toString().padLeft(2, '0')}-${scheduled.day.toString().padLeft(2, '0')} '
                '${scheduled.hour.toString().padLeft(2, '0')}:${scheduled.minute.toString().padLeft(2, '0')}.';
      events.add(
        TimelineEventEntity(
          id: 'timeline-projected-task-${task.id}',
          type: TimelineEventType.deadline,
          title: task.title,
          detail: overdue
              ? 'Task deadline missed. Re-plan this task immediately.$scheduleContext'
              : 'Task deadline is upcoming.$scheduleContext',
          timestamp: now,
          status: overdue
              ? TimelineEventStatus.overdue
              : TimelineEventStatus.planned,
          dueAt: deadline,
          dateOnly: task.hasDateOnlyDeadline,
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
    // Goal targets come from a date picker: the whole local day is available.
    // Task deadlines above distinguish date-only choices from precise times.
    final localTarget = target.toLocal();
    final localNow = now.toLocal();
    final targetDay = DateTime(
      localTarget.year,
      localTarget.month,
      localTarget.day,
    );
    final today = DateTime(localNow.year, localNow.month, localNow.day);
    final bool overdue = targetDay.isBefore(today);
    events.add(
      TimelineEventEntity(
        id: 'timeline-projected-goal-${goal.id}',
        type: TimelineEventType.goal,
        title: goal.title,
        detail: overdue
            ? 'Goal target date has passed. Recovery plan needed.'
            : targetDay == today
            ? 'Goal target date is today.'
            : 'Goal target date is upcoming.',
        timestamp: now,
        status: overdue
            ? TimelineEventStatus.overdue
            : TimelineEventStatus.active,
        dueAt: target,
        dateOnly: true,
        phase: 'goal',
        relatedId: goal.id,
      ),
    );
  }

  return events;
}
