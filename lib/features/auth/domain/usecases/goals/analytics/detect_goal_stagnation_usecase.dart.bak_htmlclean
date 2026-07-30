import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';

class GoalStagnationResult {
  const GoalStagnationResult({
    required this.stagnantGoals,
    required this.stagnationScore,
  });

  final List<GoalEntity> stagnantGoals;
  final int stagnationScore;

  bool get hasStagnation => stagnantGoals.isNotEmpty;
}

class DetectGoalStagnationUsecase {
  const DetectGoalStagnationUsecase(this._repository);

  final IGoalRepository _repository;

  GoalStagnationResult call({int staleAfterDays = 30}) {
    final DateTime now = DateTime.now();

    final List<GoalEntity> stagnant = _repository
        .getGoals()
        .where((GoalEntity goal) {
          final bool oldGoal =
              now.difference(goal.createdAt).inDays >= staleAfterDays;
          return oldGoal && goal.targetDate == null;
        })
        .toList(growable: false);

    final int score = (stagnant.length * 10).clamp(0, 100);

    return GoalStagnationResult(
      stagnantGoals: stagnant,
      stagnationScore: score,
    );
  }
}
