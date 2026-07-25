import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_timeline_repository.dart';
import 'package:fantastic_guacamole/domain/usecases/save_timeline_events.dart';

class UpdateTimelineEventUsecase {
  const UpdateTimelineEventUsecase(this._repository);

  final ITimelineRepository _repository;

  Future<void> call(TimelineEventEntity updatedEvent) {
    final List<TimelineEventEntity> existing = _repository.getEvents();

    final List<TimelineEventEntity> next = existing
        .map(
          (TimelineEventEntity event) =>
              event.id == updatedEvent.id ? updatedEvent : event,
        )
        .toList(growable: false);

    final bool alreadyExists = existing.any(
      (TimelineEventEntity event) => event.id == updatedEvent.id,
    );

    if (!alreadyExists) {
      return SaveTimelineEvents(
        _repository,
      ).call(<TimelineEventEntity>[updatedEvent, ...existing]);
    }

    return SaveTimelineEvents(_repository).call(next);
  }
}
