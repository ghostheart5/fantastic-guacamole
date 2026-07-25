import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_timeline_repository.dart';

class UpdateSubgoalUsecase {
  const UpdateSubgoalUsecase(this._timelineRepository);

  final ITimelineRepository _timelineRepository;

  Future<bool> call(TimelineEventEntity updatedSubgoal) async {
    final List<TimelineEventEntity> events = _timelineRepository.getEvents();

    bool found = false;

    final List<TimelineEventEntity> updated = events
        .map((event) {
          if (event.id == updatedSubgoal.id) {
            found = true;
            return updatedSubgoal;
          }

          return event;
        })
        .toList(growable: false);

    if (!found) {
      return false;
    }

    await _timelineRepository.saveEvents(updated);

    return true;
  }
}
