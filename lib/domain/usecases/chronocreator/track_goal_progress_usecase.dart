import '../../entities/goal_entity.dart';

class TrackGoalProgressUseCase {
  GoalEntity call(GoalEntity goal, double delta) {
    final double next = (goal.progress + delta).clamp(0, 1);
    return GoalEntity(
      id: goal.id,
      title: goal.title,
      progress: next,
      dueDate: goal.dueDate,
    );
  }
}
