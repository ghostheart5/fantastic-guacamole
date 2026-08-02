import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';

class GoalTrendsResult {
  const GoalTrendsResult({
    required this.createdLast7Days,
    required this.createdLast30Days,
    required this.createdLast365Days,
  });

  final int createdLast7Days;
  final int createdLast30Days;
  final int createdLast365Days;
}

class ViewGoalTrendsUsecase {
  const ViewGoalTrendsUsecase(this._repository);

  final IGoalRepository _repository;

  GoalTrendsResult call() {
    final DateTime now = DateTime.now();
    final List<GoalEntity> goals = _repository.getGoals();

    int createdWithin(int days) {
      return goals
          .where(
            (GoalEntity goal) => now.difference(goal.createdAt).inDays <= days,
          )
          .length;
    }

    return GoalTrendsResult(
      createdLast7Days: createdWithin(7),
      createdLast30Days: createdWithin(30),
      createdLast365Days: createdWithin(365),
    );
  }
}
