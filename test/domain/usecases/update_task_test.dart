import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/domain/usecases/update_task.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UpdateTask', () {
    late _FakeTaskRepository repository;

    setUp(() {
      repository = _FakeTaskRepository();
    });

    test('saves valid task', () async {
      final TaskEntity task = TaskEntity(
        id: 'task-1',
        title: 'Refine UI',
        createdAt: DateTime.utc(2026, 7, 5),
      );

      await UpdateTask(repository).call(task);

      expect((await repository.getTaskById('task-1'))?.title, 'Refine UI');
    });

    test('throws for invalid task', () async {
      final TaskEntity invalid = TaskEntity(
        id: 'task-bad',
        title: '',
        createdAt: DateTime.utc(2026, 7, 5),
      );

      await expectLater(() => UpdateTask(repository).call(invalid), throwsException);
    });

    test('preserves task ID while updating mutable fields', () async {
      final TaskEntity original = TaskEntity(
        id: 'task-42',
        title: 'Original',
        description: 'v1',
        priority: 2,
        difficulty: 2,
        energyRequired: 2,
        createdAt: DateTime.utc(2026, 7, 5),
      );
      await repository.saveTask(original);

      final TaskEntity updated = original.copyWith(
        title: 'Updated title',
        description: 'v2',
        priority: 5,
      );

      await UpdateTask(repository).call(updated);

      final TaskEntity? saved = await repository.getTaskById('task-42');
      expect(saved, isNotNull);
      expect(saved?.id, 'task-42');
      expect(saved?.title, 'Updated title');
      expect(saved?.description, 'v2');
      expect(saved?.priority, 5);
    });
  });
}

class _FakeTaskRepository implements ITaskRepository {
  final Map<String, TaskEntity> _tasks = <String, TaskEntity>{};

  @override
  Future<void> deleteTask(String id) async {
    _tasks.remove(id);
  }

  @override
  Future<List<TaskEntity>> getAllTasks() async => _tasks.values.toList();

  @override
  Future<TaskEntity?> getTaskById(String id) async => _tasks[id];

  @override
  Future<void> saveTask(TaskEntity task) async {
    _tasks[task.id] = task;
  }
}
