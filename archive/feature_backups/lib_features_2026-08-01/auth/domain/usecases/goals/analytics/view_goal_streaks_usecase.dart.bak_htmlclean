import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';

class GoalStreakResult {
  const GoalStreakResult({
    required this.currentStreak,
    required this.longestStreak,
  });

  final int currentStreak;
  final int longestStreak;
}

class ViewGoalStreaksUsecase {
  const ViewGoalStreaksUsecase(this._repository);

  final IGoalRepository _repository;

  GoalStreakResult call() {
    _repository.getGoals();

    // GoalEntity does not currently store completion dates.
    // Keep this use case wired with a safe baseline.
    return const GoalStreakResult(currentStreak: 0, longestStreak: 0);
  }
}
