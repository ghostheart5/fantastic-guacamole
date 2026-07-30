import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';

enum GoalSortMode {
  createdNewest,
  createdOldest,
  titleAsc,
  titleDesc,
  targetDateSoonest,
  targetDateLatest,
}

class SortGoalsUsecase {
  const SortGoalsUsecase(this._repository);

  final IGoalRepository _repository;

  List<GoalEntity> call({GoalSortMode mode = GoalSortMode.createdNewest}) {
    final List<GoalEntity> goals = <GoalEntity>[..._repository.getGoals()];

    goals.sort((GoalEntity a, GoalEntity b) {
      return switch (mode) {
        GoalSortMode.createdNewest => b.createdAt.compareTo(a.createdAt),
        GoalSortMode.createdOldest => a.createdAt.compareTo(b.createdAt),
        GoalSortMode.titleAsc => a.title.toLowerCase().compareTo(
          b.title.toLowerCase(),
        ),
        GoalSortMode.titleDesc => b.title.toLowerCase().compareTo(
          a.title.toLowerCase(),
        ),
        GoalSortMode.targetDateSoonest => _compareNullableDates(
          a.targetDate,
          b.targetDate,
          nullsLast: true,
        ),
        GoalSortMode.targetDateLatest => _compareNullableDates(
          b.targetDate,
          a.targetDate,
          nullsLast: true,
        ),
      };
    });

    return goals;
  }

  static int _compareNullableDates(
    DateTime? left,
    DateTime? right, {
    required bool nullsLast,
  }) {
    if (left == null && right == null) {
      return 0;
    }
    if (left == null) {
      return nullsLast ? 1 : -1;
    }
    if (right == null) {
      return nullsLast ? -1 : 1;
    }
    return left.compareTo(right);
  }
}
