import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';

class FilterGoalsUsecase {
  const FilterGoalsUsecase(this._repository);

  final IGoalRepository _repository;

  List<GoalEntity> call({
    bool overdueOnly = false,
    bool withTargetDateOnly = false,
  }) {
    final DateTime now = DateTime.now();

    return _repository
        .getGoals()
        .where((GoalEntity goal) {
          final DateTime? targetDate = goal.targetDate;

          if (withTargetDateOnly && targetDate == null) {
            return false;
          }

          if (overdueOnly) {
            return targetDate != null && targetDate.isBefore(now);
          }

          return true;
        })
        .toList(growable: false);
  }
}
