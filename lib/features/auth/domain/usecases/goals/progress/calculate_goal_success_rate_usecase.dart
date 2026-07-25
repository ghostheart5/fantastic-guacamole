import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';

class GoalSuccessRateResult {
  const GoalSuccessRateResult({
    required this.goalId,
    required this.totalTasks,
    required this.completedTasks,
    required this.successRate,
  });

  final String goalId;
  final int totalTasks;
  final int completedTasks;
  final double successRate;
}

class CalculateGoalSuccessRateUsecase {
  const CalculateGoalSuccessRateUsecase(
    this._goalRepository,
    this._taskRepository,
  );

  final IGoalRepository _goalRepository;
  final ITaskRepository _taskRepository;

  Future<GoalSuccessRateResult?> call(String goalId) async {
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

    final List<TaskEntity> tasks = await _taskRepository.getAllTasks();
    final List<TaskEntity> linkedTasks = tasks
        .where((TaskEntity task) => task.goalId == targetId)
        .toList(growable: false);

    final int completed = linkedTasks
        .where((TaskEntity task) => task.isCompleted)
        .length;

    final double rate = linkedTasks.isEmpty
        ? 0
        : completed / linkedTasks.length;

    return GoalSuccessRateResult(
      goalId: targetId,
      totalTasks: linkedTasks.length,
      completedTasks: completed,
      successRate: rate,
    );
  }
}
