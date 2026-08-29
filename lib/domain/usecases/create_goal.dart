import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/errors/domain_validation_exception.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';

/// CHRONOSPARK-CLASS: SHIPPING | Feature: Goals/tasks
///
/// Resolved by GoalsNotifier.add.
class CreateGoal {
  const CreateGoal(this._repository);

  final IGoalRepository _repository;

  Future<void> call(GoalEntity goal) async {
    try {
      goal.validate();
    } on StateError catch (error) {
      throw DomainValidationException(
        code: 'invalid_goal',
        message: error.message.toString(),
      );
    }
    await _repository.saveGoal(goal);
  }
}
