// CHRONOSPARK-CLASS: SHIPPING | Feature: Goal evidence availability
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';

/// Optional repository capability; preserves compatibility with other stores.
abstract interface class GoalReadHealth {
  bool get lastReadCorrupted;
}

class GoalReadUnavailable implements Exception {
  const GoalReadUnavailable();
  @override
  String toString() =>
      'Stored goals are unavailable; existing data was preserved.';
}

List<GoalEntity> readAvailableGoals(IGoalRepository repository) {
  final goals = repository.getGoals();
  if (repository is GoalReadHealth &&
      (repository as GoalReadHealth).lastReadCorrupted) {
    throw const GoalReadUnavailable();
  }
  return goals;
}
