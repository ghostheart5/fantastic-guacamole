import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';

class LinkTaskToGoalUsecase {
  const LinkTaskToGoalUsecase(this._goalRepository, this._taskRepository);

  final IGoalRepository _goalRepository;
  final ITaskRepository _taskRepository;

  Future<TaskEntity?> call({
    required String taskId,
    required String goalId,
  }) async {
    final String targetTaskId = taskId.trim();
    final String targetGoalId = goalId.trim();

    if (targetTaskId.isEmpty || targetGoalId.isEmpty) {
      return null;
    }

    final bool goalExists = _goalRepository.getGoals().any(
      (goal) => goal.id == targetGoalId,
    );

    if (!goalExists) {
      return null;
    }

    final TaskEntity? task = await _taskRepository.getTaskById(targetTaskId);

    if (task == null) {
      return null;
    }

    final TaskEntity updated = task.copyWith(goalId: targetGoalId);

    await _taskRepository.saveTask(updated);

    return updated;
  }
}
