import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_occurrence_entity.dart';
import 'package:fantastic_guacamole/domain/entities/milestone_entity.dart';
import 'package:fantastic_guacamole/domain/entities/si_v2_contract.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/planning/rhythm_planning_context.dart';
import 'package:fantastic_guacamole/state/services/si_v2_read_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Midday UTC keeps the local calendar day the same in every time zone that
  // matters for these checks.
  final DateTime now = DateTime.utc(2026, 8, 20, 12);

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
      ).read(observedAt: now);
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
    ).read(observedAt: now);
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
      ).read(observedAt: now);
      expect(snapshot.habits.map((SIV2HabitEvidence h) => h.id), <String>[
        'weekly',
      ]);
      expect(snapshot.habits.single.currentStreak, 3);
    },
  );

  test('habits are marked unavailable when they cannot be read', () async {
    final SIV2EvidenceSnapshot snapshot = await gateway(
      habitReader: () async => throw StateError('storage broke'),
    ).read(observedAt: now);
    expect(snapshot.habitsUnavailable, isTrue);
    expect(snapshot.habits, isEmpty);
  });

  test('without a habit reader nothing is claimed about habits', () async {
    final SIV2EvidenceSnapshot snapshot = await gateway().read(observedAt: now);
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
      ).read(observedAt: now);
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
    ).read(observedAt: now);
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

  test('a snapshot with none of the new records keeps its revision', () async {
    final SIV2EvidenceSnapshot plain = SIV2EvidenceSnapshot(
      accountScopeId: 'account:test',
      observedAt: now,
      tasks: const <SIV2TaskEvidence>[],
      goals: <SIV2GoalEvidence>[
        SIV2GoalEvidence(id: 'g', title: 'Goal', createdAt: now),
      ],
      milestones: const <SIV2MilestoneEvidence>[],
      timeline: const <SIV2TimelineEvidence>[],
    );
    final SIV2EvidenceSnapshot withHabit = SIV2EvidenceSnapshot(
      accountScopeId: 'account:test',
      observedAt: now,
      tasks: const <SIV2TaskEvidence>[],
      goals: plain.goals,
      milestones: const <SIV2MilestoneEvidence>[],
      timeline: const <SIV2TimelineEvidence>[],
      habits: <SIV2HabitEvidence>[
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
      ],
    );
    expect(plain.revision, hasLength(64));
    expect(withHabit.revision, isNot(plain.revision));
    // Pinned: goals without progress and no habits hash exactly as before.
    expect(
      SIV2EvidenceSnapshot(
        accountScopeId: 'account:test',
        observedAt: now,
        tasks: const <SIV2TaskEvidence>[],
        goals: plain.goals,
        milestones: const <SIV2MilestoneEvidence>[],
        timeline: const <SIV2TimelineEvidence>[],
      ).revision,
      plain.revision,
    );
  });
}
