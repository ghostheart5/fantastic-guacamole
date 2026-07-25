import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_timeline_repository.dart';

class ReopenGoalUsecase {
  const ReopenGoalUsecase(this._goalRepository, this._timelineRepository);

  final IGoalRepository _goalRepository;
  final ITimelineRepository _timelineRepository;

  Future<TimelineEventEntity?> call(String goalId) async {
    final exists = _goalRepository.getGoals().any((g) => g.id == goalId.trim());

    if (!exists) {
      return null;
    }

    final DateTime now = DateTime.now();

    final TimelineEventEntity event = TimelineEventEntity(
      id: 'goal_reopen_${now.microsecondsSinceEpoch}',
      type: TimelineEventType.goal,
      title: 'Goal reopened',
      detail: 'Goal reopened.',
      timestamp: now,
      status: TimelineEventStatus.active,
      phase: 'lifecycle.reopen',
      relatedId: goalId.trim(),
    );

    await _timelineRepository.addEvent(event);

    return event;
  }
}
