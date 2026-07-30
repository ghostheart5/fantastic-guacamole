import 'package:fantastic_guacamole/domain/entities/task_entity.dart';

class TaskPolicy {
  static bool isValid(TaskEntity task) {
    if (task.title.trim().isEmpty) return false;
    if (task.priority < 1 || task.priority > 5) return false;
    return true;
  }

  static bool canComplete(TaskEntity task) {
    return !task.isCompleted;
  }
}
