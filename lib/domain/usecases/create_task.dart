import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/errors/domain_validation_exception.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/domain/policies/task_policy.dart';
import 'package:fantastic_guacamole/domain/usecases/generate_si_decision.dart';

/// CHRONOSPARK-CLASS: SHIPPING | Feature: Goals/tasks
///
/// Resolved by taskActionsProvider. Gated by TaskPolicy.isValid.
class CreateTask {
  CreateTask(this.repo, {this.generateSiDecision});

  final ITaskRepository repo;
  final GenerateSiDecision? generateSiDecision;

  Future<void> call(TaskEntity task, {bool Function()? shouldContinue}) async {
    if (!TaskPolicy.isValid(task)) {
      throw const DomainValidationException(
        code: 'invalid_task',
        message: 'Task fields do not satisfy the task policy.',
      );
    }

    TaskEntity finalTask = task;

    final GenerateSiDecision? si = generateSiDecision;
    if (si != null) {
      final siDecision = await si(task.title);
      finalTask = task.copyWith(
        priority: siDecision.shouldSimplify ? 1 : task.priority,
      );
    }

    // Planner preparation can outlive the account session that requested the
    // task. Check immediately before entering durable storage mutation.
    if (shouldContinue != null && !shouldContinue()) return;
    await repo.saveTask(finalTask);
  }
}
