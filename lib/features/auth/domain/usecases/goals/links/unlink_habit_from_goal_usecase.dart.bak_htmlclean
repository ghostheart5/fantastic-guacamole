import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_timeline_repository.dart';

class UnlinkHabitFromGoalUsecase {
  const UnlinkHabitFromGoalUsecase(
    this._goalRepository,
    this._timelineRepository,
  );

  final IGoalRepository _goalRepository;
  final ITimelineRepository _timelineRepository;

  Future<TimelineEventEntity?> call({
    required String goalId,
    required String habitId,
  }) async {
    final String targetGoalId = goalId.trim();
    final String targetItemId = habitId.trim();

    if (targetGoalId.isEmpty || targetItemId.isEmpty) {
      return null;
    }

    GoalEntity? goal;
    for (final GoalEntity item in _goalRepository.getGoals()) {
      if (item.id == targetGoalId) {
        goal = item;
        break;
      }
    }

    if (goal == null) {
      return null;
    }

    final DateTime now = DateTime.now();

    final TimelineEventEntity event = TimelineEventEntity(
      id: 'goal.unlink.habit${targetGoalId}_${targetItemId}_${now.microsecondsSinceEpoch}',
      type: TimelineEventType.habit,
      title: 'Habit unlinked from goal',
      detail: 'Habit unlinked $targetItemId for goal "${goal.title}".',
      timestamp: now,
      status: TimelineEventStatus.info,
      phase: 'goal.unlink.habit',
      relatedId: targetGoalId,
    );

    await _timelineRepository.addEvent(event);

    return event;
  }
}
