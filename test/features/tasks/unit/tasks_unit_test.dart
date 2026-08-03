import 'package:fantastic_guacamole/domain/entities/si_state_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/engine/tasks/task_filter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TaskFilter', () {
    final DateTime now = DateTime(2026, 8, 1, 12);

    TaskEntity makeTask({
      required String id,
      bool isCompleted = false,
      bool isCanceled = false,
      DateTime? dueDate,
      DateTime? scheduledFor,
      int difficulty = 3,
      int energyRequired = 3,
      String? goalId,
    }) {
      return TaskEntity(
        id: id,
        title: 'Task $id',
        createdAt: DateTime(2026, 1, 1),
        isCompleted: isCompleted,
        isCanceled: isCanceled,
        dueDate: dueDate,
        scheduledFor: scheduledFor,
        difficulty: difficulty,
        energyRequired: energyRequired,
        goalId: goalId,
      );
    }

    test('incomplete excludes completed and canceled tasks', () {
      final List<TaskEntity> tasks = <TaskEntity>[
        makeTask(id: 'a'),
        makeTask(id: 'b', isCompleted: true),
        makeTask(id: 'c', isCanceled: true),
      ];

      final List<TaskEntity> filtered = TaskFilter.incomplete(tasks);
      expect(filtered.map((TaskEntity t) => t.id), <String>['a']);
    });

    test('overdue and dueSoon honor explicit now and edge boundaries', () {
      final List<TaskEntity> tasks = <TaskEntity>[
        makeTask(id: 'overdue', dueDate: now.subtract(const Duration(minutes: 1))),
        makeTask(id: 'atNow', dueDate: now),
        makeTask(id: 'insideWindow', dueDate: now.add(const Duration(hours: 1))),
        makeTask(id: 'atCutoff', dueDate: now.add(const Duration(hours: 24))),
        makeTask(id: 'done', dueDate: now.subtract(const Duration(days: 1)), isCompleted: true),
      ];

      final List<TaskEntity> overdue = TaskFilter.overdue(tasks, now: now);
      final List<TaskEntity> dueSoon = TaskFilter.dueSoon(tasks, now: now);

      expect(overdue.map((TaskEntity t) => t.id), <String>['overdue']);
      expect(dueSoon.map((TaskEntity t) => t.id), <String>['atNow', 'insideWindow']);
      expect(dueSoon.any((TaskEntity t) => t.id == 'atCutoff'), isFalse);
    });

    test('bySiState prefers easy tasks for safety-first instinct and falls back when needed', () {
      final List<TaskEntity> mixed = <TaskEntity>[
        makeTask(id: 'easy', difficulty: 2),
        makeTask(id: 'hard', difficulty: 4),
      ];
      final SiStateEntity safetyFirst = SiStateEntity(
        energy: 0.4,
        focus: 0.4,
        fatigue: 0.4,
        primaryInstinct: 'safety_first',
      );

      final List<TaskEntity> easyOnly = TaskFilter.bySiState(mixed, safetyFirst);
      expect(easyOnly.map((TaskEntity t) => t.id), <String>['easy']);

      final List<TaskEntity> allHard = <TaskEntity>[makeTask(id: 'hard-1', difficulty: 5)];
      final List<TaskEntity> fallback = TaskFilter.bySiState(allHard, safetyFirst);
      expect(fallback.map((TaskEntity t) => t.id), <String>['hard-1']);
    });
  });
}
