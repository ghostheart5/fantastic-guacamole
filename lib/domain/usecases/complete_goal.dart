import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';

class CompleteGoal {
  const CompleteGoal(this._repository);

  final IGoalRepository _repository;

  Future<void> call(String id) => _repository.deleteGoal(id);
}
