import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_timeline_repository.dart';

class ViewWeeklyTimelineUsecase {
  const ViewWeeklyTimelineUsecase(this._repository);

  final ITimelineRepository _repository;

  List<TimelineEventEntity> call(DateTime day) {
    final DateTime date = DateTime(day.year, day.month, day.day);
    final DateTime start = date.subtract(Duration(days: date.weekday - 1));
    final DateTime end = start.add(const Duration(days: 7));

    return _repository
        .getEvents()
        .where(
          (TimelineEventEntity event) =>
              !event.timestamp.isBefore(start) && event.timestamp.isBefore(end),
        )
        .toList(growable: false);
  }
}
