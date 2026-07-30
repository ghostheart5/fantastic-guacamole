import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';

class GenerateGoalRecommendationsUsecase {
  const GenerateGoalRecommendationsUsecase(this._repository);

  final IGoalRepository _repository;

  List<String> call() {
    final DateTime now = DateTime.now();
    final List<GoalEntity> goals = _repository.getGoals();

    final List<String> recommendations = <String>[];

    for (final GoalEntity goal in goals) {
      final DateTime? targetDate = goal.targetDate;

      if (targetDate == null) {
        recommendations.add('Add a target date to "${goal.title}".');
      } else if (targetDate.isBefore(now)) {
        recommendations.add('Re-plan overdue goal "${goal.title}".');
      } else if (targetDate.difference(now).inDays <= 7) {
        recommendations.add('Prioritize "${goal.title}" this week.');
      }
    }

    if (recommendations.isEmpty) {
      recommendations.add('Keep current goal momentum and review weekly.');
    }

    return recommendations;
  }
}
