import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';
import 'package:fantastic_guacamole/domain/usecases/update_goal.dart' as domain;

class UpdateGoalUsecase {
  const UpdateGoalUsecase(this._repository);

  final IGoalRepository _repository;

  Future<void> call(GoalEntity goal) {
    return domain.UpdateGoal(_repository).call(goal);
  }
}
