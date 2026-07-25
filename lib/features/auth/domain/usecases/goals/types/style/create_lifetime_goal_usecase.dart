import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';
import 'package:fantastic_guacamole/domain/usecases/create_goal.dart' as domain;

class CreateLifetimeGoalUsecase {
  const CreateLifetimeGoalUsecase(this._repository);

  final IGoalRepository _repository;

  Future<GoalEntity> call({
    required String title,
    String? description,
    DateTime? createdAt,
  }) async {
    final DateTime now = createdAt ?? DateTime.now();

    final GoalEntity goal = GoalEntity(
      id: 'lifetime_goal_${now.microsecondsSinceEpoch}',
      title: title.trim().isEmpty ? 'Lifetime goal' : title.trim(),
      createdAt: now,
      description: description?.trim().isEmpty ?? true
          ? 'Long-term lifetime goal created in ChronoSpark.'
          : description?.trim(),
      targetDate: null,
      colorHex: 0xFFFF4FD8,
    );

    await domain.CreateGoal(_repository).call(goal);
    return goal;
  }
}
