import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';
import 'package:fantastic_guacamole/domain/usecases/create_goal.dart' as domain;

class CreateMonthlyGoalUsecase {
  const CreateMonthlyGoalUsecase(this._repository);

  final IGoalRepository _repository;

  Future<GoalEntity> call({
    required String title,
    String? description,
    DateTime? createdAt,
  }) async {
    final DateTime now = createdAt ?? DateTime.now();
    final DateTime firstOfNextMonth = DateTime(now.year, now.month + 1);
    final DateTime endOfMonth = firstOfNextMonth.subtract(
      const Duration(minutes: 1),
    );

    final GoalEntity goal = GoalEntity(
      id: 'monthly_goal_${now.microsecondsSinceEpoch}',
      title: title.trim().isEmpty ? 'Monthly goal' : title.trim(),
      createdAt: now,
      description: description?.trim().isEmpty ?? true
          ? null
          : description?.trim(),
      targetDate: endOfMonth,
    );

    await domain.CreateGoal(_repository).call(goal);
    return goal;
  }
}
