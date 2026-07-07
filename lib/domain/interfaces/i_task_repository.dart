import 'package:fantastic_guacamole/domain/entities/task_entity.dart';

abstract class ITaskRepository {
  Future<List<TaskEntity>> getAllTasks();

  Future<TaskEntity?> getTaskById(String id);
  Future<void> saveTask(TaskEntity task);
  Future<void> deleteTask(String id);
}
