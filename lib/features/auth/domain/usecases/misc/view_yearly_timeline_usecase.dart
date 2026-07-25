import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_timeline_repository.dart';

class ViewYearlyTimelineUsecase {
  const ViewYearlyTimelineUsecase(this._repository);

  final ITimelineRepository _repository;

  List<TimelineEventEntity> call(DateTime year) {
    final DateTime start = DateTime(year.year);
    final DateTime end = DateTime(year.year + 1);

    return _repository
        .getEvents()
        .where(
          (TimelineEventEntity event) =>
              !event.timestamp.isBefore(start) && event.timestamp.isBefore(end),
        )
        .toList(growable: false);
  }
}
