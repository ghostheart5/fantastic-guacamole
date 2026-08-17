import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/domain/policies/task_policy.dart';

/// CHRONOSPARK-CLASS: PLANNED | Feature: Goals/tasks
///
/// Registered as updateTaskUseCaseProvider; no task-edit UI flow yet. Gated by
/// TaskPolicy.isValid.
class UpdateTask {
  UpdateTask(this.repository);

  final ITaskRepository repository;

  Future<void> call(TaskEntity task) async {
    if (!TaskPolicy.isValid(task)) {
      throw Exception('Invalid task');
    }
    await repository.saveTask(task.copyWith(updatedAt: DateTime.now()));
  }
}
