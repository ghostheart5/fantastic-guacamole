import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';

class FakeTaskRepository implements ITaskRepository {
  FakeTaskRepository([List<TaskEntity>? seed])
    : _tasks = <String, TaskEntity>{
        for (final TaskEntity task in (seed ?? const <TaskEntity>[]))
          task.id: task,
      };

  final Map<String, TaskEntity> _tasks;

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
