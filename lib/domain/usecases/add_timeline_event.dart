import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_timeline_repository.dart';

class AddTimelineEvent {
  const AddTimelineEvent(this._repository);

  final ITimelineRepository _repository;

  Future<void> call(TimelineEventEntity event) => _repository.addEvent(event);
}
