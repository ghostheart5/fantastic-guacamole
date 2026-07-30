import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';

class ViewCompletedGoalsUsecase {
  const ViewCompletedGoalsUsecase(this._repository);

  final IGoalRepository _repository;

  List<GoalEntity> call() {
    final List<GoalEntity> goals = _repository.getGoals();

    // GoalEntity does not currently expose a completed/status field.
    // Keep this use case repository-backed and return an empty completed set
    // until goal completion state is added to the domain model.
    return goals.where((GoalEntity goal) => false).toList(growable: false);
  }
}
