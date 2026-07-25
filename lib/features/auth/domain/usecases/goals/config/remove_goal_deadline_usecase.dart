import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';

class RemoveGoalDeadlineUsecase {
  const RemoveGoalDeadlineUsecase(this._repository);

  final IGoalRepository _repository;

  Future<GoalEntity?> call(String goalId) async {
    final String targetId = goalId.trim();
    if (targetId.isEmpty) {
      return null;
    }

    GoalEntity? selectedGoal;
    for (final GoalEntity goal in _repository.getGoals()) {
      if (goal.id == targetId) {
        selectedGoal = goal;
        break;
      }
    }

    if (selectedGoal == null) {
      return null;
    }

    final GoalEntity updated = GoalEntity(
      id: selectedGoal.id,
      title: selectedGoal.title,
      createdAt: selectedGoal.createdAt,
      description: selectedGoal.description,
      targetDate: null,
      colorHex: selectedGoal.colorHex,
    );

    await _repository.saveGoal(updated);
    return updated;
  }
}
