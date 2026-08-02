import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';

class GoalCompletionCelebrationResult {
  const GoalCompletionCelebrationResult({
    required this.goal,
    required this.title,
    required this.detail,
    required this.bonusXp,
  });

  final GoalEntity goal;
  final String title;
  final String detail;
  final int bonusXp;
}

class CelebrateGoalCompletionUsecase {
  const CelebrateGoalCompletionUsecase(this._repository);

  final IGoalRepository _repository;

  GoalCompletionCelebrationResult? call({
    required String goalId,
    int bonusXp = 15,
  }) {
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

    return GoalCompletionCelebrationResult(
      goal: selectedGoal,
      title: 'Goal completion celebrated',
      detail: selectedGoal.title,
      bonusXp: bonusXp.clamp(0, 500).toInt(),
    );
  }
}
