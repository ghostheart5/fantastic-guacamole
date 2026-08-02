import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';
import 'package:fantastic_guacamole/domain/usecases/create_goal.dart' as domain;

class CreateGoalUsecase {
  const CreateGoalUsecase(this._repository);

  final IGoalRepository _repository;

  Future<void> call(GoalEntity goal) {
    return domain.CreateGoal(_repository).call(goal);
  }
}
