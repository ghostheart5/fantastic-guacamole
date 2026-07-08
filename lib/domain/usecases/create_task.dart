import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/domain/policies/task_policy.dart';
import 'package:fantastic_guacamole/domain/usecases/generate_si_decision.dart';

class CreateTask {
  CreateTask(this.repo, {this.generateSiDecision});

  final ITaskRepository repo;
  final GenerateSiDecision? generateSiDecision;

  Future<void> call(TaskEntity task) async {
    if (!TaskPolicy.isValid(task)) {
      throw Exception('Invalid task');
    }

    TaskEntity finalTask = task;

    final GenerateSiDecision? si = generateSiDecision;
    if (si != null) {
      final siDecision = await si(task.title);
      finalTask = task.copyWith(
        priority: siDecision.shouldSimplify ? 1 : task.priority,
      );
    }

    await repo.saveTask(finalTask);
  }
}
