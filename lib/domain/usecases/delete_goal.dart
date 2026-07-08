import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';

class DeleteGoal {
  const DeleteGoal(this._repository);

  final IGoalRepository _repository;

  Future<void> call(String id) => _repository.deleteGoal(id);
}
