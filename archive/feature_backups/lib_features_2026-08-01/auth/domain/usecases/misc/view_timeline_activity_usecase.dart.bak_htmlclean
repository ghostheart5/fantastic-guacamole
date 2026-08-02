import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_timeline_repository.dart';

class ViewTimelineActivityUsecase {
  const ViewTimelineActivityUsecase(this._repository);

  final ITimelineRepository _repository;

  List<TimelineEventEntity> call({int limit = 50}) {
    final List<TimelineEventEntity> events =
        <TimelineEventEntity>[..._repository.getEvents()]..sort(
          (TimelineEventEntity a, TimelineEventEntity b) =>
              b.timestamp.compareTo(a.timestamp),
        );

    if (events.length <= limit) {
      return events;
    }

    return events.sublist(0, limit);
  }
}
