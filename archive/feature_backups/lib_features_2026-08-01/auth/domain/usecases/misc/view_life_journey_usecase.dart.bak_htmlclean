import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_timeline_repository.dart';

class ViewLifeJourneyUsecase {
  const ViewLifeJourneyUsecase(this._repository);

  final ITimelineRepository _repository;

  List<TimelineEventEntity> call() {
    final List<TimelineEventEntity> events =
        <TimelineEventEntity>[..._repository.getEvents()]..sort(
          (TimelineEventEntity a, TimelineEventEntity b) =>
              a.timestamp.compareTo(b.timestamp),
        );

    return events;
  }
}
