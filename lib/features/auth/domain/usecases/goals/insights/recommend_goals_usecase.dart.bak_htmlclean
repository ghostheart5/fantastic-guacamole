import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';

class RecommendGoalsUsecase {
  const RecommendGoalsUsecase(this._repository);

  final IGoalRepository _repository;

  List<String> call() {
    final List<GoalEntity> goals = _repository.getGoals();

    if (goals.isEmpty) {
      return const <String>[
        'Create one small goal for today.',
        'Create one weekly goal with a clear target date.',
      ];
    }

    final bool hasTargetDate = goals.any((GoalEntity goal) {
      return goal.targetDate != null;
    });

    if (!hasTargetDate) {
      return const <String>[
        'Add target dates to existing goals.',
        'Break the most important goal into tasks.',
      ];
    }

    return const <String>[
      'Review upcoming goal deadlines.',
      'Choose one next action for the highest priority goal.',
    ];
  }
}
