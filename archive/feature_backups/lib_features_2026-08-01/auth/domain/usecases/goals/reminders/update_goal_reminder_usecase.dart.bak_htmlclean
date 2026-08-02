import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';
import 'package:fantastic_guacamole/state/services/reminder_orchestrator_service.dart';

class UpdateGoalReminderUsecase {
  const UpdateGoalReminderUsecase(this._repository, this._reminders);

  final IGoalRepository _repository;
  final ReminderOrchestratorService _reminders;

  Future<GoalEntity?> call({
    required String goalId,
    required DateTime targetDate,
  }) async {
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
      targetDate: targetDate,
      colorHex: selectedGoal.colorHex,
    );

    await _repository.saveGoal(updated);
    await _reminders.syncGoalReminders(_repository.getGoals());

    return updated;
  }
}
