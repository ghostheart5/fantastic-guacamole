import 'package:fantastic_guacamole/domain/entities/recurrence_rule.dart';
import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:flutter_test/flutter_test.dart';

/// Characterisation tests for the `Task` <-> `TaskEntity` duplication.
///
/// These do NOT assert that the mapping is good — they pin down exactly which
/// fields survive a round trip and which are lost, so a future migration has a
/// safety net and nobody "fixes" the mapping without noticing the gap.
/// See the compatibility note on `lib/domain/entities/task.dart`.

/// Mirrors the production mapping in
/// `lib/state/providers/domain_usecase_providers.dart` (`_taskFromEntity`).
Task taskFromEntityAsProductionDoes(TaskEntity entity) {
  return Task(
    id: entity.id,
    title: entity.title,
    priority: entity.priority,
    difficulty: entity.difficulty,
    energyRequired: entity.energyRequired,
  );
}

/// The most complete mapping the `Task` shape can express.
Task taskFromEntityComplete(TaskEntity entity) {
  return Task(
    id: entity.id,
    title: entity.title,
    priority: entity.priority,
    difficulty: entity.difficulty,
    energyRequired: entity.energyRequired,
    scheduledFor: entity.scheduledFor,
    goalId: entity.goalId,
    subtasks: entity.subtasks,
    recurrenceRule: entity.recurrenceRule,
  );
}

void main() {
  final TaskEntity fullEntity = TaskEntity(
    id: 'task-1',
    title: 'Write the spec',
    description: 'the important one',
    createdAt: DateTime.utc(2026, 7, 4),
    isCompleted: true,
    priority: 4,
    difficulty: 2,
    energyRequired: 5,
    estimatedDuration: const Duration(minutes: 45),
    completedAt: DateTime.utc(2026, 7, 5),
    scheduledFor: DateTime.utc(2026, 7, 6),
    dueDate: DateTime.utc(2026, 7, 7),
    goalId: 'goal-1',
    isCanceled: false,
    subtasks: const <String>['sub-1', 'sub-2'],
    recurrenceRule: RecurrenceRule.daily,
  );

  group('TaskEntity -> Task (complete mapping)', () {
    test('carries every field Task is able to represent', () {
      final Task task = taskFromEntityComplete(fullEntity);

      expect(task.id, 'task-1');
      expect(task.title, 'Write the spec');
      expect(task.priority, 4);
      expect(task.difficulty, 2);
      expect(task.energyRequired, 5);
      expect(task.scheduledFor, DateTime.utc(2026, 7, 6));
      expect(task.goalId, 'goal-1');
      expect(task.subtasks, <String>['sub-1', 'sub-2']);
      expect(task.recurrenceRule, RecurrenceRule.daily);
    });
  });

  group('TaskEntity -> Task drops fields Task cannot represent', () {
    test('the seven lost fields are documented and unrecoverable', () {
      // Task has no home for these. If Task ever grows one of them, delete the
      // corresponding line here as the compatibility migration advances.
      const List<String> knownLostFields = <String>[
        'description',
        'createdAt',
        'isCompleted',
        'completedAt',
        'dueDate',
        'isCanceled',
        'estimatedDuration',
      ];
      expect(knownLostFields, hasLength(7));

      final Task task = taskFromEntityComplete(fullEntity);

      // Round-tripping back cannot restore them: reconstruct and compare.
      final TaskEntity rebuilt = TaskEntity(
        id: task.id,
        title: task.title,
        createdAt: DateTime.utc(2000), // unrecoverable, placeholder
        priority: task.priority,
        difficulty: task.difficulty,
        energyRequired: task.energyRequired,
        scheduledFor: task.scheduledFor,
        goalId: task.goalId,
        subtasks: task.subtasks,
        recurrenceRule: task.recurrenceRule,
      );

      expect(rebuilt.description, isNull);
      expect(rebuilt.createdAt, isNot(fullEntity.createdAt));
      expect(rebuilt.isCompleted, isFalse);
      expect(rebuilt.completedAt, isNull);
      expect(rebuilt.dueDate, isNull);
      expect(rebuilt.estimatedDuration, isNull);
      expect(rebuilt.isCanceled, isFalse);

      // Everything Task DOES carry must survive intact.
      expect(rebuilt.id, fullEntity.id);
      expect(rebuilt.title, fullEntity.title);
      expect(rebuilt.priority, fullEntity.priority);
      expect(rebuilt.difficulty, fullEntity.difficulty);
      expect(rebuilt.energyRequired, fullEntity.energyRequired);
      expect(rebuilt.scheduledFor, fullEntity.scheduledFor);
      expect(rebuilt.goalId, fullEntity.goalId);
      expect(rebuilt.subtasks, fullEntity.subtasks);
      expect(rebuilt.recurrenceRule, fullEntity.recurrenceRule);
    });

    test(
      'the production mapping additionally drops scheduling and recurrence',
      () {
        final Task task = taskFromEntityAsProductionDoes(fullEntity);

        // These are silently lost today by `_taskFromEntity`, on top of the
        // seven fields Task structurally cannot hold.
        expect(task.scheduledFor, isNull);
        expect(task.goalId, isNull);
        expect(task.subtasks, isEmpty);
        expect(task.recurrenceRule, RecurrenceRule.none);
      },
    );
  });

  group('Task JSON coercion is lossy on invalid input', () {
    test('a missing id becomes empty rather than being rejected', () {
      final Task task = Task.fromJson(<String, dynamic>{'title': 'No id'});

      expect(task.id, isEmpty);
    });

    test('an out-of-range priority is accepted verbatim', () {
      final Task task = Task.fromJson(<String, dynamic>{
        'id': 'task-1',
        'title': 'Bad priority',
        'priority': 99,
      });

      // TaskPolicy.isValid would reject this, but fromJson does not.
      expect(task.priority, 99);
    });

    test('a valid payload round trips', () {
      final Task task = Task(
        id: 'task-1',
        title: 'Write the spec',
        priority: 4,
        difficulty: 2,
        energyRequired: 5,
        scheduledFor: DateTime.utc(2026, 7, 6),
        goalId: 'goal-1',
        subtasks: const <String>['sub-1'],
        recurrenceRule: RecurrenceRule.daily,
      );

      final Task restored = Task.fromJson(task.toJson());

      expect(restored.id, task.id);
      expect(restored.title, task.title);
      expect(restored.priority, task.priority);
      expect(restored.difficulty, task.difficulty);
      expect(restored.energyRequired, task.energyRequired);
      expect(restored.scheduledFor, task.scheduledFor);
      expect(restored.goalId, task.goalId);
      expect(restored.subtasks, task.subtasks);
      expect(restored.recurrenceRule, task.recurrenceRule);
    });
  });
}
