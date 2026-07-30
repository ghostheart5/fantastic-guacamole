import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';

class GoalSuccessPrediction {
  const GoalSuccessPrediction({
    required this.goal,
    required this.successScore,
    required this.reason,
  });

  final GoalEntity goal;
  final int successScore;
  final String reason;
}

class PredictGoalSuccessUsecase {
  const PredictGoalSuccessUsecase(this._repository);

  final IGoalRepository _repository;

  List<GoalSuccessPrediction> call() {
    final DateTime now = DateTime.now();

    return _repository
        .getGoals()
        .map((GoalEntity goal) {
          final DateTime? targetDate = goal.targetDate;
          int score = 70;
          String reason = 'Goal has a stable baseline.';

          if (targetDate == null) {
            score -= 12;
            reason = 'Goal has no target date.';
          } else if (targetDate.isBefore(now)) {
            score -= 35;
            reason = 'Goal target date has passed.';
          } else if (targetDate.difference(now).inDays <= 7) {
            score -= 8;
            reason = 'Goal is due soon.';
          }

          if ((goal.description ?? '').trim().isNotEmpty) {
            score += 8;
          }

          return GoalSuccessPrediction(
            goal: goal,
            successScore: score.clamp(0, 100),
            reason: reason,
          );
        })
        .toList(growable: false);
  }
}
