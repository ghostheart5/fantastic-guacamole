import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';

class GenerateGoalInsightsUsecase {
  const GenerateGoalInsightsUsecase(this._repository);

  final IGoalRepository _repository;

  List<String> call() {
    final DateTime now = DateTime.now();
    final List<GoalEntity> goals = _repository.getGoals();

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

    final int withoutTarget = goals
        .where((GoalEntity goal) => goal.targetDate == null)
        .length;

    final List<String> insights = <String>[];

    if (goals.isEmpty) {
      insights.add('No goals are currently active.');
    }
    if (overdue > 0) {
      insights.add('$overdue goal(s) are past their target date.');
    }
    if (dueSoon > 0) {
      insights.add('$dueSoon goal(s) are due soon.');
    }
    if (withoutTarget > 0) {
      insights.add('$withoutTarget goal(s) do not have a target date.');
    }
    if (insights.isEmpty) {
      insights.add('Goals are currently structured and stable.');
    }

    return insights;
  }
}
