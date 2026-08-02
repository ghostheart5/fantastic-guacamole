import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';

class UpdateGoalProgressUsecase {
  const UpdateGoalProgressUsecase(this._goalRepository, this._taskRepository);

  final IGoalRepository _goalRepository;
  final ITaskRepository _taskRepository;

  Future<int?> call({
    required String goalId,
    required int completedTaskCount,
  }) async {
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

    final int desiredCompleted = completedTaskCount.clamp(
      0,
      linkedTasks.length,
    );

    for (int index = 0; index < linkedTasks.length; index++) {
      final TaskEntity task = linkedTasks[index];
      final bool shouldBeCompleted = index < desiredCompleted;

      if (task.isCompleted != shouldBeCompleted) {
        await _taskRepository.saveTask(
          shouldBeCompleted
              ? task.complete()
              : task.copyWith(isCompleted: false),
        );
      }
    }

    return desiredCompleted;
  }
}
