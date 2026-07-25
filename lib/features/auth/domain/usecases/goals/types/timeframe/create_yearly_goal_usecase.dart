import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';
import 'package:fantastic_guacamole/domain/usecases/create_goal.dart' as domain;

class CreateYearlyGoalUsecase {
  const CreateYearlyGoalUsecase(this._repository);

  final IGoalRepository _repository;

  Future<GoalEntity> call({
    required String title,
    String? description,
    DateTime? createdAt,
  }) async {
    final DateTime now = createdAt ?? DateTime.now();
    final DateTime endOfYear = DateTime(now.year, 12, 31, 23, 59);

    final GoalEntity goal = GoalEntity(
      id: 'yearly_goal_${now.microsecondsSinceEpoch}',
      title: title.trim().isEmpty ? 'Yearly goal' : title.trim(),
      createdAt: now,
      description: description?.trim().isEmpty ?? true
          ? null
          : description?.trim(),
      targetDate: endOfYear,
    );

    await domain.CreateGoal(_repository).call(goal);
    return goal;
  }
}
