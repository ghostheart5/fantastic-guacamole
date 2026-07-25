import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_timeline_repository.dart';

class UnfavoriteGoalUsecase {
  const UnfavoriteGoalUsecase(this._goalRepository, this._timelineRepository);

  final IGoalRepository _goalRepository;
  final ITimelineRepository _timelineRepository;

  Future<TimelineEventEntity?> call(String goalId) async {
    final String targetGoalId = goalId.trim();
    if (targetGoalId.isEmpty) {
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
      id: 'goal_unfavorite_${goal.id}_${now.microsecondsSinceEpoch}',
      type: TimelineEventType.reflection,
      title: 'Goal unfavorited',
      detail: 'Unfavorited goal "${goal.title}".',
      timestamp: now,
      status: TimelineEventStatus.info,
      phase: 'goal.metadata.unfavorite',
      relatedId: goal.id,
    );

    await _timelineRepository.addEvent(event);
    return event;
  }
}
