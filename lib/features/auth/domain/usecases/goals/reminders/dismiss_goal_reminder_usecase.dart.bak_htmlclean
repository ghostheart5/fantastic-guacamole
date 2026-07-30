import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_timeline_repository.dart';

class DismissGoalReminderUsecase {
  const DismissGoalReminderUsecase(
    this._goalRepository,
    this._timelineRepository,
  );

  final IGoalRepository _goalRepository;
  final ITimelineRepository _timelineRepository;

  Future<TimelineEventEntity?> call(String goalId) async {
    final String targetId = goalId.trim();
    if (targetId.isEmpty) {
      return null;
    }

    GoalEntity? goal;
    for (final GoalEntity item in _goalRepository.getGoals()) {
      if (item.id == targetId) {
        goal = item;
        break;
      }
    }

    if (goal == null) {
      return null;
    }

    final DateTime now = DateTime.now();

    final TimelineEventEntity event = TimelineEventEntity(
      id: 'goal_reminder_dismissed_${now.microsecondsSinceEpoch}',
      type: TimelineEventType.deadline,
      title: 'Goal reminder dismissed',
      detail: goal.title,
      timestamp: now,
      status: TimelineEventStatus.info,
      phase: 'reminder.dismissed',
      relatedId: goal.id,
    );

    await _timelineRepository.addEvent(event);

    return event;
  }
}
