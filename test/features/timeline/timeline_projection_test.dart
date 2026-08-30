import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/features/timeline/logic/timeline_projection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final DateTime now = DateTime.utc(2026, 8, 29, 12);

  test('projects only active tasks and goals that still need attention', () {
    final List<TimelineEventEntity> events = projectTimelineEvents(
      now: now,
      tasks: <Task>[
        _task('active', dueDate: now.add(const Duration(days: 1))),
        _task(
          'completed',
          dueDate: now.subtract(const Duration(days: 1)),
          isCompleted: true,
        ),
        _task(
          'skipped',
          dueDate: now.subtract(const Duration(days: 1)),
          isSkipped: true,
        ),
        _task(
          'canceled',
          dueDate: now.subtract(const Duration(days: 1)),
          isCanceled: true,
        ),
      ],
      goals: <GoalEntity>[
        _goal('active-goal', now.add(const Duration(days: 2))),
        _goal(
          'completed-goal',
          now.subtract(const Duration(days: 1)),
          completedAt: now,
        ),
      ],
    );

    expect(events.map((event) => event.id), <String>[
      'timeline-projected-task-active',
      'timeline-projected-goal-active-goal',
    ]);
  });

  test('a past schedule never overrides a later task deadline', () {
    final DateTime scheduled = now.subtract(const Duration(hours: 2));
    final DateTime deadline = now.add(const Duration(days: 1));

    final TimelineEventEntity event = projectTimelineEvents(
      now: now,
      tasks: <Task>[
        _task(
          'scheduled-before-due',
          scheduledFor: scheduled,
          dueDate: deadline,
        ),
      ],
      goals: const <GoalEntity>[],
    ).single;

    expect(event.type, TimelineEventType.deadline);
    expect(event.dueAt, deadline);
    expect(event.status, TimelineEventStatus.planned);
    expect(event.isOverdue, isFalse);
    expect(event.detail, isNot(contains('missed')));
  });

  test('a past schedule-only task stays open without becoming overdue', () {
    final DateTime scheduled = now.subtract(const Duration(hours: 2));

    final TimelineEventEntity event = projectTimelineEvents(
      now: now,
      tasks: <Task>[_task('schedule-only', scheduledFor: scheduled)],
      goals: const <GoalEntity>[],
    ).single;

    expect(event.type, TimelineEventType.task);
    expect(event.dueAt, scheduled);
    expect(event.status, TimelineEventStatus.active);
    expect(event.isOverdue, isFalse);
    expect(event.detail, contains('no deadline was missed'));
  });

  test('an expired due date remains overdue despite a later schedule', () {
    final DateTime deadline = now.subtract(const Duration(hours: 1));

    final TimelineEventEntity event = projectTimelineEvents(
      now: now,
      tasks: <Task>[
        _task(
          'genuinely-overdue',
          scheduledFor: now.add(const Duration(days: 1)),
          dueDate: deadline,
        ),
      ],
      goals: const <GoalEntity>[],
    ).single;

    expect(event.type, TimelineEventType.deadline);
    expect(event.dueAt, deadline);
    expect(event.status, TimelineEventStatus.overdue);
    expect(event.detail, contains('deadline missed'));
  });
}

Task _task(
  String id, {
  DateTime? scheduledFor,
  DateTime? dueDate,
  bool isCompleted = false,
  bool isSkipped = false,
  bool isCanceled = false,
}) => Task(
  id: id,
  title: id,
  priority: 3,
  difficulty: 2,
  energyRequired: 2,
  scheduledFor: scheduledFor,
  dueDate: dueDate,
  isCompleted: isCompleted,
  isSkipped: isSkipped,
  isCanceled: isCanceled,
);

GoalEntity _goal(String id, DateTime targetDate, {DateTime? completedAt}) =>
    GoalEntity(
      id: id,
      title: id,
      createdAt: DateTime.utc(2026, 1, 1),
      targetDate: targetDate,
      completedAt: completedAt,
    );
