import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_timeline_repository.dart';

class StartGoalUsecase {
  const StartGoalUsecase(this._goalRepository, this._timelineRepository);

  final IGoalRepository _goalRepository;
  final ITimelineRepository _timelineRepository;

  Future<TimelineEventEntity?> call(String goalId) async {
    GoalEntity? goal;

    for (final GoalEntity item in _goalRepository.getGoals()) {
      if (item.id == goalId.trim()) {
        goal = item;
        break;
      }
    }

    if (goal == null) {
      return null;
    }

    final DateTime now = DateTime.now();

    final TimelineEventEntity event = TimelineEventEntity(
      id: 'goal_start_${now.microsecondsSinceEpoch}',
      type: TimelineEventType.goal,
      title: goal.title,
      detail: 'Goal started.',
      timestamp: now,
      status: TimelineEventStatus.active,
      phase: 'lifecycle.start',
      relatedId: goal.id,
    );

    await _timelineRepository.addEvent(event);

    return event;
  }
}
