import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';

abstract class IGoalRepository {
  List<GoalEntity> getGoals();
  Future<void> saveGoal(GoalEntity goal);
  Future<void> saveGoals(List<GoalEntity> goals);
  Future<void> deleteGoal(String id);
}
