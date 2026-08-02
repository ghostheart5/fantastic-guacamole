import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';
import 'package:fantastic_guacamole/domain/usecases/create_goal.dart' as domain;

class CreateWeeklyGoalUsecase {
  const CreateWeeklyGoalUsecase(this._repository);

  final IGoalRepository _repository;

  Future<GoalEntity> call({
    required String title,
    String? description,
    DateTime? createdAt,
  }) async {
    final DateTime now = createdAt ?? DateTime.now();
    final int daysUntilSunday = DateTime.sunday - now.weekday;
    final DateTime endOfWeek = DateTime(
      now.year,
      now.month,
      now.day,
      23,
      59,
    ).add(Duration(days: daysUntilSunday));

    final GoalEntity goal = GoalEntity(
      id: 'weekly_goal_${now.microsecondsSinceEpoch}',
      title: title.trim().isEmpty ? 'Weekly goal' : title.trim(),
      createdAt: now,
      description: description?.trim().isEmpty ?? true
          ? null
          : description?.trim(),
      targetDate: endOfWeek,
    );

    await domain.CreateGoal(_repository).call(goal);
    return goal;
  }
}
