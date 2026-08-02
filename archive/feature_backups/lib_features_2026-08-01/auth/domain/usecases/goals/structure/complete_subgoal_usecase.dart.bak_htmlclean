import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_timeline_repository.dart';

class CompleteSubgoalUsecase {
  const CompleteSubgoalUsecase(this._timelineRepository);

  final ITimelineRepository _timelineRepository;

  Future<TimelineEventEntity?> call(String subgoalId) async {
    final List<TimelineEventEntity> events = _timelineRepository.getEvents();

    TimelineEventEntity? completed;

    final List<TimelineEventEntity> updated = events
        .map((event) {
          if (event.id != subgoalId.trim()) {
            return event;
          }

          completed = TimelineEventEntity(
            id: event.id,
            type: event.type,
            title: event.title,
            detail: event.detail,
            timestamp: event.timestamp,
            status: TimelineEventStatus.completed,
            dueAt: event.dueAt,
            phase: event.phase,
            relatedId: event.relatedId,
          );

          return completed!;
        })
        .toList(growable: false);

    if (completed == null) {
      return null;
    }

    await _timelineRepository.saveEvents(updated);

    return completed;
  }
}
