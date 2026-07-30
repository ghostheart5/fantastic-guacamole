import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';

class GoalCompletionRateResult {
  const GoalCompletionRateResult({
    required this.completedGoals,
    required this.totalTrackedGoals,
    required this.completionRate,
  });

  final int completedGoals;
  final int totalTrackedGoals;
  final double completionRate;
}

class ViewGoalCompletionRateUsecase {
  const ViewGoalCompletionRateUsecase(this._repository);

  final IGoalRepository _repository;

  GoalCompletionRateResult call() {
    final int total = _repository.getGoals().length;

    // GoalEntity currently removes completed goals rather than storing a
    // completed status. Return a safe baseline until completed goal history
    // is represented in the goal model.
    return GoalCompletionRateResult(
      completedGoals: 0,
      totalTrackedGoals: total,
      completionRate: 0,
    );
  }
}
