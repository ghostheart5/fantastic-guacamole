import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';

class ViewArchivedGoalsUsecase {
  const ViewArchivedGoalsUsecase(this._repository);

  final IGoalRepository _repository;

  List<GoalEntity> call() {
    return _repository
        .getGoals()
        .where((GoalEntity goal) => goal.isArchived)
        .toList(growable: false);
  }
}
