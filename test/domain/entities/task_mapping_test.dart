import 'package:fantastic_guacamole/domain/entities/recurrence_rule.dart';
import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final TaskEntity fullEntity = TaskEntity(
    id: 'task-1',
    title: 'Write the spec',
    description: 'the important one',
    createdAt: DateTime.utc(2026, 7, 4),
    updatedAt: DateTime.utc(2026, 7, 4, 12),
    isCompleted: true,
    priority: 4,
    difficulty: 2,
    energyRequired: 5,
    estimatedDuration: const Duration(minutes: 45),
    completedAt: DateTime.utc(2026, 7, 5),
    isSkipped: true,
    skippedAt: DateTime.utc(2026, 7, 5, 8),
    scheduledFor: DateTime.utc(2026, 7, 6),
    occurrenceKey: 'task-1:2026-07-06',
    dueDate: DateTime.utc(2026, 7, 7),
    goalId: 'goal-1',
    subtasks: const <String>['sub-1', 'sub-2'],
    recurrenceRule: RecurrenceRule.daily,
  );

  test('Task compatibility adapter preserves every canonical field', () {
    final Task task = Task.fromEntity(fullEntity);

    expect(task, isA<TaskEntity>());
    expect(task.id, fullEntity.id);
    expect(task.title, fullEntity.title);
    expect(task.description, fullEntity.description);
    expect(task.createdAt, fullEntity.createdAt);
    expect(task.updatedAt, fullEntity.updatedAt);
    expect(task.isCompleted, fullEntity.isCompleted);
    expect(task.priority, fullEntity.priority);
    expect(task.difficulty, fullEntity.difficulty);
    expect(task.energyRequired, fullEntity.energyRequired);
    expect(task.estimatedDuration, fullEntity.estimatedDuration);
    expect(task.completedAt, fullEntity.completedAt);
    expect(task.isSkipped, fullEntity.isSkipped);
    expect(task.skippedAt, fullEntity.skippedAt);
    expect(task.scheduledFor, fullEntity.scheduledFor);
    expect(task.occurrenceKey, fullEntity.occurrenceKey);
    expect(task.dueDate, fullEntity.dueDate);
    expect(task.goalId, fullEntity.goalId);
    expect(task.subtasks, fullEntity.subtasks);
    expect(task.recurrenceRule, fullEntity.recurrenceRule);
  });

  test('canonical JSON round trip preserves lifecycle and planning state', () {
    final Task restored = Task.fromJson(fullEntity.toJson());

    expect(restored.toJson(), fullEntity.toJson());
  });

  test('legacy construction retains a deterministic creation epoch', () {
    final Task task = Task(
      id: 'task-2',
      title: 'Legacy fixture',
      priority: 3,
      difficulty: 3,
      energyRequired: 3,
    );

    expect(task.createdAt, DateTime.fromMillisecondsSinceEpoch(0));
    expect(task.estimatedDuration, const Duration(minutes: 30));
  });
}
