import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';

class GoalSummaryResult {
  const GoalSummaryResult({
    required this.totalGoals,
    required this.withTargetDate,
    required this.overdueGoals,
    required this.dueSoonGoals,
    required this.summary,
  });

  final int totalGoals;
  final int withTargetDate;
  final int overdueGoals;
  final int dueSoonGoals;
  final String summary;
}

class GenerateGoalSummaryUsecase {
  const GenerateGoalSummaryUsecase(this._repository);

  final IGoalRepository _repository;

  GoalSummaryResult call() {
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

    final String summary = goals.isEmpty
        ? 'No goals are currently active.'
        : '$withTarget of ${goals.length} goal(s) have target dates.';

    return GoalSummaryResult(
      totalGoals: goals.length,
      withTargetDate: withTarget,
      overdueGoals: overdue,
      dueSoonGoals: dueSoon,
      summary: summary,
    );
  }
}
