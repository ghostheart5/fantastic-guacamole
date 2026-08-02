import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_timeline_repository.dart';

class TrackDeadlinesUsecase {
  const TrackDeadlinesUsecase(this._repository);

  final ITimelineRepository _repository;

  List<TimelineEventEntity> call() {
    final List<TimelineEventEntity> deadlines = _repository
        .getEvents()
        .where((TimelineEventEntity event) => event.isDeadline)
        .toList(growable: false);

    deadlines.sort((TimelineEventEntity a, TimelineEventEntity b) {
      final DateTime aDue = a.dueAt ?? a.timestamp;
      final DateTime bDue = b.dueAt ?? b.timestamp;
      return aDue.compareTo(bDue);
    });

    return deadlines;
  }
}
