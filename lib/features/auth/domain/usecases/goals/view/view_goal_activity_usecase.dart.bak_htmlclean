import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_timeline_repository.dart';

class ViewGoalActivityUsecase {
  const ViewGoalActivityUsecase(this._timelineRepository);

  final ITimelineRepository _timelineRepository;

  List<TimelineEventEntity> call(String goalId, {int limit = 25}) {
    final String targetId = goalId.trim();
    if (targetId.isEmpty) {
      return const <TimelineEventEntity>[];
    }

    final List<TimelineEventEntity> events = _timelineRepository
        .getEvents()
        .where((TimelineEventEntity event) => event.relatedId == targetId)
        .toList(growable: false);

    events.sort(
      (TimelineEventEntity a, TimelineEventEntity b) =>
          b.timestamp.compareTo(a.timestamp),
    );

    if (events.length <= limit) {
      return events;
    }

    return events.sublist(0, limit);
  }
}
