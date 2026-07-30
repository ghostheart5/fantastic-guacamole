import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';

class SaveGoals {
  const SaveGoals(this._repository);

  final IGoalRepository _repository;

  Future<void> call(List<GoalEntity> goals) => _repository.saveGoals(goals);
}
