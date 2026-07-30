import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';

class GoalAnalyticsResult {
  const GoalAnalyticsResult({
    required this.totalGoals,
    required this.goalsWithTargetDate,
    required this.overdueGoals,
    required this.dueSoonGoals,
    required this.goalsWithoutTargetDate,
  });

  final int totalGoals;
  final int goalsWithTargetDate;
  final int overdueGoals;
  final int dueSoonGoals;
  final int goalsWithoutTargetDate;
}

class ViewGoalAnalyticsUsecase {
  const ViewGoalAnalyticsUsecase(this._repository);

  final IGoalRepository _repository;

  GoalAnalyticsResult call() {
    final DateTime now = DateTime.now();
    final List<GoalEntity> goals = _repository.getGoals();

    final int withTarget = goals
        .where((GoalEntity goal) => goal.targetDate != null)
        .length;

    final int overdue = goals.where((GoalEntity goal) {
      final DateTime? targetDate = goal.targetDate;
      return targetDate != null && targetDate.isBefore(now);
    }).length;

    final int dueSoon = goals.where((GoalEntity goal) {
      final DateTime? targetDate = goal.targetDate;
      if (targetDate == null || targetDate.isBefore(now)) {
        return false;
      }
      return targetDate.difference(now).inDays <= 7;
    }).length;

    return GoalAnalyticsResult(
      totalGoals: goals.length,
      goalsWithTargetDate: withTarget,
      overdueGoals: overdue,
      dueSoonGoals: dueSoon,
      goalsWithoutTargetDate: goals.length - withTarget,
    );
  }
}
