import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';

/// CHRONOSPARK-CLASS: SHIPPING | Feature: Goals/tasks
///
/// Resolved by goalsProvider -> Goals UI.
class GetGoals {
  const GetGoals(this._repository);

  final IGoalRepository _repository;

  List<GoalEntity> call() => _repository.getGoals();
}
