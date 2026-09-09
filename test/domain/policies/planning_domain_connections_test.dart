import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_occurrence_entity.dart';
import 'package:fantastic_guacamole/domain/entities/log_entry_entity.dart';
import 'package:fantastic_guacamole/domain/entities/recurrence_rule.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/planning/rhythm_planning_context.dart';
import 'package:fantastic_guacamole/domain/policies/recent_skip_policy.dart';
import 'package:fantastic_guacamole/state/models/goal_progress_view.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('goal ratio excludes terminal omissions and ongoing series', () {
    final now = DateTime(2026, 9, 8);
    final completed = TaskEntity(
      id: 'done',
      title: 'Finite action',
      createdAt: now,
      isCompleted: true,
      completedAt: now,
      goalId: 'goal',
    );
    final progress = GoalProgressView.fromTasks([
      completed,
      completed.copyWith(
        id: 'canceled',
        isCompleted: false,
        clearCompletedAt: true,
        isCanceled: true,
      ),
      completed.copyWith(
        id: 'skipped',
        isCompleted: false,
        clearCompletedAt: true,
        isSkipped: true,
        skippedAt: now,
      ),
      completed.copyWith(id: 'repeated', recurrenceRule: RecurrenceRule.daily),
      completed.copyWith(
        id: 'tomorrow',
        recurrenceRule: RecurrenceRule.daily,
        isCompleted: false,
        clearCompletedAt: true,
        scheduledFor: now.add(const Duration(days: 1)),
      ),
    ]);
    expect(progress.totalCount, 1);
    expect(progress.completedCount, 1);
    expect(progress.fraction, 1);
    expect(progress.recurringCompletedCount, 1);
    expect(progress.excludedCount, 2);
  });

  test(
    'skip evidence has a seven-day window and rejects duplicates and future logs',
    () {
      final now = DateTime.utc(2026, 9, 8);
      LogEntryEntity skip(String id, DateTime at) => LogEntryEntity(
        id: id,
        message: 'Skipped',
        source: 'task_skipped',
        timestamp: at,
      );
      expect(
        RecentSkipPolicy.count([
          skip('old', now.subtract(const Duration(days: 8))),
          skip('future', now.add(const Duration(hours: 1))),
          skip('recent', now.subtract(const Duration(days: 1))),
          skip('recent', now.subtract(const Duration(days: 1))),
        ], now),
        1,
      );
    },
  );

  for (final cadence in HabitCadence.values) {
    test(
      '${cadence.name} completed period leaves workload and resets next period',
      () {
        final now = DateTime(2026, 9, 8, 12);
        final habit = HabitEntity(
          id: 'rhythm',
          title: 'Walk',
          createdAt: now,
          cadence: cadence,
          targetCount: 3,
        );
        final outcome = HabitOccurrenceEntity(
          habitId: habit.id,
          occurrenceKey: RhythmPlanningContext.periodKey(cadence, now),
          operationId: 'done',
          outcome: HabitOccurrenceOutcome.completed,
          recordedAt: now,
        );
        expect(
          RhythmPlanningContext.build(
            [habit],
            [outcome],
            now,
          ).single.needsAttention,
          isFalse,
        );
        final next = cadence == HabitCadence.monthly
            ? DateTime(2026, 10, 1)
            : now.add(Duration(days: cadence == HabitCadence.weekly ? 7 : 1));
        expect(
          RhythmPlanningContext.build(
            [habit],
            [outcome],
            next,
          ).single.needsAttention,
          isTrue,
        );
        expect(
          RhythmPlanningContext.build(
            [habit.copyWith(status: HabitStatus.paused)],
            [],
            now,
          ).single.status,
          RhythmPeriodStatus.paused,
        );
      },
    );
  }
}
