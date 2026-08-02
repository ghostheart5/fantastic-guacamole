import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';

class GoalPriorityConfig {
  const GoalPriorityConfig({
    required this.goal,
    required this.priority,
    required this.updatedAt,
  });

  final GoalEntity goal;
  final int priority;
  final DateTime updatedAt;
}

class SetGoalPriorityUsecase {
  const SetGoalPriorityUsecase(this._repository);

  final IGoalRepository _repository;

  GoalPriorityConfig? call({required String goalId, required int priority}) {
    final String targetId = goalId.trim();
    if (targetId.isEmpty) {
      return null;
    }

    GoalEntity? selectedGoal;
    for (final GoalEntity goal in _repository.getGoals()) {
      if (goal.id == targetId) {
        selectedGoal = goal;
        break;
      }
    }

    if (selectedGoal == null) {
      return null;
    }

    return GoalPriorityConfig(
      goal: selectedGoal,
      priority: priority.clamp(1, 5).toInt(),
      updatedAt: DateTime.now(),
    );
  }
}
