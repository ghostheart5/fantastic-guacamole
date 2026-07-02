import 'package:fantastic_guacamole/features/tasks/models/tasks_models.dart';
import 'package:fantastic_guacamole/features/tasks/repositories/task_repository.dart';

class TaskService {
  TaskService(this._repository);

  final TaskRepository _repository;

  Future<List<TaskModel>> getTasks() async {
    final List<Map<String, dynamic>> raw = await _repository.getTasks();
    return raw.map(TaskModel.fromJson).toList();
  }

  Future<void> saveTask(TaskModel task) => _repository.saveTask(task.toJson());

  Future<void> deleteTask(String id) => _repository.deleteTask(id);
}
