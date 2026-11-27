import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_occurrence_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/planning/rhythm_planning_context.dart';
import 'package:fantastic_guacamole/engine/patterns/activity_record.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final DateTime now = DateTime(2026, 8, 20, 12);
  DateTime daysAgo(int n, [int hour = 9]) =>
      DateTime(now.year, now.month, now.day - n, hour);

  final HabitEntity walk = HabitEntity(
    id: 'walk',
    title: 'Walk',
    createdAt: daysAgo(60),
  );
  final HabitEntity other = HabitEntity(
    id: 'other',
    title: 'Other',
    createdAt: daysAgo(60),
  );

  HabitOccurrenceEntity occurrence(
    HabitEntity habit,
    DateTime at, {
    HabitOccurrenceOutcome outcome = HabitOccurrenceOutcome.completed,
  }) => HabitOccurrenceEntity(
    habitId: habit.id,
    occurrenceKey: RhythmPlanningContext.occurrenceKey(habit, at),
    operationId: 'op-${habit.id}-${at.toIso8601String()}',
    outcome: outcome,
    recordedAt: at.toUtc(),
  );

  TaskEntity task(
    String id, {
    bool completed = false,
    bool skipped = false,
    bool canceled = false,
    DateTime? completedAt,
    DateTime? skippedAt,
    String title = 'Task',
  }) => TaskEntity(
    id: id,
    title: title,
    createdAt: daysAgo(30),
    isCompleted: completed,
    completedAt: completedAt,
    isSkipped: skipped,
    skippedAt: skippedAt,
    isCanceled: canceled,
  );

  test('a habit check-in and a task completion on one day both appear', () {
    final List<ActivityRecord> records = activityRecords(
      tasks: <TaskEntity>[
        task('t1', completed: true, completedAt: daysAgo(0, 8)),
      ],
      habits: <HabitEntity>[walk],
      occurrences: <HabitOccurrenceEntity>[occurrence(walk, daysAgo(0, 10))],
      now: now,
    );
    expect(records.map((ActivityRecord r) => r.kind), <ActivityKind>[
      ActivityKind.habit,
      ActivityKind.task,
    ]);
    expect(records.first.subjectId, 'walk');
    expect(records.first.outcome, ActivityOutcome.done);
    expect(records.first.periodKey, isNotNull);
    expect(records.last.periodKey, isNull);
    expect(records.last.at, daysAgo(0, 8));
  });

  test('canceled, untimed and out-of-window records never appear', () {
    final List<ActivityRecord> records = activityRecords(
      tasks: <TaskEntity>[
        task('c', completed: true, completedAt: daysAgo(1), canceled: true),
        task('no-time', completed: true),
        task('old', completed: true, completedAt: daysAgo(7)),
        task('open'),
        task('skip', skipped: true, skippedAt: daysAgo(6)),
      ],
      habits: <HabitEntity>[walk],
      occurrences: <HabitOccurrenceEntity>[
        occurrence(walk, daysAgo(7)),
        occurrence(walk, daysAgo(2), outcome: HabitOccurrenceOutcome.skipped),
      ],
      now: now,
    );
    expect(records.map((ActivityRecord r) => r.subjectId), <String>[
      'walk',
      'skip',
    ]);
    expect(records.first.outcome, ActivityOutcome.skipped);
    expect(records.last.outcome, ActivityOutcome.skipped);
  });

  test('another habit or an unknown habit does not leak in', () {
    expect(activityFromHabitOccurrence(walk, occurrence(other, now)), isNull);
    expect(
      activityFromHabit(walk, <HabitOccurrenceEntity>[
        occurrence(other, daysAgo(0)),
        occurrence(walk, daysAgo(1)),
      ]).map((ActivityRecord r) => r.subjectId),
      <String>['walk'],
    );
    final List<ActivityRecord> records = activityRecords(
      tasks: const <TaskEntity>[],
      habits: <HabitEntity>[walk],
      occurrences: <HabitOccurrenceEntity>[
        occurrence(other, daysAgo(0)),
        occurrence(walk, daysAgo(0)),
      ],
      now: now,
    );
    expect(records.map((ActivityRecord r) => r.subjectId), <String>['walk']);
  });

  test('a task with an empty title is dropped and a habit keeps history', () {
    expect(
      activityFromTask(
        task('x', completed: true, completedAt: now, title: '  '),
      ),
      isNull,
    );
    final HabitEntity paused = walk.copyWith(status: HabitStatus.paused);
    expect(
      activityRecords(
        tasks: const <TaskEntity>[],
        habits: <HabitEntity>[paused],
        occurrences: <HabitOccurrenceEntity>[occurrence(paused, daysAgo(1))],
        now: now,
      ),
      hasLength(1),
    );
  });

  test(
    'records at one moment order by kind then id, and are de-duplicated',
    () {
      final DateTime at = daysAgo(0, 8);
      final HabitOccurrenceEntity first = occurrence(walk, at);
      final List<TaskEntity> tasks = <TaskEntity>[
        task('b', completed: true, completedAt: at),
        task('a', completed: true, completedAt: at),
        // The same task listed twice.
        task('a', completed: true, completedAt: at),
      ];
      List<String> ids(
        Iterable<TaskEntity> t,
        Iterable<HabitOccurrenceEntity> o,
      ) => activityRecords(
        tasks: t,
        habits: <HabitEntity>[walk],
        occurrences: o,
        now: now,
      ).map((ActivityRecord r) => '${r.kind.name}:${r.subjectId}').toList();
      final List<String> forward = ids(tasks, <HabitOccurrenceEntity>[
        first,
        first,
      ]);
      expect(forward, <String>['task:a', 'task:b', 'habit:walk']);
      expect(ids(tasks.reversed, <HabitOccurrenceEntity>[first]), forward);
    },
  );

  test('one period with a check-in and a later skip: the check-in is kept', () {
    final List<ActivityRecord> records = activityRecords(
      tasks: const <TaskEntity>[],
      habits: <HabitEntity>[walk],
      occurrences: <HabitOccurrenceEntity>[
        occurrence(walk, daysAgo(0, 8)),
        occurrence(
          walk,
          daysAgo(0, 10),
          outcome: HabitOccurrenceOutcome.skipped,
        ),
      ],
      now: now,
    );
    expect(records, hasLength(1));
    expect(records.single.outcome, ActivityOutcome.done);
    expect(records.single.at, daysAgo(0, 8).toUtc());
  });

  test('two check-ins for one period: the newest is kept', () {
    final List<ActivityRecord> records = activityRecords(
      tasks: const <TaskEntity>[],
      habits: <HabitEntity>[walk],
      occurrences: <HabitOccurrenceEntity>[
        occurrence(walk, daysAgo(0, 8)),
        occurrence(walk, daysAgo(0, 11)),
      ],
      now: now,
    );
    expect(records, hasLength(1));
    expect(records.single.at, daysAgo(0, 11).toUtc());
  });

  test('the window is applied before de-duplicating', () {
    final HabitEntity monthly = HabitEntity(
      id: 'monthly',
      title: 'Monthly review',
      cadence: HabitCadence.monthly,
      createdAt: daysAgo(90),
    );
    // Same month, so the same period: a check-in 7 days ago (outside the
    // 7-day window) and a skip today (inside it).
    final HabitOccurrenceEntity done = occurrence(monthly, daysAgo(7));
    final HabitOccurrenceEntity skipped = occurrence(
      monthly,
      daysAgo(0, 8),
      outcome: HabitOccurrenceOutcome.skipped,
    );
    expect(done.occurrenceKey, skipped.occurrenceKey);
    final List<ActivityRecord> records = activityRecords(
      tasks: const <TaskEntity>[],
      habits: <HabitEntity>[monthly],
      occurrences: <HabitOccurrenceEntity>[done, skipped],
      now: now,
    );
    // The check-in outside the window cannot hide the skip inside it.
    expect(records, hasLength(1));
    expect(records.single.outcome, ActivityOutcome.skipped);
  });

  test('ActivityRecord compares by value', () {
    final DateTime at = daysAgo(1);
    ActivityRecord make(String title) => ActivityRecord(
      kind: ActivityKind.task,
      subjectId: 'x',
      title: title,
      outcome: ActivityOutcome.done,
      at: at,
    );
    expect(make('X'), make('X'));
    expect(make('X').hashCode, make('X').hashCode);
    expect(make('X') == make('Y'), isFalse);
  });

  test('check-ins of a habit that is no longer saved are dropped', () {
    expect(
      activityRecords(
        tasks: const <TaskEntity>[],
        habits: const <HabitEntity>[],
        occurrences: <HabitOccurrenceEntity>[occurrence(walk, daysAgo(0))],
        now: now,
      ),
      isEmpty,
    );
  });
}
