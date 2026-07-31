import 'package:fantastic_guacamole/domain/entities/recurrence_rule.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/domain/usecases/complete_task.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CompleteTask workflow', () {
    test('completes one-time task without creating a new occurrence', () async {
      final _FakeTaskRepository repo = _FakeTaskRepository(
        seed: <TaskEntity>[
          TaskEntity(
            id: 'task-1',
            title: 'One-time task',
            createdAt: DateTime(2026, 1, 1),
            recurrenceRule: RecurrenceRule.none,
          ),
        ],
      );

      await CompleteTask(repo).call('task-1');

      expect(repo.savedOrder.length, 1);
      final TaskEntity? saved = await repo.getTaskById('task-1');
      expect(saved, isNotNull);
      expect(saved!.isCompleted, isTrue);
      expect(saved.completedAt, isNotNull);
    });

    test('completing recurring task creates next scheduled occurrence', () async {
      final _FakeTaskRepository repo = _FakeTaskRepository(
        seed: <TaskEntity>[
          TaskEntity(
            id: 'routine-1',
            title: 'Daily routine',
            createdAt: DateTime(2026, 1, 1),
            recurrenceRule: RecurrenceRule.daily,
          ),
        ],
      );

      final DateTime before = DateTime.now();
      await CompleteTask(repo).call('routine-1');
      final DateTime after = DateTime.now();

      expect(repo.savedOrder.length, 2);

      final TaskEntity? completed = await repo.getTaskById('routine-1');
      expect(completed, isNotNull);
      expect(completed!.isCompleted, isTrue);
      expect(completed.completedAt, isNotNull);

      final TaskEntity next = repo.savedOrder.last;
      expect(next.id, isNot('routine-1'));
      expect(next.isCompleted, isFalse);
      expect(next.completedAt, isNull);
      expect(next.recurrenceRule, RecurrenceRule.daily);
      expect(next.scheduledFor, isNotNull);

      final Duration fromBefore = next.scheduledFor!.difference(before);
      final Duration fromAfter = next.scheduledFor!.difference(after);
      expect(fromBefore.inHours, greaterThanOrEqualTo(23));
      expect(fromAfter.inHours, lessThanOrEqualTo(24));
    });

    test('completing recurring task early preserves cadence from scheduled time', () async {
      final DateTime now = DateTime.now();
      final DateTime scheduledFor = now.add(const Duration(hours: 6));
      final _FakeTaskRepository repo = _FakeTaskRepository(
        seed: <TaskEntity>[
          TaskEntity(
            id: 'routine-early',
            title: 'Weekly routine',
            createdAt: DateTime(2026, 1, 1),
            scheduledFor: scheduledFor,
            recurrenceRule: RecurrenceRule.weekly,
          ),
        ],
      );

      await CompleteTask(repo).call('routine-early');

      final TaskEntity next = repo.savedOrder.last;
      final DateTime expected = scheduledFor.add(const Duration(days: 7));
      expect(next.scheduledFor, isNotNull);
      expect(next.scheduledFor!.difference(expected).inSeconds.abs(), lessThan(2));
    });

    test('overdue recurring completion rolls forward to a future occurrence', () async {
      final DateTime now = DateTime.now();
      final DateTime overdueSchedule = now.subtract(const Duration(days: 2));
      final _FakeTaskRepository repo = _FakeTaskRepository(
        seed: <TaskEntity>[
          TaskEntity(
            id: 'routine-overdue',
            title: 'Daily overdue routine',
            createdAt: DateTime(2026, 1, 1),
            scheduledFor: overdueSchedule,
            recurrenceRule: RecurrenceRule.daily,
          ),
        ],
      );

      await CompleteTask(repo).call('routine-overdue');

      final TaskEntity next = repo.savedOrder.last;
      expect(next.scheduledFor, isNotNull);
      expect(next.scheduledFor!.isAfter(now), isTrue);
    });
  });
}

class _FakeTaskRepository implements ITaskRepository {
  _FakeTaskRepository({required List<TaskEntity> seed}) {
    for (final TaskEntity task in seed) {
      _store[task.id] = task;
    }
  }

  final Map<String, TaskEntity> _store = <String, TaskEntity>{};
  final List<TaskEntity> savedOrder = <TaskEntity>[];

  @override
  Future<void> deleteTask(String id) async {
    _store.remove(id);
  }

  @override
  Future<List<TaskEntity>> getAllTasks() async {
    return _store.values.toList(growable: false);
  }

  @override
  Future<TaskEntity?> getTaskById(String id) async {
    return _store[id];
  }

  @override
  Future<void> saveTask(TaskEntity task) async {
    _store[task.id] = task;
    savedOrder.add(task);
  }
}
