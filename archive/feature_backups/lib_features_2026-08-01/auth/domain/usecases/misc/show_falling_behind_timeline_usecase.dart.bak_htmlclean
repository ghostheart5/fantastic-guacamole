import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_timeline_repository.dart';

class ShowFallingBehindTimelineUsecase {
  const ShowFallingBehindTimelineUsecase(this._repository);

  final ITimelineRepository _repository;

  List<TimelineEventEntity> call() {
    final DateTime now = DateTime.now();

    final List<TimelineEventEntity> fallingBehind = _repository
        .getEvents()
        .where((TimelineEventEntity event) {
          final DateTime? dueAt = event.dueAt;
          return event.isOverdue ||
              event.status == TimelineEventStatus.atRisk ||
              event.isRisk ||
              (dueAt != null &&
                  dueAt.isBefore(now) &&
                  event.status != TimelineEventStatus.completed);
        })
        .toList(growable: false);

    fallingBehind.sort(
      (TimelineEventEntity a, TimelineEventEntity b) =>
          (a.dueAt ?? a.timestamp).compareTo(b.dueAt ?? b.timestamp),
    );

    return fallingBehind;
  }
}
