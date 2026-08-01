import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';

class ReopenGoal {
  const ReopenGoal(this._repository);

  final IGoalRepository _repository;

  Future<void> call(String id) async {
    GoalEntity? goal;
    for (final GoalEntity item in _repository.getGoals()) {
      if (item.id == id) {
        goal = item;
        break;
      }
    }

    if (goal == null) {
      return;
    }

    await _repository.saveGoal(goal.activate());
  }
}
