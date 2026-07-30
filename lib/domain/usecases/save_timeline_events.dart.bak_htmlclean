import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_timeline_repository.dart';

class SaveTimelineEvents {
  const SaveTimelineEvents(this._repository);

  final ITimelineRepository _repository;

  Future<void> call(List<TimelineEventEntity> events) =>
      _repository.saveEvents(events);
}
