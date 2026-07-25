import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';
import 'package:fantastic_guacamole/domain/usecases/create_goal.dart' as domain;

class CreateSmartGoalUsecase {
  const CreateSmartGoalUsecase(this._repository);

  final IGoalRepository _repository;

  Future<GoalEntity> call({
    required String title,
    String? description,
    DateTime? targetDate,
    DateTime? createdAt,
  }) async {
    final DateTime now = createdAt ?? DateTime.now();

    final GoalEntity goal = GoalEntity(
      id: 'smart_goal_${now.microsecondsSinceEpoch}',
      title: title.trim().isEmpty ? 'SMART goal' : title.trim(),
      createdAt: now,
      description: description?.trim().isEmpty ?? true
          ? 'SMART goal created in ChronoSpark.'
          : description?.trim(),
      targetDate: targetDate,
      colorHex: 0xFF00E5FF,
    );

    await domain.CreateGoal(_repository).call(goal);
    return goal;
  }
}
