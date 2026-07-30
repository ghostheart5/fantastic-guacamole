import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';

class GoalConflictResult {
  const GoalConflictResult({
    required this.first,
    required this.second,
    required this.reason,
  });

  final GoalEntity first;
  final GoalEntity second;
  final String reason;
}

class DetectGoalConflictsUsecase {
  const DetectGoalConflictsUsecase(this._repository);

  final IGoalRepository _repository;

  List<GoalConflictResult> call() {
    final List<GoalEntity> goals = _repository.getGoals();
    final List<GoalConflictResult> conflicts = <GoalConflictResult>[];

    for (int i = 0; i < goals.length; i++) {
      for (int j = i + 1; j < goals.length; j++) {
        final GoalEntity first = goals[i];
        final GoalEntity second = goals[j];

        final DateTime? firstTarget = first.targetDate;
        final DateTime? secondTarget = second.targetDate;

        if (firstTarget == null || secondTarget == null) {
          continue;
        }

        final bool sameDay =
            firstTarget.year == secondTarget.year &&
            firstTarget.month == secondTarget.month &&
            firstTarget.day == secondTarget.day;

        if (sameDay) {
          conflicts.add(
            GoalConflictResult(
              first: first,
              second: second,
              reason: 'Multiple goals share the same target date.',
            ),
          );
        }
      }
    }

    return conflicts;
  }
}
