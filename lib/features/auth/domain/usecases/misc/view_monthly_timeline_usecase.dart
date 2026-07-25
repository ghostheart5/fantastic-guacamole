import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_timeline_repository.dart';

class ViewMonthlyTimelineUsecase {
  const ViewMonthlyTimelineUsecase(this._repository);

  final ITimelineRepository _repository;

  List<TimelineEventEntity> call(DateTime month) {
    final DateTime start = DateTime(month.year, month.month);
    final DateTime end = DateTime(month.year, month.month + 1);

    return _repository
        .getEvents()
        .where(
          (TimelineEventEntity event) =>
              !event.timestamp.isBefore(start) && event.timestamp.isBefore(end),
        )
        .toList(growable: false);
  }
}
