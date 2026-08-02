import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_connection_entity.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_timeline_repository.dart';
import 'package:fantastic_guacamole/domain/usecases/add_timeline_event.dart';

class ConnectTimelineToGoalsUsecase {
  const ConnectTimelineToGoalsUsecase(this._repository);

  final ITimelineRepository _repository;

  Future<GoalTimelineLink> call(GoalEntity goal) async {
    final DateTime now = DateTime.now();
    final String eventId = 'goal_link_${goal.id}_${now.microsecondsSinceEpoch}';

    final TimelineEventEntity event = TimelineEventEntity(
      id: eventId,
      type: TimelineEventType.goal,
      title: goal.title.trim().isEmpty ? 'Goal linked' : goal.title.trim(),
      detail: (goal.description ?? 'Goal connected to timeline.').trim(),
      timestamp: now,
      status: TimelineEventStatus.active,
      dueAt: goal.targetDate,
      relatedId: goal.id,
    );

    await AddTimelineEvent(_repository).call(event);

    return GoalTimelineLink(
      id: 'goal_timeline_link_${goal.id}_${now.microsecondsSinceEpoch}',
      timelineEventId: eventId,
      targetId: goal.id,
      createdAt: now,
      label: event.title,
    );
  }
}
