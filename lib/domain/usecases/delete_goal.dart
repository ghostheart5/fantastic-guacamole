import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';
import 'package:fantastic_guacamole/domain/policies/input_guard.dart';

/// CHRONOSPARK-CLASS: PLANNED | Feature: Goals/tasks
///
/// Registered as deleteGoalUseCaseProvider. The only destructive goal path; UI
/// currently completes instead.
/// The only destructive goal path. Use `CompleteGoal` to mark a goal done.
class DeleteGoal {
  const DeleteGoal(this._repository);

  final IGoalRepository _repository;

  Future<void> call(String id) =>
      _repository.deleteGoal(InputGuard.id(id, 'id'));
}
