import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';

class ResetGoalProgressUsecase {
  const ResetGoalProgressUsecase(this._goalRepository, this._taskRepository);

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

    for (final TaskEntity task in linkedTasks) {
      if (task.isCompleted) {
        await _taskRepository.saveTask(task.copyWith(isCompleted: false));
      }
    }

    return 0;
  }
}
