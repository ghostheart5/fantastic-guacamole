import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/features/timeline/logic/timeline_projection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final DateTime now = DateTime.utc(2026, 8, 29, 12);

  for (final hour in [0, 2, 12, 23]) {
    test('goal remains due today at $hour:59, including UTC storage', () {
      final today = DateTime(2026, 9, 13);
      final reference = DateTime(2026, 9, 13, hour, 59, 59);
      for (final target in [today, today.toUtc()]) {
        final event = projectTimelineEvents(
          now: reference,
          tasks: const [],
          goals: [_goal('today', target)],
        ).single;
        expect(event.status, TimelineEventStatus.active);
        expect(event.detail, 'Goal target date is today.');
        expect(event.dueAt, target);
        expect(event.isUpcomingAt(reference), isTrue);
      }
    });
  }

  test(
    'goal date boundaries respect yesterday, tomorrow and seven-day horizon',
    () {
      final reference = DateTime(
        2026,
        11,
        1,
        23,
        59,
      ); // DST boundary in US zones.
      final events = projectTimelineEvents(
        now: reference,
        tasks: const [],
        goals: [
          _goal('yesterday', DateTime(2026, 10, 31)),
          _goal('tomorrow', DateTime(2026, 11, 2)),
          _goal('seven', DateTime(2026, 11, 8)),
          _goal('eight', DateTime(2026, 11, 9)),
        ],
      );
      expect(events.map((e) => e.isOverdue), [true, false, false, false]);
      expect(events.map((e) => e.isUpcomingAt(reference)), [
        false,
        true,
        true,
        false,
      ]);
      final afterMidnight = projectTimelineEvents(
        now: DateTime(2026, 9, 14),
        tasks: const [],
        goals: [_goal('ended', DateTime(2026, 9, 13))],
      ).single;
      expect(afterMidnight.isOverdue, isTrue);
    },
  );

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
    expect(event.detail, contains('Planned work time'));
  });

  test('a Creator date-only deadline remains upcoming throughout its day', () {
    final date = DateTime(2026, 9, 16);
    final afternoon = DateTime(2026, 9, 16, 18, 30);
    final event = projectTimelineEvents(
      now: afternoon,
      tasks: [_task('grocery', dueDate: date)],
      goals: const [],
    ).single;

    expect(event.dateOnly, isTrue);
    expect(event.dueAt, date);
    expect(event.status, TimelineEventStatus.planned);
    expect(event.isUpcomingAt(afternoon), isTrue);

    final nextDay = DateTime(2026, 9, 17);
    final expired = projectTimelineEvents(
      now: nextDay,
      tasks: [_task('grocery', dueDate: date)],
      goals: const [],
    ).single;
    expect(expired.isOverdue, isTrue);
    expect(expired.isUpcomingAt(nextDay), isFalse);
  });

  test(
    'a task with an explicit deadline time keeps precise time semantics',
    () {
      final due = DateTime(2026, 9, 16, 16);
      final before = DateTime(2026, 9, 16, 15, 59);
      final event = projectTimelineEvents(
        now: before,
        tasks: [_task('call', dueDate: due)],
        goals: const [],
      ).single;

      expect(event.dateOnly, isFalse);
      expect(event.isUpcomingAt(before), isTrue);
      final late = projectTimelineEvents(
        now: DateTime(2026, 9, 16, 16, 1),
        tasks: [_task('call', dueDate: due)],
        goals: const [],
      ).single;
      expect(late.isOverdue, isTrue);
    },
  );

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
