import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';

class RestoreGoalsUsecase {
  const RestoreGoalsUsecase(this._repository);

  final IGoalRepository _repository;

  Future<List<GoalEntity>> call(List<GoalEntity> goals) async {
    await _repository.saveGoals(goals);
    return goals;
  }
}
