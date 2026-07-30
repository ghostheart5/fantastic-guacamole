import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';
import 'package:fantastic_guacamole/domain/usecases/create_goal.dart' as domain;

class DuplicateGoalUsecase {
  const DuplicateGoalUsecase(this._repository);

  final IGoalRepository _repository;

  Future<GoalEntity?> call(String id) async {
    final String targetId = id.trim();
    if (targetId.isEmpty) {
      return null;
    }

    GoalEntity? source;
    for (final GoalEntity goal in _repository.getGoals()) {
      if (goal.id == targetId) {
        source = goal;
        break;
      }
    }

    if (source == null) {
      return null;
    }

    final DateTime now = DateTime.now();
    final GoalEntity duplicate = GoalEntity(
      id: 'goal_duplicate_${now.microsecondsSinceEpoch}',
      title: '${source.title} Copy',
      createdAt: now,
      description: source.description,
      targetDate: source.targetDate,
      colorHex: source.colorHex,
    );

    await domain.CreateGoal(_repository).call(duplicate);
    return duplicate;
  }
}
