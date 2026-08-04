import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';

/// CHRONOSPARK-CLASS: SHIPPING | Feature: Goals/tasks
///
/// Bound to GoalRepository.
abstract class IGoalRepository {
  List<GoalEntity> getGoals();
  Future<void> saveGoal(GoalEntity goal);
  Future<void> saveGoals(List<GoalEntity> goals);
  Future<void> deleteGoal(String id);
}
