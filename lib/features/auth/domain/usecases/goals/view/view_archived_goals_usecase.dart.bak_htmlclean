import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';

class ViewArchivedGoalsUsecase {
  const ViewArchivedGoalsUsecase(this._repository);

  final IGoalRepository _repository;

  List<GoalEntity> call() {
    final List<GoalEntity> goals = _repository.getGoals();

    // GoalEntity does not currently expose an archived/status field.
    // Keep this use case repository-backed and return an empty archived set
    // until goal archival state is added to the domain model.
    return goals.where((GoalEntity goal) => false).toList(growable: false);
  }
}
