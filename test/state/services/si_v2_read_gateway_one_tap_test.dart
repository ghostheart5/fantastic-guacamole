import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_occurrence_entity.dart';
import 'package:fantastic_guacamole/domain/entities/milestone_entity.dart';
import 'package:fantastic_guacamole/domain/entities/si_v2_contract.dart';
import 'package:fantastic_guacamole/domain/entities/si_one_tap_question.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/engine/si/api.dart';
import 'package:fantastic_guacamole/domain/planning/rhythm_planning_context.dart';
import 'package:fantastic_guacamole/state/services/si_v2_read_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Midday UTC keeps the local calendar day the same in every time zone that
  // matters for these checks.
  final DateTime now = DateTime.utc(2026, 8, 20, 12);
  const String pinnedRevision =
      'a5555f37c3fb38122d6bf964d7a14fff560bbb89cafa48047c766903db801967';

  HabitOccurrenceEntity checkIn(
    HabitEntity habit,
    DateTime at, {
    HabitOccurrenceOutcome outcome = HabitOccurrenceOutcome.completed,
  }) => HabitOccurrenceEntity(
    habitId: habit.id,
    occurrenceKey: RhythmPlanningContext.occurrenceKey(habit, at),
    operationId: 'op-${at.toIso8601String()}',
    outcome: outcome,
    recordedAt: at.toUtc(),
  );

  SIV2ReadGateway gateway({
    List<TaskEntity> tasks = const <TaskEntity>[],
    List<GoalEntity> goals = const <GoalEntity>[],
    List<MilestoneEntity> milestones = const <MilestoneEntity>[],
    List<HabitEntity>? habits,
    List<HabitOccurrenceEntity> occurrences = const <HabitOccurrenceEntity>[],
    Future<List<HabitEntity>> Function()? habitReader,
  }) => SIV2ReadGateway(
    accountScopeId: 'account:test',
    readTasks: () async => tasks,
    readGoals: () async => goals,
    readMilestones: () async => milestones,
    readTimeline: () async => const [],
    readHabits: habitReader ?? (habits == null ? null : () async => habits),
    readHabitOccurrences: () async => occurrences,
  );

  test(
    'habits: cadence, check-ins in the last 14 days and the streak',
    () async {
      final HabitEntity walk = HabitEntity(
        id: 'walk',
        title: 'Walk',
        createdAt: now.subtract(const Duration(days: 60)),
      );
      final List<HabitOccurrenceEntity> occurrences = <HabitOccurrenceEntity>[
        // Today, yesterday and the day before: a streak of 3.
        for (int i = 0; i < 3; i++)
          checkIn(walk, now.subtract(Duration(days: i))),
        // Two older ones, one skipped.
        checkIn(walk, now.subtract(const Duration(days: 6))),
        checkIn(
          walk,
          now.subtract(const Duration(days: 7)),
          outcome: HabitOccurrenceOutcome.skipped,
        ),
        // Outside the 14 day window.
        checkIn(walk, now.subtract(const Duration(days: 30))),
      ];
      final SIV2EvidenceSnapshot snapshot = await gateway(
        habits: <HabitEntity>[walk],
        occurrences: occurrences,
      ).read(observedAt: now, includeActivity: true);
      final SIV2HabitEvidence habit = snapshot.habits.single;
      expect(habit.cadence, HabitCadence.daily);
      expect(habit.checkInsInWindow, 4);
      expect(habit.currentStreak, 3);
      expect(habit.checkedInThisPeriod, isTrue);
    },
  );

  test('habits: a period still open does not break the streak', () async {
    final HabitEntity read = HabitEntity(
      id: 'read',
      title: 'Read',
      createdAt: now.subtract(const Duration(days: 60)),
    );
    final SIV2EvidenceSnapshot snapshot = await gateway(
      habits: <HabitEntity>[read],
      occurrences: <HabitOccurrenceEntity>[
        checkIn(read, now.subtract(const Duration(days: 1))),
        checkIn(read, now.subtract(const Duration(days: 2))),
      ],
    ).read(observedAt: now, includeActivity: true);
    expect(snapshot.habits.single.currentStreak, 2);
    expect(snapshot.habits.single.checkedInThisPeriod, isFalse);
  });

  test(
    'habits: weekly streak counts weeks and paused habits are left out',
    () async {
      final HabitEntity weekly = HabitEntity(
        id: 'weekly',
        title: 'Long run',
        createdAt: now.subtract(const Duration(days: 90)),
        cadence: HabitCadence.weekly,
      );
      final HabitEntity paused = HabitEntity(
        id: 'paused',
        title: 'Paused one',
        createdAt: now.subtract(const Duration(days: 90)),
        status: HabitStatus.paused,
      );
      final SIV2EvidenceSnapshot snapshot = await gateway(
        habits: <HabitEntity>[weekly, paused],
        occurrences: <HabitOccurrenceEntity>[
          checkIn(weekly, now),
          checkIn(weekly, now.subtract(const Duration(days: 7))),
          checkIn(weekly, now.subtract(const Duration(days: 14))),
          checkIn(weekly, now.subtract(const Duration(days: 28))),
        ],
      ).read(observedAt: now, includeActivity: true);
      expect(snapshot.habits.map((SIV2HabitEvidence h) => h.id), <String>[
        'weekly',
      ]);
      expect(snapshot.habits.single.currentStreak, 3);
    },
  );

  test('habits are marked unavailable when they cannot be read', () async {
    final SIV2EvidenceSnapshot snapshot = await gateway(
      habitReader: () async => throw StateError('storage broke'),
    ).read(observedAt: now, includeActivity: true);
    expect(snapshot.habitsUnavailable, isTrue);
    expect(snapshot.habits, isEmpty);
  });

  test('without a habit reader nothing is claimed about habits', () async {
    final SIV2EvidenceSnapshot snapshot = await gateway().read(
      observedAt: now,
      includeActivity: true,
    );
    expect(snapshot.habits, isEmpty);
    expect(snapshot.habitsUnavailable, isFalse);
  });

  test(
    'recent tasks: finished and skipped in 14 days, titles kept, others dropped',
    () async {
      TaskEntity done(String id, int daysAgo) => TaskEntity(
        id: id,
        title: 'Done $id',
        createdAt: now.subtract(const Duration(days: 40)),
        isCompleted: true,
        completedAt: now.subtract(Duration(days: daysAgo)),
      );
      final SIV2EvidenceSnapshot snapshot = await gateway(
        tasks: <TaskEntity>[
          done('a', 1),
          done('b', 13),
          done('old', 20),
          TaskEntity(
            id: 'skip',
            title: 'Skipped one',
            createdAt: now.subtract(const Duration(days: 40)),
            isSkipped: true,
            skippedAt: now.subtract(const Duration(days: 2)),
          ),
          TaskEntity(
            id: 'cancelled',
            title: 'Cancelled',
            createdAt: now.subtract(const Duration(days: 40)),
            isCompleted: true,
            isCanceled: true,
            completedAt: now.subtract(const Duration(days: 1)),
          ),
          TaskEntity(
            id: 'untimed',
            title: 'No time recorded',
            createdAt: now.subtract(const Duration(days: 40)),
            isCompleted: true,
          ),
          TaskEntity(
            id: 'open',
            title: 'Still open',
            createdAt: now.subtract(const Duration(days: 40)),
          ),
        ],
      ).read(observedAt: now, includeActivity: true);
      expect(
        snapshot.recentTasks.map((SIV2RecentTaskEvidence t) => t.id),
        <String>['a', 'skip', 'b'],
      );
      expect(snapshot.recentTasks[1].outcome, SIV2RecentTaskOutcome.skipped);
      // Open tasks still behave as before.
      expect(snapshot.tasks.map((SIV2TaskEvidence t) => t.id), <String>[
        'open',
      ]);
    },
  );

  test('goal progress: linked tasks and milestones, done and open', () async {
    final SIV2EvidenceSnapshot snapshot = await gateway(
      goals: <GoalEntity>[
        GoalEntity(id: 'g', title: 'Goal', createdAt: now),
        GoalEntity(id: 'bare', title: 'Bare', createdAt: now),
      ],
      tasks: <TaskEntity>[
        TaskEntity(id: 't1', title: 'One', goalId: 'g', isCompleted: true),
        TaskEntity(id: 't2', title: 'Two', goalId: 'g'),
        TaskEntity(id: 't3', title: 'Three', goalId: 'g', isSkipped: true),
        TaskEntity(id: 't4', title: 'Four', goalId: 'g', isCanceled: true),
        TaskEntity(id: 't5', title: 'Elsewhere', goalId: 'other'),
      ],
      milestones: <MilestoneEntity>[
        MilestoneEntity(
          id: 'm1',
          goalId: 'g',
          title: 'Half',
          status: MilestoneStatus.completed,
          createdAt: now,
          updatedAt: now,
        ),
        MilestoneEntity(
          id: 'm2',
          goalId: 'g',
          title: 'Rest',
          createdAt: now,
          updatedAt: now,
        ),
      ],
    ).read(observedAt: now, includeActivity: true);
    final SIV2GoalEvidence goal = snapshot.goals.firstWhere(
      (SIV2GoalEvidence g) => g.id == 'g',
    );
    expect(goal.linkedTasksDone, 1);
    expect(goal.linkedTasksOpen, 1);
    expect(goal.milestonesDone, 1);
    expect(goal.milestonesOpen, 1);
    final SIV2GoalEvidence bare = snapshot.goals.firstWhere(
      (SIV2GoalEvidence g) => g.id == 'bare',
    );
    expect(bare.hasProgress, isFalse);
  });

  test('without includeActivity no habit or history is read at all', () async {
    int habitReads = 0;
    final SIV2ReadGateway g = SIV2ReadGateway(
      accountScopeId: 'account:test',
      readTasks: () async => <TaskEntity>[
        TaskEntity(
          id: 'done',
          title: 'Done',
          createdAt: now,
          isCompleted: true,
          completedAt: now,
        ),
      ],
      readGoals: () async => const [],
      readMilestones: () async => const [],
      readTimeline: () async => const [],
      readHabits: () async {
        habitReads++;
        return <HabitEntity>[];
      },
      readHabitOccurrences: () async {
        habitReads++;
        return <HabitOccurrenceEntity>[];
      },
    );
    final SIV2EvidenceSnapshot packetSide = await g.read(observedAt: now);
    expect(habitReads, 0);
    expect(packetSide.habits, isEmpty);
    expect(packetSide.recentTasks, isEmpty);
    final SIV2EvidenceSnapshot oneTap = await g.read(
      observedAt: now,
      includeActivity: true,
    );
    expect(habitReads, 2);
    expect(oneTap.recentTasks, hasLength(1));
  });

  test(
    'the evidence revision is exactly what it was before the one-tap records',
    () async {
      // The value was computed with the contract as it stood before this change
      // (commit 8f9255dc) for this exact account.
      SIV2EvidenceSnapshot build({bool withNewRecords = false}) =>
          SIV2EvidenceSnapshot(
            accountScopeId: 'account:test',
            observedAt: now,
            tasks: <SIV2TaskEvidence>[
              SIV2TaskEvidence(
                id: 't1',
                title: 'Write report',
                createdAt: DateTime.utc(2026, 8, 1),
                priority: 4,
                dueDate: DateTime.utc(2026, 8, 19, 22),
                goalId: 'g1',
                dueDay: withNewRecords ? DateTime(2026, 8, 20) : null,
              ),
            ],
            goals: <SIV2GoalEvidence>[
              SIV2GoalEvidence(
                id: 'g1',
                title: 'Launch',
                createdAt: DateTime.utc(2026, 7, 1),
                targetDate: DateTime.utc(2026, 9, 1),
                linkedTasksDone: withNewRecords ? 3 : 0,
              ),
            ],
            milestones: const <SIV2MilestoneEvidence>[],
            timeline: const <SIV2TimelineEvidence>[],
            habits: withNewRecords
                ? <SIV2HabitEvidence>[
                    SIV2HabitEvidence(
                      id: 'h',
                      title: 'Walk',
                      createdAt: now,
                      cadence: HabitCadence.daily,
                      targetCount: 1,
                      checkInsInWindow: 1,
                      currentStreak: 1,
                      checkedInThisPeriod: true,
                    ),
                  ]
                : const <SIV2HabitEvidence>[],
            recentTasks: withNewRecords
                ? <SIV2RecentTaskEvidence>[
                    SIV2RecentTaskEvidence(
                      id: 'x',
                      title: 'Finished',
                      outcome: SIV2RecentTaskOutcome.completed,
                      at: now,
                    ),
                  ]
                : const <SIV2RecentTaskEvidence>[],
          );
      expect(build().revision, pinnedRevision);
      // Habits, recent tasks, goal progress and whole days never change it, so
      // a preview and a later send compare equal.
      expect(build(withNewRecords: true).revision, pinnedRevision);
    },
  );

  test('a deadline chosen as a whole day carries its calendar day', () async {
    final SIV2EvidenceSnapshot s = await gateway(
      tasks: <TaskEntity>[
        // Saved at local midnight, in this machine's zone.
        TaskEntity(
          id: 'local',
          title: 'Local midnight',
          createdAt: now,
          dueDate: DateTime(2026, 8, 20),
        ),
        // A cloud decoder may mark the same chosen day as UTC.
        TaskEntity(
          id: 'utc',
          title: 'UTC marked',
          createdAt: now,
          dueDate: DateTime.utc(2026, 8, 20),
        ),
        TaskEntity(
          id: 'timed',
          title: 'Has a time',
          createdAt: now,
          dueDate: DateTime(2026, 8, 20, 18, 30),
        ),
      ],
      goals: <GoalEntity>[
        GoalEntity(
          id: 'g',
          title: 'Goal',
          createdAt: now,
          targetDate: DateTime(2026, 9, 1),
        ),
      ],
      milestones: <MilestoneEntity>[
        MilestoneEntity(
          id: 'm',
          title: 'Milestone',
          createdAt: now,
          updatedAt: now,
          targetDate: DateTime(2026, 9, 2),
        ),
      ],
    ).read(observedAt: now);
    final Map<String, SIV2TaskEvidence> byId = <String, SIV2TaskEvidence>{
      for (final SIV2TaskEvidence t in s.tasks) t.id: t,
    };
    expect(byId['local']!.dueDay, DateTime(2026, 8, 20));
    expect(byId['utc']!.dueDay, DateTime(2026, 8, 20));
    expect(byId['timed']!.dueDay, isNull);
    expect(s.goals.single.targetDay, DateTime(2026, 9, 1));
    expect(s.milestones.single.targetDay, DateTime(2026, 9, 2));
  });

  test('a habit is tracked from its last frequency edit', () async {
    final HabitEntity edited = HabitEntity(
      id: 'e',
      title: 'Edited',
      createdAt: now.subtract(const Duration(days: 90)),
      frequencyRevision: 1,
      frequencyStartedAt: now.subtract(const Duration(days: 4)),
    );
    final HabitEntity plain = HabitEntity(
      id: 'p',
      title: 'Plain',
      createdAt: now.subtract(const Duration(days: 90)),
    );
    final SIV2EvidenceSnapshot s = await gateway(
      habits: <HabitEntity>[edited, plain],
    ).read(observedAt: now, includeActivity: true);
    final Map<String, SIV2HabitEvidence> byId = <String, SIV2HabitEvidence>{
      for (final SIV2HabitEvidence h in s.habits) h.id: h,
    };
    expect(byId['e']!.trackedSince, now.subtract(const Duration(days: 4)));
    expect(byId['p']!.trackedSince, now.subtract(const Duration(days: 90)));
  });

  test(
    'a habit edited 4 days ago is not credited with the days before',
    () async {
      final DateTime editedAt = now.subtract(const Duration(days: 4));
      // Checked in every day for 10 days under the old frequency (revision 0)...
      final HabitEntity before = HabitEntity(
        id: 'e',
        title: 'Edited',
        createdAt: now.subtract(const Duration(days: 90)),
      );
      // ...then edited: revision 1 starts 4 days ago, with no check-in since.
      final HabitEntity edited = before.copyWith(
        frequencyRevision: 1,
        frequencyStartedAt: editedAt,
      );
      final SIV2EvidenceSnapshot s = await gateway(
        habits: <HabitEntity>[edited],
        occurrences: <HabitOccurrenceEntity>[
          for (int i = 5; i < 12; i++)
            checkIn(before, now.subtract(Duration(days: i))),
        ],
      ).read(observedAt: now, includeActivity: true);
      final SIV2HabitEvidence habit = s.habits.single;
      // The raw 14 day count (the paid packet's label) keeps earlier
      // check-ins; the one the answer judges does not.
      expect(habit.checkInsInWindow, 7);
      expect(habit.checkInsSinceTracked, 0);
      expect(habit.currentStreak, 0);
      expect(habit.checkedInThisPeriod, isFalse);
      // A check-in under the new frequency is counted, and only that one.
      final SIV2EvidenceSnapshot after = await gateway(
        habits: <HabitEntity>[edited],
        occurrences: <HabitOccurrenceEntity>[
          for (int i = 5; i < 12; i++)
            checkIn(before, now.subtract(Duration(days: i))),
          checkIn(edited, now.subtract(const Duration(days: 1))),
        ],
      ).read(observedAt: now, includeActivity: true);
      expect(after.habits.single.checkInsInWindow, 8);
      expect(after.habits.single.checkInsSinceTracked, 1);
      expect(after.habits.single.currentStreak, 1);
    },
  );

  test(
    'a whole-day deadline saved at local midnight reaches the answer',
    () async {
      // Saved the way Creator saves it: local midnight. Whatever the machine's
      // zone, the stored calendar day is the day the answer reads.
      final SIV2EvidenceSnapshot s = await gateway(
        tasks: <TaskEntity>[
          TaskEntity(
            id: 'rent',
            title: 'Pay rent',
            createdAt: now,
            dueDate: DateTime(2026, 8, 20),
          ),
        ],
      ).read(observedAt: now, includeActivity: true);
      const SIOneTapEngine engine = SIOneTapEngine();
      String plan(DateTime at) => engine
          .answer(
            question: SIOneTapQuestion.planMyDay,
            snapshot: s,
            now: at,
            isSpanish: false,
          )
          .response
          .directAnswer;
      expect(
        plan(DateTime(2026, 8, 20, 23, 59)),
        '1 task needs you today: 0 overdue and 1 due or planned for today.',
      );
      expect(
        plan(DateTime(2026, 8, 21)),
        '1 task needs you today: 1 overdue and 0 due or planned for today.',
      );
    },
  );

  test('check-ins since tracked cover exactly the last periods', () async {
    final HabitEntity daily = HabitEntity(
      id: 'd',
      title: 'Daily',
      createdAt: now.subtract(const Duration(days: 90)),
    );
    Future<SIV2HabitEvidence> read(List<int> daysAgo) async => (await gateway(
      habits: <HabitEntity>[daily],
      occurrences: <HabitOccurrenceEntity>[
        for (final int i in daysAgo)
          checkIn(daily, now.subtract(Duration(days: i))),
      ],
    ).read(observedAt: now, includeActivity: true)).habits.single;

    // Today and the 13 days before: 14 of the last 14 days.
    expect(
      (await read(<int>[for (int i = 0; i < 14; i++) i])).checkInsSinceTracked,
      14,
    );
    // Today missing: at most 13, never "14 of the last 14".
    expect(
      (await read(<int>[for (int i = 1; i < 15; i++) i])).checkInsSinceTracked,
      13,
    );
    // The 15th day back is outside the window.
    expect((await read(<int>[14, 15])).checkInsSinceTracked, 0);
    // Two check-ins in one day count once.
    expect((await read(<int>[0, 0])).checkInsSinceTracked, 1);
  });

  test('a weekly habit is counted over this week and the one before', () async {
    final HabitEntity weekly = HabitEntity(
      id: 'w',
      title: 'Weekly',
      createdAt: now.subtract(const Duration(days: 90)),
      cadence: HabitCadence.weekly,
    );
    Future<int> count(List<int> daysAgo) async =>
        (await gateway(
              habits: <HabitEntity>[weekly],
              occurrences: <HabitOccurrenceEntity>[
                for (final int i in daysAgo)
                  checkIn(weekly, now.subtract(Duration(days: i))),
              ],
            ).read(observedAt: now, includeActivity: true))
            .habits
            .single
            .checkInsSinceTracked;

    expect(await count(<int>[0, 7]), 2);
    // Three weeks back is outside the last two weeks.
    expect(await count(<int>[21]), 0);
  });

  test(
    'the 14 day window counts calendar days across a clock change',
    () async {
      // 8 March 2026 is a 23 hour day in the US zones. A task finished
      // exactly 14 calendar days earlier, at the same local time, is inside
      // the window; one 15 days earlier is not. One at 11:30 on 22 February
      // is inside a window of 336 hours (it starts at 11:00 local there) but
      // before the calendar-day window, so it is left out. That case can
      // only fail on a machine in a zone that moves its clocks on 8 March.
      final DateTime at = DateTime(2026, 3, 8, 12);
      final SIV2EvidenceSnapshot s = await gateway(
        tasks: <TaskEntity>[
          TaskEntity(
            id: 'edge',
            title: 'Edge',
            createdAt: DateTime(2026, 1, 1),
            isCompleted: true,
            completedAt: DateTime(2026, 2, 22, 12),
          ),
          TaskEntity(
            id: 'out',
            title: 'Out',
            createdAt: DateTime(2026, 1, 1),
            isCompleted: true,
            completedAt: DateTime(2026, 2, 21, 11),
          ),
          TaskEntity(
            id: 'hour',
            title: 'Hour',
            createdAt: DateTime(2026, 1, 1),
            isCompleted: true,
            completedAt: DateTime(2026, 2, 22, 11, 30),
          ),
        ],
      ).read(observedAt: at.toUtc(), includeActivity: true);
      expect(s.recentTasks.map((t) => t.id), <String>['edge']);
    },
  );

  test(
    'a habit tracked for 5 days is counted, and judged, over those days',
    () async {
      final HabitEntity young = HabitEntity(
        id: 'y',
        title: 'Stretch',
        createdAt: now.subtract(const Duration(days: 5)),
      );
      final SIV2EvidenceSnapshot s = await gateway(
        habits: <HabitEntity>[young],
        occurrences: <HabitOccurrenceEntity>[
          for (final int i in <int>[0, 1, 3])
            checkIn(young, now.subtract(Duration(days: i))),
        ],
      ).read(observedAt: now, includeActivity: true);
      final SIV2HabitEvidence habit = s.habits.single;
      expect(habit.checkInsSinceTracked, 3);
      expect(habit.checkInsInWindow, 3);
      expect(habit.trackedSince, now.subtract(const Duration(days: 5)));
      // Six calendar days from the day it was created to today, both counted.
      final String line = const SIOneTapEngine()
          .answer(
            question: SIOneTapQuestion.improveRoutine,
            snapshot: s,
            now: now.toLocal(),
            isSpanish: false,
          )
          .response
          .observedFacts
          .first
          .text;
      expect(line, contains('checked in on 3 of the last 6 days'));
    },
  );
}
