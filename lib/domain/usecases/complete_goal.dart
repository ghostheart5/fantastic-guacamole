import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';

/// CHRONOSPARK-CLASS: SHIPPING | Feature: Goals/tasks
///
/// Resolved by GoalsNotifier.complete. Marks complete; never deletes.
/// Marks a goal complete. This is NOT a delete.
///
/// This use case previously delegated straight to `deleteGoal`, which
/// irreversibly destroyed the goal and all completion history. `DeleteGoal`
/// remains the only destructive path.
class CompleteGoal {
  const CompleteGoal(this._repository);

  final IGoalRepository _repository;

  Future<void> call(String id, {DateTime? completedAt}) async {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'Goal id must not be blank');
    }

    GoalEntity? target;
    for (final GoalEntity goal in _repository.getGoals()) {
      if (goal.id == id) {
        target = goal;
        break;
      }
    }
    if (target == null) {
      throw StateError('Goal not found');
    }
    if (target.isCompleted) {
      return;
    }

    await _repository.saveGoal(
      target.markCompleted(completedAt ?? DateTime.now()),
    );
  }
}
