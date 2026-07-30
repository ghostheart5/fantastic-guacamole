import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';

class GoalBreakdownResult {
  const GoalBreakdownResult({
    required this.goal,
    required this.totalTasks,
    required this.completedTasks,
    required this.remainingTasks,
    required this.steps,
  });

  final GoalEntity goal;
  final int totalTasks;
  final int completedTasks;
  final int remainingTasks;
  final List<String> steps;
}

class GenerateGoalBreakdownUsecase {
  const GenerateGoalBreakdownUsecase(
    this._goalRepository,
    this._taskRepository,
  );

  final IGoalRepository _goalRepository;
  final ITaskRepository _taskRepository;

  Future<GoalBreakdownResult?> call(String goalId) async {
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

    final int completed = linkedTasks
        .where((TaskEntity task) => task.isCompleted)
        .length;

    final List<String> steps = linkedTasks.isEmpty
        ? <String>[
            'Define the first task for this goal.',
            'Choose a target date or review cadence.',
            'Review progress in the timeline.',
          ]
        : linkedTasks
              .map((TaskEntity task) => task.title)
              .toList(growable: false);

    return GoalBreakdownResult(
      goal: selectedGoal,
      totalTasks: linkedTasks.length,
      completedTasks: completed,
      remainingTasks: linkedTasks.length - completed,
      steps: steps,
    );
  }
}
