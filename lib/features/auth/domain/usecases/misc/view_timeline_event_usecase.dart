import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_timeline_repository.dart';

class ViewTimelineEventUsecase {
  const ViewTimelineEventUsecase(this._repository);

  final ITimelineRepository _repository;

  TimelineEventEntity? call(String id) {
    final String targetId = id.trim();
    if (targetId.isEmpty) {
      return null;
    }

    for (final TimelineEventEntity event in _repository.getEvents()) {
      if (event.id == targetId) {
        return event;
      }
    }

    return null;
  }
}
