import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_timeline_repository.dart';

class ReopenMilestoneUsecase {
  const ReopenMilestoneUsecase(this._timelineRepository);

  final ITimelineRepository _timelineRepository;

  Future<TimelineEventEntity?> call(String milestoneId) async {
    final String targetId = milestoneId.trim();
    if (targetId.isEmpty) {
      return null;
    }

    final List<TimelineEventEntity> events = _timelineRepository.getEvents();
    TimelineEventEntity? reopened;

    final List<TimelineEventEntity> next = events
        .map((TimelineEventEntity event) {
          if (event.id != targetId) {
            return event;
          }

          reopened = TimelineEventEntity(
            id: event.id,
            type: event.type,
            title: event.title,
            detail: event.detail,
            timestamp: event.timestamp,
            status: TimelineEventStatus.active,
            dueAt: event.dueAt,
            phase: event.phase,
            relatedId: event.relatedId,
          );

          return reopened!;
        })
        .toList(growable: false);

    if (reopened == null) {
      return null;
    }

    await _timelineRepository.saveEvents(next);
    return reopened;
  }
}
