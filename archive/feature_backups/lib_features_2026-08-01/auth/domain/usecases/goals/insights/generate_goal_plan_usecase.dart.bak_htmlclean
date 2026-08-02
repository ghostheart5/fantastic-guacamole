import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';

class GoalPlanResult {
  const GoalPlanResult({required this.goal, required this.planSteps});

  final GoalEntity goal;
  final List<String> planSteps;
}

class GenerateGoalPlanUsecase {
  const GenerateGoalPlanUsecase(this._goalRepository, this._taskRepository);

  final IGoalRepository _goalRepository;
  final ITaskRepository _taskRepository;

  Future<GoalPlanResult?> call(String goalId) async {
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

    final List<String> steps = <String>[];

    if (linkedTasks.isEmpty) {
      steps.add('Create the first task for ${selectedGoal.title}.');
    } else {
      steps.addAll(
        linkedTasks
            .where((TaskEntity task) => !task.isCompleted && !task.isCanceled)
            .map((TaskEntity task) => 'Work on: ${task.title}'),
      );
    }

    if (selectedGoal.targetDate == null) {
      steps.add('Set a target date for this goal.');
    }

    steps.add('Review goal progress in the timeline.');

    return GoalPlanResult(goal: selectedGoal, planSteps: steps);
  }
}
