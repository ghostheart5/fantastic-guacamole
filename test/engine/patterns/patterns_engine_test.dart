import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_occurrence_entity.dart';
import 'package:fantastic_guacamole/domain/entities/si_one_tap_question.dart';
import 'package:fantastic_guacamole/domain/entities/si_v2_contract.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/planning/rhythm_planning_context.dart';
import 'package:fantastic_guacamole/engine/patterns/habit_consistency.dart';
import 'package:fantastic_guacamole/engine/patterns/patterns_engine.dart';
import 'package:fantastic_guacamole/engine/si/si_one_tap_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Tuesday 2026-12-01 10:00 local. Fixtures use calendar fields only.
  final DateTime now = DateTime(2026, 12, 1, 10);
  DateTime at(int daysAgo, [int hour = 9]) =>
      DateTime(now.year, now.month, now.day - daysAgo, hour);

  TaskEntity finished(String id, DateTime when) => TaskEntity(
    id: id,
    title: 'Done $id',
    createdAt: at(40),
    isCompleted: true,
    completedAt: when,
  );

  TaskEntity skipped(String id, DateTime when) => TaskEntity(
    id: id,
    title: 'Skipped $id',
    createdAt: at(40),
    isSkipped: true,
    skippedAt: when,
  );

  HabitEntity daily({String id = 'walk', int createdDaysAgo = 40}) =>
      HabitEntity(id: id, title: 'Walk', createdAt: at(createdDaysAgo));

  HabitOccurrenceEntity checkIn(
    HabitEntity habit,
    DateTime when, {
    HabitOccurrenceOutcome outcome = HabitOccurrenceOutcome.completed,
  }) => HabitOccurrenceEntity(
    habitId: habit.id,
    occurrenceKey: RhythmPlanningContext.occurrenceKey(habit, when),
    operationId: 'op-${habit.id}-${when.toIso8601String()}',
    outcome: outcome,
    recordedAt: when.toUtc(),
  );

  PatternsResult run({
    List<TaskEntity> tasks = const <TaskEntity>[],
    List<HabitEntity> habits = const <HabitEntity>[],
    List<HabitOccurrenceEntity> occurrences = const <HabitOccurrenceEntity>[],
    int range = 7,
    DateTime? clock,
  }) => PatternsEngine.compute(
    tasks: tasks,
    habits: habits,
    occurrences: occurrences,
    now: clock ?? now,
    rangeDays: range,
  );

  group('when things get done', () {
    // 2026-11-30, 11-23 and 11-16 are Mondays.
    final List<TaskEntity> mondays = <TaskEntity>[
      finished('m1', at(1)),
      finished('m2', at(8)),
      finished('m3', at(15)),
      finished('tue', at(0, 8)),
      finished('wed', at(6)),
    ];

    test('names Monday with 3 of 5 and more than any other day', () {
      for (final int range in <int>[7, 30]) {
        final WhenThingsGetDone v = run(
          tasks: mondays,
          range: range,
        ).whenDone.value;
        expect(v.weekday, DateTime.monday, reason: 'range $range');
        expect(v.weekdayCount, 3);
        expect(v.finishedTasks, 5);
      }
      expect(run(tasks: mondays).whenDone.evidence.enough, isTrue);
    });

    test('2 Mondays and 2 Tuesdays plus one other name no weekday', () {
      final WhenThingsGetDone v = run(
        tasks: <TaskEntity>[
          finished('a', at(1)),
          finished('b', at(8)),
          finished('c', at(0, 8)),
          finished('d', at(7, 8)),
          finished('e', at(3)),
        ],
      ).whenDone.value;
      expect(v.weekday, isNull);
    });

    test('four finished tasks are not enough: 4 of 5', () {
      final PatternMetric<WhenThingsGetDone> m = run(
        tasks: mondays.take(4).toList(),
      ).whenDone;
      expect(m.evidence.enough, isFalse);
      expect(m.evidence.reason, PatternEvidenceReason.tooFewRecords);
      expect(m.evidence.have, 4);
      expect(m.evidence.need, 5);
    });

    test('a part of day needs 3 and more than half', () {
      final List<TaskEntity> mornings = <TaskEntity>[
        for (int i = 0; i < 3; i++) finished('m$i', at(i + 1, 7)),
        finished('e1', at(5, 18)),
        finished('e2', at(6, 19)),
      ];
      final WhenThingsGetDone v = run(tasks: mornings).whenDone.value;
      expect(v.partOfDay, PartOfDay.morning);
      expect(v.partOfDayCount, 3);
      final WhenThingsGetDone split = run(
        tasks: <TaskEntity>[
          finished('a', at(1, 7)),
          finished('b', at(2, 7)),
          finished('c', at(3, 13)),
          finished('d', at(4, 13)),
          finished('e', at(5, 19)),
        ],
      ).whenDone.value;
      expect(split.partOfDay, isNull);
    });

    test('hour boundaries match the one-tap answer', () {
      expect(PatternsEngine.partOfDay(5), PartOfDay.night);
      expect(PatternsEngine.partOfDay(6), PartOfDay.morning);
      expect(PatternsEngine.partOfDay(11), PartOfDay.morning);
      expect(PatternsEngine.partOfDay(12), PartOfDay.afternoon);
      expect(PatternsEngine.partOfDay(16), PartOfDay.afternoon);
      expect(PatternsEngine.partOfDay(17), PartOfDay.evening);
    });

    test('names the same weekday and part of day as the one-tap answer', () {
      const SIOneTapEngine oneTap = SIOneTapEngine();
      String weekdayName(int d) => const <String>[
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ][d - 1];
      String partPhrase(PartOfDay p) => switch (p) {
        PartOfDay.night => 'at night',
        PartOfDay.morning => 'in the morning',
        PartOfDay.afternoon => 'in the afternoon',
        PartOfDay.evening => 'in the evening',
      };

      void expectSame(List<TaskEntity> tasks, {required String reason}) {
        final SIV2EvidenceSnapshot snapshot = SIV2EvidenceSnapshot(
          accountScopeId: 'account:test',
          observedAt: now,
          tasks: const <SIV2TaskEvidence>[],
          goals: const <SIV2GoalEvidence>[],
          milestones: const <SIV2MilestoneEvidence>[],
          timeline: const <SIV2TimelineEvidence>[],
          habits: const <SIV2HabitEvidence>[],
          recentTasks: <SIV2RecentTaskEvidence>[
            for (final TaskEntity t in tasks)
              SIV2RecentTaskEvidence(
                id: t.id,
                title: t.title,
                outcome: SIV2RecentTaskOutcome.completed,
                at: t.completedAt!,
              ),
          ],
        );
        final String text = oneTap
            .answer(
              question: SIOneTapQuestion.explainPatterns,
              snapshot: snapshot,
              now: now,
              isSpanish: false,
            )
            .response
            .toPlainText();
        final WhenThingsGetDone mine = run(
          tasks: tasks,
          range: 30,
        ).whenDone.value;
        for (int d = 1; d <= 7; d++) {
          expect(
            text.contains('on a ${weekdayName(d)}'),
            mine.weekday == d,
            reason: '$reason weekday $d',
          );
        }
        for (final PartOfDay p in PartOfDay.values) {
          expect(
            text.contains('marked done ${partPhrase(p)}'),
            mine.partOfDay == p,
            reason: '$reason part ${p.name}',
          );
        }
      }

      // Monday and morning stand out.
      expectSame(<TaskEntity>[
        finished('a', at(1, 7)),
        finished('b', at(8, 8)),
        finished('c', at(15, 9)),
        finished('d', at(0, 7)),
        finished('e', at(6, 20)),
      ], reason: 'standout');
      // Nothing stands out.
      expectSame(<TaskEntity>[
        finished('a', at(1, 7)),
        finished('b', at(2, 13)),
        finished('c', at(3, 19)),
        finished('d', at(4, 2)),
        finished('e', at(5, 8)),
      ], reason: 'spread');
      // A tie between two days.
      expectSame(<TaskEntity>[
        finished('a', at(1, 9)),
        finished('b', at(8, 9)),
        finished('c', at(15, 9)),
        finished('d', at(0, 9)),
        finished('e', at(7, 9)),
        finished('f', at(14, 9)),
      ], reason: 'tie');
    });
  });

  group('habits', () {
    test('a daily habit checked in every day reads 7 of 7 with streaks', () {
      final HabitEntity walk = daily();
      final PatternsResult r = run(
        habits: <HabitEntity>[walk],
        occurrences: <HabitOccurrenceEntity>[
          for (int i = 0; i < 7; i++) checkIn(walk, at(i, 8)),
        ],
      );
      expect(r.habits.evidence.enough, isTrue);
      final HabitConsistency c = r.habits.value.single.consistency;
      expect(r.habits.value.single.habitId, 'walk');
      expect(c.completed, 7);
      expect(c.windowPeriods, 7);
      expect(c.currentStreak, 7);
      expect(c.longestStreak, 7);
    });

    test('range 30 widens the habit window and the trend buckets', () {
      final HabitEntity walk = daily();
      final List<HabitOccurrenceEntity> all = <HabitOccurrenceEntity>[
        for (int i = 0; i < 30; i++) checkIn(walk, at(i, 8)),
      ];
      final PatternsResult seven = run(
        habits: <HabitEntity>[walk],
        occurrences: all,
      );
      final PatternsResult thirty = run(
        habits: <HabitEntity>[walk],
        occurrences: all,
        range: 30,
      );
      expect(seven.habits.value.single.consistency.windowPeriods, 7);
      expect(thirty.habits.value.single.consistency.windowPeriods, 30);
      expect(thirty.habits.value.single.consistency.completed, 30);
      expect(seven.trend.value.buckets, hasLength(7));
      expect(seven.trend.value.bucketDays, 1);
      expect(thirty.trend.value.buckets, hasLength(4));
      expect(thirty.trend.value.bucketDays, 7);
    });

    test('paused habits are left out', () {
      final HabitEntity paused = HabitEntity(
        id: 'p',
        title: 'Paused',
        createdAt: at(20),
        status: HabitStatus.paused,
      );
      final PatternsResult r = run(habits: <HabitEntity>[paused]);
      expect(r.habits.value, isEmpty);
      expect(r.habits.evidence.reason, PatternEvidenceReason.noHabits);
    });
  });

  group('completion trend', () {
    test('counts tasks and check-ins separately in daily buckets', () {
      final HabitEntity walk = daily();
      final PatternsResult r = run(
        tasks: <TaskEntity>[
          finished('a', at(0, 8)),
          finished('b', at(0, 9)),
          finished('c', at(3)),
          finished('old', at(10)),
        ],
        habits: <HabitEntity>[walk],
        occurrences: <HabitOccurrenceEntity>[checkIn(walk, at(0, 7))],
      );
      final CompletionTrend t = r.trend.value;
      expect(t.buckets.last.tasksFinished, 2);
      expect(t.buckets.last.habitCheckIns, 1);
      expect(t.buckets[3].tasksFinished, 1);
      expect(t.tasksFinished, 3);
      expect(t.habitCheckIns, 1);
      expect(r.trend.provenance, PatternProvenance.recorded);
    });

    test('weekly buckets over 4 weeks for range 30, oldest first', () {
      final PatternsResult r = run(
        tasks: <TaskEntity>[
          finished('a', at(1)),
          finished('b', at(9)),
          finished('c', at(20)),
          finished('d', at(27)),
        ],
        range: 30,
      );
      expect(
        r.trend.value.buckets.map((TrendBucket b) => b.tasksFinished),
        <int>[1, 1, 1, 1],
      );
      expect(r.trend.value.buckets.first.start, DateTime(2026, 11, 4));
    });

    test('a 7-day window across a clock change still has 7 daily buckets', () {
      // US clocks change 2026-03-08 and 2026-11-01: windows across both.
      for (final DateTime clock in <DateTime>[
        DateTime(2026, 3, 10, 10),
        DateTime(2026, 11, 3, 10),
      ]) {
        final CompletionTrend t = run(clock: clock).trend.value;
        expect(t.buckets, hasLength(7));
        for (int i = 0; i < 7; i++) {
          expect(
            t.buckets[i].start,
            DateTime(clock.year, clock.month, clock.day - 6 + i),
          );
          expect(
            t.buckets[i].end,
            DateTime(clock.year, clock.month, clock.day - 5 + i),
          );
        }
      }
    });
  });

  group('workload by day', () {
    test('lands on the right days and flags default estimates', () {
      final PatternsResult r = run(
        tasks: <TaskEntity>[
          TaskEntity(
            id: 'sched',
            title: 'Write',
            createdAt: at(2),
            scheduledFor: DateTime(2026, 12, 2, 14),
            estimatedDuration: const Duration(minutes: 60),
          ),
          TaskEntity(
            id: 'due',
            title: 'Pay',
            createdAt: at(2),
            dueDate: DateTime(2026, 12, 4, 17),
          ),
          TaskEntity(
            id: 'whole-day',
            title: 'Renew',
            createdAt: at(2),
            dueDate: DateTime(2026, 12, 5),
            estimatedDuration: const Duration(minutes: 10),
          ),
        ],
      );
      final List<WorkloadDay> days = r.workload.value;
      expect(days, hasLength(7));
      expect(days.first.day, DateTime(2026, 12, 1));
      expect(days[1].plannedMinutes, 60);
      expect(days[1].isRough, isFalse);
      expect(days[3].plannedMinutes, 25);
      expect(days[3].estimatedByDefaultCount, 1);
      expect(days[3].isRough, isTrue);
      // A whole-day deadline owns the day it names.
      expect(days[4].plannedMinutes, 10);
      expect(days[0].plannedMinutes, 0);
      expect(r.workload.evidence.enough, isTrue);
    });

    test('finished tasks and tasks beyond 7 days are not counted', () {
      final PatternsResult r = run(
        tasks: <TaskEntity>[
          TaskEntity(
            id: 'later',
            title: 'Later',
            createdAt: at(2),
            dueDate: DateTime(2026, 12, 9, 12),
          ),
          finished('x', at(1)).copyWith(scheduledFor: DateTime(2026, 12, 2)),
        ],
      );
      expect(r.workload.value.fold<int>(0, (s, d) => s + d.taskCount), 0);
      expect(r.workload.evidence.reason, PatternEvidenceReason.noPlannedWork);
    });
  });

  group('missed items', () {
    test('skipped tasks follow the range', () {
      final List<TaskEntity> tasks = <TaskEntity>[
        skipped('recent', at(2)),
        skipped('old', at(20)),
      ];
      expect(
        run(tasks: tasks).missed.skippedTasks.value.map((r) => r.subjectId),
        <String>['recent'],
      );
      expect(
        run(
          tasks: tasks,
          range: 30,
        ).missed.skippedTasks.value.map((r) => r.subjectId),
        <String>['recent', 'old'],
      );
    });

    test('a task due today with no time is not overdue until the day ends', () {
      final TaskEntity dueToday = TaskEntity(
        id: 'today',
        title: 'Today',
        createdAt: at(3),
        dueDate: DateTime(2026, 12, 1),
      );
      final TaskEntity dueYesterday = TaskEntity(
        id: 'yesterday',
        title: 'Yesterday',
        createdAt: at(3),
        dueDate: DateTime(2026, 11, 30),
      );
      final TaskEntity earlierToday = TaskEntity(
        id: 'earlier',
        title: 'Earlier',
        createdAt: at(3),
        dueDate: DateTime(2026, 12, 1, 8),
      );
      final List<String> ids = run(
        tasks: <TaskEntity>[dueToday, dueYesterday, earlierToday],
      ).missed.overdueTasks.value.map((TaskEntity t) => t.id).toList();
      expect(ids, unorderedEquals(<String>['yesterday', 'earlier']));
      // The next morning the whole-day task has ended.
      expect(
        run(
          tasks: <TaskEntity>[dueToday],
          clock: DateTime(2026, 12, 2, 0, 1),
        ).missed.overdueTasks.value,
        hasLength(1),
      );
    });

    test('a daily habit with one unchecked closed day misses one period', () {
      final HabitEntity walk = daily();
      final PatternsResult r = run(
        habits: <HabitEntity>[walk],
        occurrences: <HabitOccurrenceEntity>[
          for (final int i in <int>[1, 2, 4, 5, 6]) checkIn(walk, at(i, 8)),
          checkIn(walk, at(3, 8), outcome: HabitOccurrenceOutcome.skipped),
        ],
      );
      // Today is open (not missed); day 3 skipped; day 0..6 window has 7.
      final List<HabitPeriodMiss> misses = r.missed.habitPeriods.value;
      expect(misses.where((m) => m.state == HabitPeriodState.missed), isEmpty);
      expect(misses.single.state, HabitPeriodState.skipped);
      final PatternsResult withGap = run(
        habits: <HabitEntity>[walk],
        occurrences: <HabitOccurrenceEntity>[
          for (final int i in <int>[1, 3, 4, 5, 6]) checkIn(walk, at(i, 8)),
        ],
      );
      final List<HabitPeriodMiss> gap = withGap.missed.habitPeriods.value;
      expect(gap, hasLength(1));
      expect(gap.single.state, HabitPeriodState.missed);
      expect(gap.single.start, DateTime(2026, 11, 29));
    });
  });

  test('an empty account is empty and not enough everywhere', () {
    for (final int range in <int>[7, 30]) {
      final PatternsResult r = PatternsResult.empty(now: now, rangeDays: range);
      expect(r.habits.value, isEmpty);
      expect(r.habits.evidence.enough, isFalse);
      expect(r.trend.evidence.enough, isFalse);
      expect(r.trend.value.tasksFinished, 0);
      expect(r.trend.value.buckets, hasLength(range == 7 ? 7 : 4));
      expect(r.whenDone.evidence.enough, isFalse);
      expect(r.whenDone.evidence.have, 0);
      expect(r.whenDone.evidence.need, 5);
      expect(r.workload.evidence.enough, isFalse);
      expect(r.workload.value, hasLength(7));
      expect(r.missed.skippedTasks.value, isEmpty);
      expect(r.missed.overdueTasks.value, isEmpty);
      expect(r.missed.habitPeriods.value, isEmpty);
      expect(r.missed.skippedTasks.evidence.enough, isFalse);
    }
  });

  test('a range other than 7 or 30 is refused', () {
    expect(() => run(range: 14), throwsA(isA<ArgumentError>()));
  });
}
