import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';

class DecrementGoalProgressUsecase {
  const DecrementGoalProgressUsecase(
    this._goalRepository,
    this._taskRepository,
  );

  final IGoalRepository _goalRepository;
  final ITaskRepository _taskRepository;

  Future<int?> call(String goalId) async {
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

    TaskEntity? completedTask;
    for (final TaskEntity task in linkedTasks.reversed) {
      if (task.isCompleted) {
        completedTask = task;
        break;
      }
    }

    if (completedTask != null) {
      await _taskRepository.saveTask(
        completedTask.copyWith(isCompleted: false),
      );
    }

    final List<TaskEntity> updatedTasks = (await _taskRepository.getAllTasks())
        .where((TaskEntity task) => task.goalId == targetId)
        .toList(growable: false);

    return updatedTasks.where((TaskEntity task) => task.isCompleted).length;
  }
}
