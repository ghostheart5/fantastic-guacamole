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

  group('when things get done: window', () {
    test('looks back 28 days whatever the range and says so', () {
      for (final int range in <int>[7, 30]) {
        final WhenThingsGetDone v = run(range: range).whenDone.value;
        expect(v.windowDays, 28);
        expect(v.windowStart, DateTime(2026, 11, 4));
      }
    });

    test('a task 27 days ago counts, 28 days ago does not', () {
      List<TaskEntity> five(int oldest) => <TaskEntity>[
        for (int i = 0; i < 4; i++) finished('n$i', at(i + 1)),
        finished('old', at(oldest)),
      ];
      expect(run(tasks: five(27)).whenDone.value.finishedTasks, 5);
      expect(run(tasks: five(28)).whenDone.value.finishedTasks, 4);
    });

    test('the Assistant answer looks back 14 days: the window differs on '
        'purpose', () {
      // The free one-tap answer reads what the read gateway gives it: 14 days
      // back from the current time of day (si_v2_read_gateway.dart,
      // _recentTaskEvidence). Patterns looks back 28 days so a weekday can
      // reach 3. This fixture has 3 Mondays, one of them 15 days ago: the
      // Assistant sees 2 and names no day, Patterns names Monday. The
      // difference in window is intended; the counting rules are the same
      // (tested above).
      final List<TaskEntity> tasks = <TaskEntity>[
        finished('m1', at(1)),
        finished('m2', at(8)),
        finished('m3', at(15)),
        finished('tue', at(0, 8)),
        finished('wed', at(6)),
        finished('sat', at(3)),
      ];
      final DateTime gatewayStart = DateTime(
        now.year,
        now.month,
        now.day - 14,
        now.hour,
        now.minute,
      );
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
            if (!t.completedAt!.isBefore(gatewayStart))
              SIV2RecentTaskEvidence(
                id: t.id,
                title: t.title,
                outcome: SIV2RecentTaskOutcome.completed,
                at: t.completedAt!,
              ),
        ],
      );
      final String text = const SIOneTapEngine()
          .answer(
            question: SIOneTapQuestion.explainPatterns,
            snapshot: snapshot,
            now: now,
            isSpanish: false,
          )
          .response
          .toPlainText();
      expect(snapshot.recentTasks, hasLength(5));
      expect(text.contains('on a Monday'), isFalse);
      expect(run(tasks: tasks).whenDone.value.weekday, DateTime.monday);
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
      expect(days[1].hasTasksWithoutEstimate, isFalse);
      expect(days[3].plannedMinutes, 25);
      expect(days[3].withoutEstimateCount, 1);
      expect(days[3].hasTasksWithoutEstimate, isTrue);
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

  group('boundaries', () {
    test('skipped tasks 6 days ago count for range 7, 7 days ago do not', () {
      List<String> ids(int range, int daysAgo) => run(
        tasks: <TaskEntity>[skipped('s', at(daysAgo))],
        range: range,
      ).missed.skippedTasks.value.map((r) => r.subjectId).toList();
      expect(ids(7, 6), <String>['s']);
      expect(ids(7, 7), isEmpty);
      expect(ids(30, 29), <String>['s']);
      expect(ids(30, 30), isEmpty);
    });

    test('range 30 trend covers 28 days: 27 days ago in, 28 days ago out', () {
      final PatternsResult in27 = run(
        tasks: <TaskEntity>[finished('a', at(27))],
        range: 30,
      );
      final PatternsResult out28 = run(
        tasks: <TaskEntity>[finished('a', at(28))],
        range: 30,
      );
      expect(in27.trend.value.coveredDays, 28);
      expect(in27.trend.value.tasksFinished, 1);
      expect(out28.trend.value.tasksFinished, 0);
      expect(run().trend.value.coveredDays, 7);
    });

    test('workload covers 7 days: day 6 in, day 7 out', () {
      TaskEntity due(int day) => TaskEntity(
        id: 'd$day',
        title: 'D$day',
        createdAt: at(2),
        scheduledFor: DateTime(2026, 12, 1 + day, 12),
      );
      int total(PatternsResult r) =>
          r.workload.value.fold<int>(0, (s, d) => s + d.taskCount);
      expect(total(run(tasks: <TaskEntity>[due(6)])), 1);
      expect(total(run(tasks: <TaskEntity>[due(7)])), 0);
    });

    test('canceled, skipped and finished tasks are not planned work', () {
      final DateTime tomorrow = DateTime(2026, 12, 2, 9);
      final PatternsResult r = run(
        tasks: <TaskEntity>[
          TaskEntity(
            id: 'c',
            title: 'C',
            createdAt: at(2),
            scheduledFor: tomorrow,
            isCanceled: true,
          ),
          TaskEntity(
            id: 's',
            title: 'S',
            createdAt: at(2),
            scheduledFor: tomorrow,
            isSkipped: true,
            skippedAt: at(1),
          ),
          TaskEntity(
            id: 'f',
            title: 'F',
            createdAt: at(2),
            scheduledFor: tomorrow,
            isCompleted: true,
            completedAt: at(1),
          ),
        ],
      );
      expect(r.workload.value.fold<int>(0, (s, d) => s + d.taskCount), 0);
      expect(r.unplaced.value.taskCount, 0);
    });

    test('the schedule wins over the deadline while it is still ahead', () {
      final PatternsResult r = run(
        tasks: <TaskEntity>[
          TaskEntity(
            id: 'x',
            title: 'X',
            createdAt: at(2),
            scheduledFor: DateTime(2026, 12, 2, 9),
            dueDate: DateTime(2026, 12, 5, 17),
          ),
        ],
      );
      expect(r.workload.value[1].taskCount, 1);
      expect(r.workload.value[4].taskCount, 0);
    });

    test('a whole-day deadline stored as UTC midnight keeps its day', () {
      final PatternsResult r = run(
        tasks: <TaskEntity>[
          TaskEntity(
            id: 'u',
            title: 'U',
            createdAt: at(2),
            dueDate: DateTime.utc(2026, 12, 5),
          ),
        ],
      );
      expect(r.workload.value[4].taskCount, 1);
    });
  });

  group('unplaced work', () {
    test('slipped work falls back to its deadline; the rest is unplaced', () {
      final PatternsResult r = run(
        tasks: <TaskEntity>[
          // Scheduled yesterday, due in 3 days: lands on the deadline day.
          TaskEntity(
            id: 'slipped',
            title: 'Slipped',
            createdAt: at(5),
            scheduledFor: at(1, 14),
            dueDate: DateTime(2026, 12, 4, 17),
            estimatedDuration: const Duration(minutes: 40),
          ),
          // Scheduled yesterday, nothing else: unplaced.
          TaskEntity(
            id: 'slipped-alone',
            title: 'Slipped alone',
            createdAt: at(5),
            scheduledFor: at(1, 14),
            estimatedDuration: const Duration(minutes: 20),
          ),
          // No date at all: unplaced, no estimate saved (25 minutes).
          TaskEntity(id: 'undated', title: 'Undated', createdAt: at(5)),
          // Overdue: unplaced.
          TaskEntity(
            id: 'late',
            title: 'Late',
            createdAt: at(5),
            dueDate: DateTime(2026, 11, 28, 12),
            estimatedDuration: const Duration(minutes: 10),
          ),
          // Beyond 7 days: in no day and not unplaced.
          TaskEntity(
            id: 'later',
            title: 'Later',
            createdAt: at(5),
            dueDate: DateTime(2026, 12, 20, 12),
          ),
        ],
      );
      expect(r.workload.value[3].plannedMinutes, 40);
      expect(r.workload.value.fold<int>(0, (s, d) => s + d.taskCount), 1);
      final UnplacedWork u = r.unplaced.value;
      expect(u.taskCount, 3);
      expect(u.plannedMinutes, 20 + 25 + 10);
      expect(u.withoutEstimateCount, 1);
      expect(r.unplaced.evidence.enough, isTrue);
    });

    test('nothing unplaced is not enough evidence of anything', () {
      expect(run().unplaced.value.taskCount, 0);
      expect(run().unplaced.evidence.enough, isFalse);
    });
  });

  group('habit misses follow the range', () {
    test('a weekly habit lists only weeks that overlap the range', () {
      final HabitEntity weekly = HabitEntity(
        id: 'w',
        title: 'Plan',
        createdAt: at(120),
        cadence: HabitCadence.weekly,
      );
      List<DateTime> misses(int range) => run(
        habits: <HabitEntity>[weekly],
        range: range,
      ).missed.habitPeriods.value.map((m) => m.start).toList();
      // Dec 1 is a Tuesday: the week of Mon Nov 30 is open. Range 7 starts
      // Nov 25, so only the week of Nov 23 (to Nov 30) overlaps.
      expect(misses(7), <DateTime>[DateTime(2026, 11, 23)]);
      // Range 30 starts Nov 2: weeks of Nov 23, 16, 9 and 2.
      expect(misses(30), <DateTime>[
        DateTime(2026, 11, 23),
        DateTime(2026, 11, 16),
        DateTime(2026, 11, 9),
        DateTime(2026, 11, 2),
      ]);
      // The consistency figure keeps the wider window.
      expect(
        run(
          habits: <HabitEntity>[weekly],
        ).habits.value.single.consistency.windowPeriods,
        4,
      );
    });

    test('a monthly habit lists only months that overlap the range', () {
      final HabitEntity monthly = HabitEntity(
        id: 'm',
        title: 'Review',
        createdAt: DateTime(2026, 8, 1),
        cadence: HabitCadence.monthly,
      );
      for (final int range in <int>[7, 30]) {
        final List<HabitPeriodMiss> misses = run(
          habits: <HabitEntity>[monthly],
          range: range,
        ).missed.habitPeriods.value;
        expect(misses.map((m) => m.start), <DateTime>[DateTime(2026, 11, 1)]);
      }
    });
  });

  test('a streak after a gap: current and longest differ', () {
    final HabitEntity walk = daily();
    final HabitConsistency c = run(
      habits: <HabitEntity>[walk],
      occurrences: <HabitOccurrenceEntity>[
        for (final int i in <int>[0, 1, 3, 4, 5, 6]) checkIn(walk, at(i, 8)),
      ],
    ).habits.value.single.consistency;
    expect(c.currentStreak, 2);
    expect(c.longestStreak, 4);
  });

  test('days across a clock change keep their own check-ins', () {
    // Bites only in a time zone with clock changes (the US ones on
    // 2026-03-08 and 2026-11-01, the EU ones on 03-29 and 10-25): in a zone
    // without them it still passes but proves nothing. Times just either side
    // of midnight and inside the short and long days must land on their own
    // calendar day, which 24-hour arithmetic would get wrong.
    for (final DateTime day in <DateTime>[
      DateTime(2026, 3, 8),
      DateTime(2026, 3, 29),
      DateTime(2026, 10, 25),
      DateTime(2026, 11, 1),
    ]) {
      final DateTime before = DateTime(
        day.year,
        day.month,
        day.day - 1,
        23,
        30,
      );
      final DateTime early = DateTime(day.year, day.month, day.day, 0, 30);
      final DateTime late = DateTime(day.year, day.month, day.day, 23, 30);
      final DateTime after = DateTime(day.year, day.month, day.day + 1, 0, 30);
      final DateTime clock = DateTime(day.year, day.month, day.day + 2, 10);
      final CompletionTrend t = run(
        tasks: <TaskEntity>[
          finished('b', before),
          finished('e', early),
          finished('l', late),
          finished('a', after),
        ],
        clock: clock,
      ).trend.value;
      expect(t.buckets, hasLength(7));
      int on(DateTime d) => t.buckets
          .firstWhere((b) => b.start == DateTime(d.year, d.month, d.day))
          .tasksFinished;
      expect(on(day), 2, reason: 'day $day');
      expect(on(DateTime(day.year, day.month, day.day - 1)), 1);
      expect(on(DateTime(day.year, day.month, day.day + 1)), 1);
    }
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
