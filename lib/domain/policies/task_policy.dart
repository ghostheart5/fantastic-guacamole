import 'package:fantastic_guacamole/domain/entities/task_entity.dart';

/// CHRONOSPARK-CLASS: SHIPPING | Feature: Goals/tasks
///
/// Enforced by CreateTask, UpdateTask, CompleteTask.
class TaskPolicy {
  static bool isValid(TaskEntity task) {
    if (task.title.trim().isEmpty) return false;
    if (task.priority < 1 || task.priority > 5) return false;
    return true;
  }

  static bool canComplete(TaskEntity task, {DateTime? at}) =>
      task.isActionableAt(at ?? DateTime.now());
}
