import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/domain/usecases/delete_task.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DeleteTask', () {
    test('removes task by id', () async {
      final _FakeTaskRepository repository = _FakeTaskRepository();
      await repository.saveTask(
        TaskEntity(id: 'task-1', title: 'Delete me', createdAt: DateTime.utc(2026, 7, 5)),
      );

      await DeleteTask(repository).call('task-1');

      expect(await repository.getTaskById('task-1'), isNull);
    });

    test('missing id returns safe failure behavior', () async {
      final _FakeTaskRepository repository = _FakeTaskRepository();

      await expectLater(DeleteTask(repository).call('missing-task-id'), completes);
      expect(await repository.getTaskById('missing-task-id'), isNull);
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
