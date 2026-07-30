import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';
import 'package:fantastic_guacamole/domain/usecases/create_goal.dart' as domain;

class CreateMicroGoalUsecase {
  const CreateMicroGoalUsecase(this._repository);

  final IGoalRepository _repository;

  Future<GoalEntity> call({
    required String title,
    String? description,
    DateTime? createdAt,
  }) async {
    final DateTime now = createdAt ?? DateTime.now();

    final GoalEntity goal = GoalEntity(
      id: 'micro_goal_${now.microsecondsSinceEpoch}',
      title: title.trim().isEmpty ? 'Micro goal' : title.trim(),
      createdAt: now,
      description: description?.trim().isEmpty ?? true
          ? 'Small next-step goal created in ChronoSpark.'
          : description?.trim(),
      targetDate: now.add(const Duration(days: 1)),
      colorHex: 0xFF9B8AFB,
    );

    await domain.CreateGoal(_repository).call(goal);
    return goal;
  }
}
