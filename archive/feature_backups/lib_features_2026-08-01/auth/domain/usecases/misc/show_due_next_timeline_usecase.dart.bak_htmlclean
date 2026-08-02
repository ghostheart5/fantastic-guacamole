import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_timeline_repository.dart';

class ShowDueNextTimelineUsecase {
  const ShowDueNextTimelineUsecase(this._repository);

  final ITimelineRepository _repository;

  List<TimelineEventEntity> call({int limit = 5}) {
    final DateTime now = DateTime.now();

    final List<TimelineEventEntity> due = _repository
        .getEvents()
        .where((TimelineEventEntity event) {
          final DateTime? dueAt = event.dueAt;
          if (dueAt == null) {
            return false;
          }
          return !dueAt.isBefore(now) &&
              event.status != TimelineEventStatus.completed;
        })
        .toList(growable: false);

    due.sort(
      (TimelineEventEntity a, TimelineEventEntity b) =>
          (a.dueAt ?? a.timestamp).compareTo(b.dueAt ?? b.timestamp),
    );

    if (due.length <= limit) {
      return due;
    }

    return due.sublist(0, limit);
  }
}
