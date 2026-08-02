import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';

class GoalProgressMutationResult {
  const GoalProgressMutationResult({
    required this.goalId,
    required this.totalTasks,
    required this.completedTasks,
    required this.changed,
  });

  final String goalId;
  final int totalTasks;
  final int completedTasks;
  final bool changed;

  double get progress {
    if (totalTasks == 0) {
      return 0;
    }
    return completedTasks / totalTasks;
  }
}

class IncrementGoalProgressUsecase {
  const IncrementGoalProgressUsecase(
    this._goalRepository,
    this._taskRepository,
  );

  final IGoalRepository _goalRepository;
  final ITaskRepository _taskRepository;

  Future<GoalProgressMutationResult?> call(String goalId) async {
    final String targetId = goalId.trim();
    if (targetId.isEmpty) {
      return null;
    }

    final bool goalExists = _goalRepository.getGoals().any(
      (goal) => goal.id == targetId,
    );

    if (!goalExists) {
      return null;
    }

    final List<TaskEntity> linkedTasks = (await _taskRepository.getAllTasks())
        .where((TaskEntity task) => task.goalId == targetId)
        .toList(growable: false);

    TaskEntity? nextIncomplete;
    for (final TaskEntity task in linkedTasks) {
      if (!task.isCompleted && !task.isCanceled) {
        nextIncomplete = task;
        break;
      }
    }

    bool changed = false;
    if (nextIncomplete != null) {
      await _taskRepository.saveTask(nextIncomplete.complete());
      changed = true;
    }

    final List<TaskEntity> updatedTasks = (await _taskRepository.getAllTasks())
        .where((TaskEntity task) => task.goalId == targetId)
        .toList(growable: false);

    final int completed = updatedTasks
        .where((TaskEntity task) => task.isCompleted)
        .length;

    return GoalProgressMutationResult(
      goalId: targetId,
      totalTasks: updatedTasks.length,
      completedTasks: completed,
      changed: changed,
    );
  }
}
