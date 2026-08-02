import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';

class SearchGoalsUsecase {
  const SearchGoalsUsecase(this._repository);

  final IGoalRepository _repository;

  List<GoalEntity> call(String query) {
    final String target = query.trim().toLowerCase();
    if (target.isEmpty) {
      return _repository.getGoals();
    }

    return _repository
        .getGoals()
        .where(
          (GoalEntity goal) =>
              goal.title.toLowerCase().contains(target) ||
              (goal.description ?? '').toLowerCase().contains(target),
        )
        .toList(growable: false);
  }
}
