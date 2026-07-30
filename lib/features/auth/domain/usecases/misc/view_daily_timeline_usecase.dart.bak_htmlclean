import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_timeline_repository.dart';

class ViewDailyTimelineUsecase {
  const ViewDailyTimelineUsecase(this._repository);

  final ITimelineRepository _repository;

  List<TimelineEventEntity> call(DateTime day) {
    final DateTime start = DateTime(day.year, day.month, day.day);
    final DateTime end = start.add(const Duration(days: 1));

    return _repository
        .getEvents()
        .where(
          (TimelineEventEntity event) =>
              !event.timestamp.isBefore(start) && event.timestamp.isBefore(end),
        )
        .toList(growable: false);
  }
}
