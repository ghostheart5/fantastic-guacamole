import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/errors/domain_validation_exception.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/domain/policies/task_policy.dart';

/// CHRONOSPARK-CLASS: SHIPPING | Feature: Goals/tasks
///
/// Used by the Timeline task-edit flow through taskProvider. Gated by
/// [TaskPolicy.isValid].
class UpdateTask {
  UpdateTask(this.repository);

  final ITaskRepository repository;

  Future<void> call(TaskEntity task, {DateTime? now}) async {
    if (!TaskPolicy.isValid(task)) {
      throw const DomainValidationException(
        code: 'invalid_task',
        message: 'Task fields do not satisfy the task policy.',
      );
    }
    await repository.saveTask(task.copyWith(updatedAt: now ?? DateTime.now()));
  }
}
