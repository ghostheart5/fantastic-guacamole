import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_occurrence_entity.dart';
import 'package:fantastic_guacamole/domain/entities/si_v2_contract.dart';
import 'package:fantastic_guacamole/domain/planning/rhythm_planning_context.dart';
import 'package:fantastic_guacamole/engine/patterns/habit_consistency.dart';
import 'package:fantastic_guacamole/state/services/si_v2_read_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Local calendar fields, never real time.
  final DateTime now = DateTime(2026, 8, 20, 12);
  DateTime daysAgo(int n, [int hour = 9]) =>
      DateTime(now.year, now.month, now.day - n, hour);

  HabitOccurrenceEntity record(
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

  HabitEntity daily({
    String id = 'walk',
    int createdDaysAgo = 10,
    int revision = 0,
    DateTime? startedAt,
    HabitStatus status = HabitStatus.active,
  }) => HabitEntity(
    id: id,
    title: 'Walk',
    createdAt: daysAgo(createdDaysAgo),
    frequencyRevision: revision,
    frequencyStartedAt: startedAt,
    status: status,
  );

  test('daily habit done on each of the last 7 days: 7 of 7, streak 7', () {
    final HabitEntity h = daily();
    final HabitConsistency c = HabitConsistency.compute(
      habit: h,
      occurrences: <HabitOccurrenceEntity>[
        for (int i = 0; i < 7; i++) record(h, daysAgo(i)),
      ],
      now: now,
    )!;
    expect(c.windowPeriods, 7);
    expect(c.completed, 7);
    expect(c.missed, 0);
    expect(c.currentStreak, 7);
    expect(c.longestStreak, 7);
    expect(c.checkedInThisPeriod, isTrue);
    expect(c.closedPeriodsSinceTracked, 10);
  });

  test('today not yet checked: streak 6 and today is open, not missed', () {
    final HabitEntity h = daily();
    final HabitConsistency c = HabitConsistency.compute(
      habit: h,
      occurrences: <HabitOccurrenceEntity>[
        for (int i = 1; i < 7; i++) record(h, daysAgo(i)),
      ],
      now: now,
    )!;
    expect(c.currentStreak, 6);
    expect(c.checkedInThisPeriod, isFalse);
    expect(c.currentPeriodOpen, isTrue);
    expect(c.completed, 6);
    expect(c.missed, 0);
    expect(c.windowPeriods, 7);
  });

  test('a gap ends the current streak but not the longest one', () {
    final HabitEntity h = daily(createdDaysAgo: 30);
    final HabitConsistency c = HabitConsistency.compute(
      habit: h,
      occurrences: <HabitOccurrenceEntity>[
        for (final int i in <int>[0, 1, 5, 6, 7, 8, 9]) record(h, daysAgo(i)),
      ],
      now: now,
    )!;
    expect(c.currentStreak, 2);
    expect(c.longestStreak, 5);
    expect(c.completed, 4);
    expect(c.missed, 3); // days 2, 3 and 4 in the 7-day window
  });

  test('weekly habit done in 2 of the last 4 weeks: 2 of 4', () {
    final HabitEntity h = HabitEntity(
      id: 'run',
      title: 'Long run',
      createdAt: daysAgo(90),
      cadence: HabitCadence.weekly,
    );
    final HabitConsistency c = HabitConsistency.compute(
      habit: h,
      occurrences: <HabitOccurrenceEntity>[
        record(h, daysAgo(0)),
        record(h, daysAgo(14)),
      ],
      now: now,
    )!;
    expect(c.windowPeriods, 4);
    expect(c.completed, 2);
    expect(c.missed, 2);
  });

  test('a frequency edit 4 days ago judges only the periods since it', () {
    final HabitEntity h = daily(
      createdDaysAgo: 60,
      revision: 1,
      startedAt: daysAgo(4),
    );
    final HabitConsistency c = HabitConsistency.compute(
      habit: h,
      occurrences: <HabitOccurrenceEntity>[
        record(h, daysAgo(0)),
        record(h, daysAgo(1)),
        record(h, daysAgo(3)),
        // Under the old frequency: a different key, so it is not counted.
        HabitOccurrenceEntity(
          habitId: h.id,
          occurrenceKey: RhythmPlanningContext.periodKey(
            HabitCadence.daily,
            daysAgo(2),
          ),
          operationId: 'old',
          outcome: HabitOccurrenceOutcome.completed,
          recordedAt: daysAgo(2).toUtc(),
        ),
      ],
      now: now,
    )!;
    expect(c.periods.length, 5);
    expect(c.windowPeriods, 5);
    expect(c.completed, 3);
    expect(c.missed, 2);
    expect(c.currentStreak, 2);
  });

  test('paused and archived habits are excluded', () {
    for (final HabitStatus s in <HabitStatus>[
      HabitStatus.paused,
      HabitStatus.archived,
    ]) {
      expect(
        HabitConsistency.compute(
          habit: daily(status: s),
          occurrences: const <HabitOccurrenceEntity>[],
          now: now,
        ),
        isNull,
      );
    }
  });

  test('a window across a daylight-saving change still has 7 days', () {
    final DateTime springNow = DateTime(2026, 3, 11, 12);
    final HabitEntity h = HabitEntity(
      id: 'dst',
      title: 'Stretch',
      createdAt: DateTime(2026, 2, 1),
    );
    final HabitConsistency c = HabitConsistency.compute(
      habit: h,
      occurrences: <HabitOccurrenceEntity>[
        for (int i = 0; i < 7; i++) record(h, DateTime(2026, 3, 11 - i, 9)),
      ],
      now: springNow,
    )!;
    expect(c.windowPeriods, 7);
    expect(c.completed, 7);
    expect(c.currentStreak, 7);
    final HabitConsistency fall = HabitConsistency.compute(
      habit: h,
      occurrences: <HabitOccurrenceEntity>[
        for (int i = 0; i < 7; i++) record(h, DateTime(2026, 11, 3 - i, 9)),
      ],
      now: DateTime(2026, 11, 3, 12),
    )!;
    expect(fall.windowPeriods, 7);
    expect(fall.completed, 7);
  });

  test('monthly habit: one period per month, a skipped one is not missed', () {
    final HabitEntity h = HabitEntity(
      id: 'review',
      title: 'Budget review',
      createdAt: DateTime(2026, 3, 5),
      cadence: HabitCadence.monthly,
    );
    final HabitConsistency c = HabitConsistency.compute(
      habit: h,
      occurrences: <HabitOccurrenceEntity>[
        record(h, DateTime(2026, 8, 3)),
        record(
          h,
          DateTime(2026, 7, 10),
          outcome: HabitOccurrenceOutcome.skipped,
        ),
      ],
      now: now,
      windowPeriods: 3,
    )!;
    expect(c.periods.length, 6); // March to August
    expect(c.closedPeriodsSinceTracked, 5);
    expect(c.windowPeriods, 3);
    expect(c.completed, 1);
    expect(c.skipped, 1);
    expect(c.missed, 1); // June
    expect(c.currentStreak, 1);
  });

  test('other habits and a young habit are handled', () {
    final HabitEntity h = daily(createdDaysAgo: 2);
    final HabitEntity other = daily(id: 'other');
    final HabitConsistency c = HabitConsistency.compute(
      habit: h,
      occurrences: <HabitOccurrenceEntity>[
        record(other, daysAgo(0)),
        record(h, daysAgo(1)),
      ],
      now: now,
    )!;
    expect(c.windowPeriods, 3); // only the days since it was created
    expect(c.completed, 1);
    expect(c.checkedInThisPeriod, isFalse);
  });

  test(
    'current streak matches the read gateway for the same records',
    () async {
      final HabitEntity daily1 = daily(createdDaysAgo: 40);
      final HabitEntity weekly = HabitEntity(
        id: 'weekly',
        title: 'Long run',
        createdAt: daysAgo(90),
        cadence: HabitCadence.weekly,
      );
      final HabitEntity monthly = HabitEntity(
        id: 'monthly',
        title: 'Review',
        createdAt: daysAgo(200),
        cadence: HabitCadence.monthly,
      );
      final HabitEntity edited = daily(
        id: 'edited',
        createdDaysAgo: 60,
        revision: 2,
        startedAt: daysAgo(5),
      );
      final List<HabitEntity> habits = <HabitEntity>[
        daily1,
        weekly,
        monthly,
        edited,
      ];
      final List<HabitOccurrenceEntity> occurrences = <HabitOccurrenceEntity>[
        for (final int i in <int>[1, 2, 3, 4, 8, 9]) record(daily1, daysAgo(i)),
        for (final int i in <int>[0, 7, 14, 28]) record(weekly, daysAgo(i)),
        record(monthly, DateTime(2026, 7, 4)),
        record(monthly, DateTime(2026, 6, 4)),
        for (final int i in <int>[0, 1, 2]) record(edited, daysAgo(i)),
      ];
      final SIV2EvidenceSnapshot snapshot = await SIV2ReadGateway(
        accountScopeId: 'account:test',
        readTasks: () async => const [],
        readGoals: () async => const [],
        readMilestones: () async => const [],
        readTimeline: () async => const [],
        readHabits: () async => habits,
        readHabitOccurrences: () async => occurrences,
      ).read(observedAt: now.toUtc(), includeActivity: true);
      expect(snapshot.habits, hasLength(4));
      for (final SIV2HabitEvidence evidence in snapshot.habits) {
        final HabitEntity habit = habits.firstWhere(
          (HabitEntity h) => h.id == evidence.id,
        );
        final HabitConsistency c = HabitConsistency.compute(
          habit: habit,
          occurrences: occurrences,
          now: now,
        )!;
        expect(c.currentStreak, evidence.currentStreak, reason: habit.id);
        expect(c.checkedInThisPeriod, evidence.checkedInThisPeriod);
      }
    },
  );
}
