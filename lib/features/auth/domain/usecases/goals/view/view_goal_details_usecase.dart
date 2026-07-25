import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';

class ViewGoalDetailsUsecase {
  const ViewGoalDetailsUsecase(this._repository);

  final IGoalRepository _repository;

  GoalEntity? call(String id) {
    final String targetId = id.trim();
    if (targetId.isEmpty) {
      return null;
    }

    for (final GoalEntity goal in _repository.getGoals()) {
      if (goal.id == targetId) {
        return goal;
      }
    }

    return null;
  }
}
