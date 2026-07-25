import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_timeline_repository.dart';

class ViewGoalTimelineUsecase {
  const ViewGoalTimelineUsecase(this._timelineRepository);

  final ITimelineRepository _timelineRepository;

  List<TimelineEventEntity> call(String goalId) {
    final String targetId = goalId.trim();
    if (targetId.isEmpty) {
      return const <TimelineEventEntity>[];
    }

    return _timelineRepository
        .getEvents()
        .where((TimelineEventEntity event) => event.relatedId == targetId)
        .toList(growable: false);
  }
}
