import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';

class RecommendNextActionUsecase {
  const RecommendNextActionUsecase(this._goalRepository, this._taskRepository);

  final IGoalRepository _goalRepository;
  final ITaskRepository _taskRepository;

  Future<String?> call(String goalId) async {
    final String targetId = goalId.trim();
    if (targetId.isEmpty) {
      return null;
    }

    GoalEntity? selectedGoal;
    for (final GoalEntity goal in _goalRepository.getGoals()) {
      if (goal.id == targetId) {
        selectedGoal = goal;
        break;
      }
    }

    if (selectedGoal == null) {
      return null;
    }

    final List<TaskEntity> linkedTasks = (await _taskRepository.getAllTasks())
        .where((TaskEntity task) => task.goalId == targetId)
        .toList(growable: false);

    for (final TaskEntity task in linkedTasks) {
      if (!task.isCompleted && !task.isCanceled) {
        return 'Next action: ${task.title}';
      }
    }

    if (selectedGoal.targetDate == null) {
      return 'Set a target date for ${selectedGoal.title}.';
    }

    return 'Create a new task for ${selectedGoal.title}.';
  }
}
