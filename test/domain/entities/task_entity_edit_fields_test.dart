import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('task edit fields can be explicitly cleared without stale values', () {
    final TaskEntity task = TaskEntity(
      id: 'task-1',
      title: 'Linked task',
      createdAt: DateTime.utc(2026, 8, 30),
      description: 'Context',
      estimatedDuration: const Duration(minutes: 45),
      scheduledFor: DateTime.utc(2026, 8, 31, 9),
      dueDate: DateTime.utc(2026, 9, 1),
      goalId: 'goal-1',
    );

    final TaskEntity cleared = task.copyWith(
      clearDescription: true,
      clearEstimatedDuration: true,
      clearScheduledFor: true,
      clearDueDate: true,
      clearGoalId: true,
    );

    expect(cleared.description, isNull);
    expect(cleared.estimatedDuration, isNull);
    expect(cleared.scheduledFor, isNull);
    expect(cleared.dueDate, isNull);
    expect(cleared.goalId, isNull);
  });

  test('task actionability excludes every terminal lifecycle state', () {
    final DateTime reference = DateTime.utc(2026, 8, 30, 12);
    TaskEntity task({
      bool completed = false,
      bool skipped = false,
      bool canceled = false,
    }) => TaskEntity(
      id: 'task',
      title: 'Task',
      createdAt: reference,
      isCompleted: completed,
      completedAt: completed ? reference : null,
      isSkipped: skipped,
      skippedAt: skipped ? reference : null,
      isCanceled: canceled,
    );

    expect(task().isActionableAt(reference), isTrue);
    expect(task(completed: true).isActionableAt(reference), isFalse);
    expect(task(skipped: true).isActionableAt(reference), isFalse);
    expect(task(canceled: true).isActionableAt(reference), isFalse);
  });

  test('typed temporal commands set and clear schedule and deadline', () {
    final DateTime createdAt = DateTime.utc(2026, 8, 30, 8);
    final DateTime changedAt = DateTime.utc(2026, 8, 30, 9);
    final DateTime schedule = DateTime.utc(2026, 8, 31, 10);
    final DateTime deadline = DateTime.utc(2026, 8, 31, 17);
    final TaskEntity task = TaskEntity(
      id: 'temporal-task',
      title: 'Temporal task',
      createdAt: createdAt,
    );

    final TaskEntity scheduled = task.applyTemporalEdit(
      SetSchedule(schedule),
      at: changedAt,
    );
    final TaskEntity dated = scheduled.applyTemporalEdit(
      SetDeadline(deadline),
      at: changedAt,
    );
    final TaskEntity clearedSchedule = dated.applyTemporalEdit(
      const ClearSchedule(),
      at: changedAt,
    );
    final TaskEntity clearedDeadline = clearedSchedule.applyTemporalEdit(
      const ClearDeadline(),
      at: changedAt,
    );

    expect(scheduled.scheduledFor, schedule);
    expect(dated.dueDate, deadline);
    expect(clearedSchedule.scheduledFor, isNull);
    expect(clearedDeadline.dueDate, isNull);
    expect(clearedDeadline.updatedAt, changedAt);
  });

  test('terminal tasks reject typed temporal commands', () {
    final DateTime now = DateTime.utc(2026, 8, 30, 9);
    final TaskEntity completed = TaskEntity(
      id: 'completed',
      title: 'Completed',
      createdAt: now.subtract(const Duration(hours: 1)),
      isCompleted: true,
      completedAt: now,
    );

    expect(
      () => completed.applyTemporalEdit(
        SetSchedule(now.add(const Duration(days: 1))),
        at: now,
      ),
      throwsStateError,
    );
  });
}
