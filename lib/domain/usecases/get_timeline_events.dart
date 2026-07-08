import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_timeline_repository.dart';

class GetTimelineEvents {
  const GetTimelineEvents(this._repository);

  final ITimelineRepository _repository;

  List<TimelineEventEntity> call() => _repository.getEvents();
}
