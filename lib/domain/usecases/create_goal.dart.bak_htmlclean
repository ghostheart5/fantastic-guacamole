import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';

class CreateGoal {
  const CreateGoal(this._repository);

  final IGoalRepository _repository;

  Future<void> call(GoalEntity goal) => _repository.saveGoal(goal);
}
