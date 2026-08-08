import 'package:fantastic_guacamole/domain/entities/task_entity.dart';

/// CHRONOSPARK-CLASS: SHIPPING | Feature: Goals/tasks
///
/// Bound to TaskRepository.
abstract class ITaskRepository {
  Future<List<TaskEntity>> getAllTasks();

  Future<TaskEntity?> getTaskById(String id);
  Future<void> saveTask(TaskEntity task);
  Future<void> deleteTask(String id);
}
