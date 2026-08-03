import 'package:fantastic_guacamole/domain/entities/recurrence_rule.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/domain/usecases/complete_task.dart';
import 'package:fantastic_guacamole/domain/usecases/create_task.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Task System', () {
    test('create task saves a valid task', () async {
      final _InMemoryTaskRepository repo = _InMemoryTaskRepository();
      final CreateTask createTask = CreateTask(repo);

      final TaskEntity task = TaskEntity(
        id: 'task-1',
        title: 'Write launch brief',
        createdAt: DateTime(2026, 1, 1),
        priority: 3,
        difficulty: 2,
        energyRequired: 2,
      );

      await createTask.call(task);

      final TaskEntity? saved = await repo.getTaskById('task-1');
      expect(saved, isNotNull);
      expect(saved!.title, 'Write launch brief');
      expect(saved.isCompleted, isFalse);
    });

    test('complete task marks task complete with timestamp', () async {
      final _InMemoryTaskRepository repo = _InMemoryTaskRepository();
      final CompleteTask completeTask = CompleteTask(repo);

      final TaskEntity task = TaskEntity(
        id: 'task-2',
        title: 'Finish execution block',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      );
      await repo.saveTask(task);

      await completeTask.call('task-2');

      final TaskEntity? completed = await repo.getTaskById('task-2');
      expect(completed, isNotNull);
      expect(completed!.isCompleted, isTrue);
      expect(completed.completedAt, isNotNull);
    });

    test('overdue detection reflects due date and completion state', () {
      final DateTime now = DateTime.now();
      final TaskEntity overdue = TaskEntity(
        id: 'task-3',
        title: 'Past due',
        createdAt: now.subtract(const Duration(days: 2)),
        dueDate: now.subtract(const Duration(hours: 1)),
      );
      final TaskEntity upcoming = TaskEntity(
        id: 'task-4',
        title: 'Upcoming',
        createdAt: now,
        dueDate: now.add(const Duration(hours: 3)),
      );
      final TaskEntity completedPastDue = TaskEntity(
        id: 'task-5',
        title: 'Completed past due',
        createdAt: now.subtract(const Duration(days: 1)),
        dueDate: now.subtract(const Duration(hours: 2)),
        isCompleted: true,
        completedAt: now.subtract(const Duration(hours: 1)),
      );

      expect(overdue.isOverdue, isTrue);
      expect(upcoming.isOverdue, isFalse);
      expect(completedPastDue.isOverdue, isFalse);
    });

    test('recurrence creates next scheduled task instance', () async {
      final _InMemoryTaskRepository repo = _InMemoryTaskRepository();
      final CompleteTask completeTask = CompleteTask(repo);

      final DateTime originalSchedule = DateTime.now().subtract(
        const Duration(days: 1),
      );
      final TaskEntity recurring = TaskEntity(
        id: 'task-6',
        title: 'Daily standup recap',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        scheduledFor: originalSchedule,
        recurrenceRule: RecurrenceRule.daily,
      );
      await repo.saveTask(recurring);

      await completeTask.call('task-6');

      final TaskEntity? completed = await repo.getTaskById('task-6');
      expect(completed, isNotNull);
      expect(completed!.isCompleted, isTrue);

      final List<TaskEntity> all = await repo.getAllTasks();
      final List<TaskEntity> spawned = all
          .where((TaskEntity task) => task.id != 'task-6')
          .toList(growable: false);

      expect(spawned, hasLength(1));
      expect(spawned.first.isCompleted, isFalse);
      expect(spawned.first.recurrenceRule, RecurrenceRule.daily);
      expect(spawned.first.scheduledFor, isNotNull);
      expect(spawned.first.scheduledFor!.isAfter(DateTime.now()), isTrue);
    });
  });
}

class _InMemoryTaskRepository implements ITaskRepository {
  final Map<String, TaskEntity> _tasks = <String, TaskEntity>{};

  @override
  Future<void> deleteTask(String id) async {
    _tasks.remove(id);
  }

  @override
  Future<List<TaskEntity>> getAllTasks() async {
    return _tasks.values.toList(growable: false);
  }

  @override
  Future<TaskEntity?> getTaskById(String id) async {
    return _tasks[id];
  }

  @override
  Future<void> saveTask(TaskEntity task) async {
    _tasks[task.id] = task;
  }
}
