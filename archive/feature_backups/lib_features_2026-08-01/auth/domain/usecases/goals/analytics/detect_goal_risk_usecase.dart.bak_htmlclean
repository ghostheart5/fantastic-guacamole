import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';

class GoalRiskResult {
  const GoalRiskResult({
    required this.overdueGoals,
    required this.dueSoonGoals,
    required this.goalsWithoutTargetDate,
    required this.riskScore,
  });

  final List<GoalEntity> overdueGoals;
  final List<GoalEntity> dueSoonGoals;
  final List<GoalEntity> goalsWithoutTargetDate;
  final int riskScore;

  bool get hasRisk => riskScore > 0;
}

class DetectGoalRiskUsecase {
  const DetectGoalRiskUsecase(this._repository);

  final IGoalRepository _repository;

  GoalRiskResult call() {
    final DateTime now = DateTime.now();
    final List<GoalEntity> goals = _repository.getGoals();

    final List<GoalEntity> overdue = goals
        .where((GoalEntity goal) {
          final DateTime? targetDate = goal.targetDate;
          return targetDate != null && targetDate.isBefore(now);
        })
        .toList(growable: false);

    final List<GoalEntity> dueSoon = goals
        .where((GoalEntity goal) {
          final DateTime? targetDate = goal.targetDate;
          if (targetDate == null || targetDate.isBefore(now)) {
            return false;
          }
          return targetDate.difference(now).inDays <= 7;
        })
        .toList(growable: false);

    final List<GoalEntity> withoutTarget = goals
        .where((GoalEntity goal) => goal.targetDate == null)
        .toList(growable: false);

    final int score =
        ((overdue.length * 15) + (dueSoon.length * 6) + withoutTarget.length)
            .clamp(0, 100);

    return GoalRiskResult(
      overdueGoals: overdue,
      dueSoonGoals: dueSoon,
      goalsWithoutTargetDate: withoutTarget,
      riskScore: score,
    );
  }
}
