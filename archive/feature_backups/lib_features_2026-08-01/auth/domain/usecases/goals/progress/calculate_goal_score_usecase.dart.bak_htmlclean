import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';

class GoalScoreResult {
  const GoalScoreResult({
    required this.goal,
    required this.totalTasks,
    required this.completedTasks,
    required this.overdueTasks,
    required this.score,
  });

  final GoalEntity goal;
  final int totalTasks;
  final int completedTasks;
  final int overdueTasks;
  final int score;

  double get completionRate {
    if (totalTasks == 0) {
      return 0;
    }
    return completedTasks / totalTasks;
  }
}

class CalculateGoalScoreUsecase {
  const CalculateGoalScoreUsecase(this._goalRepository, this._taskRepository);

  final IGoalRepository _goalRepository;
  final ITaskRepository _taskRepository;

  Future<GoalScoreResult?> call(String goalId) async {
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

    final List<TaskEntity> tasks = await _taskRepository.getAllTasks();
    final List<TaskEntity> linkedTasks = tasks
        .where((TaskEntity task) => task.goalId == targetId)
        .toList(growable: false);

    final int completed = linkedTasks
        .where((TaskEntity task) => task.isCompleted)
        .length;

    final int overdue = linkedTasks
        .where((TaskEntity task) => task.isOverdue)
        .length;

    final double completionRate = linkedTasks.isEmpty
        ? 0
        : completed / linkedTasks.length;

    final int overduePenalty = overdue * 8;
    final int score = ((completionRate * 100).round() - overduePenalty)
        .clamp(0, 100)
        .toInt();

    return GoalScoreResult(
      goal: selectedGoal,
      totalTasks: linkedTasks.length,
      completedTasks: completed,
      overdueTasks: overdue,
      score: score,
    );
  }
}
