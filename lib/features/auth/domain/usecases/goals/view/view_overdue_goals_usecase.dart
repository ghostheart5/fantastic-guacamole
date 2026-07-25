import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';

class ViewOverdueGoalsUsecase {
  const ViewOverdueGoalsUsecase(this._repository);

  final IGoalRepository _repository;

  List<GoalEntity> call() {
    final DateTime now = DateTime.now();

    return _repository
        .getGoals()
        .where((GoalEntity goal) {
          final DateTime? targetDate = goal.targetDate;
          return targetDate != null && targetDate.isBefore(now);
        })
        .toList(growable: false);
  }
}
