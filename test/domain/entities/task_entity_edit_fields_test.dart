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
}
