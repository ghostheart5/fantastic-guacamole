import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';

class GoalAchievementRewardResult {
  const GoalAchievementRewardResult({
    required this.goal,
    required this.title,
    required this.detail,
    required this.xp,
  });

  final GoalEntity goal;
  final String title;
  final String detail;
  final int xp;
}

class AwardGoalAchievementUsecase {
  const AwardGoalAchievementUsecase(this._repository);

  final IGoalRepository _repository;

  GoalAchievementRewardResult? call({
    required String goalId,
    int xp = 25,
    String? title,
    String? detail,
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

    return GoalAchievementRewardResult(
      goal: selectedGoal,
      title: title?.trim().isEmpty ?? true
          ? 'Goal achievement unlocked'
          : title!.trim(),
      detail: detail?.trim().isEmpty ?? true
          ? selectedGoal.title
          : detail!.trim(),
      xp: xp.clamp(0, 500).toInt(),
    );
  }
}
