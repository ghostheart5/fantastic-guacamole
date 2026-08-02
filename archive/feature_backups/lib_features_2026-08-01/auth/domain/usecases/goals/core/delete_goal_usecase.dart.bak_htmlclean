import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';
import 'package:fantastic_guacamole/domain/usecases/delete_goal.dart' as domain;

class DeleteGoalUsecase {
  const DeleteGoalUsecase(this._repository);

  final IGoalRepository _repository;

  Future<void> call(String id) {
    return domain.DeleteGoal(_repository).call(id);
  }
}
