import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_timeline_repository.dart';

class UpdateMilestoneUsecase {
  const UpdateMilestoneUsecase(this._timelineRepository);

  final ITimelineRepository _timelineRepository;

  Future<bool> call(TimelineEventEntity updatedMilestone) async {
    final List<TimelineEventEntity> events = _timelineRepository.getEvents();
    bool found = false;

    final List<TimelineEventEntity> next = events
        .map((TimelineEventEntity event) {
          if (event.id == updatedMilestone.id) {
            found = true;
            return updatedMilestone;
          }
          return event;
        })
        .toList(growable: false);

    if (!found) {
      return false;
    }

    await _timelineRepository.saveEvents(next);
    return true;
  }
}
