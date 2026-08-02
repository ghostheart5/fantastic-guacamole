import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_timeline_repository.dart';

class TrackCompletedEventsUsecase {
  const TrackCompletedEventsUsecase(this._repository);

  final ITimelineRepository _repository;

  List<TimelineEventEntity> call() {
    final List<TimelineEventEntity> completed = _repository
        .getEvents()
        .where(
          (TimelineEventEntity event) =>
              event.status == TimelineEventStatus.completed ||
              event.isMilestone,
        )
        .toList(growable: false);

    completed.sort(
      (TimelineEventEntity a, TimelineEventEntity b) =>
          b.timestamp.compareTo(a.timestamp),
    );

    return completed;
  }
}
