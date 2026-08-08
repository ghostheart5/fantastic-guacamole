import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';
import 'package:fantastic_guacamole/domain/policies/input_guard.dart';

/// CHRONOSPARK-CLASS: PLANNED | Feature: Goals/tasks
///
/// Registered as saveGoalsUseCaseProvider; bulk goal replace for
/// import/restore. Empty-batch guarded.
/// Replaces the whole stored goal collection. Pass `allowClear: true` to clear
/// it deliberately; an empty list is otherwise rejected as an accident.
class SaveGoals {
  const SaveGoals(this._repository);

  final IGoalRepository _repository;

  Future<void> call(List<GoalEntity> goals, {bool allowClear = false}) =>
      _repository.saveGoals(
        InputGuard.batch(goals, 'goals', allowClear: allowClear),
      );
}
