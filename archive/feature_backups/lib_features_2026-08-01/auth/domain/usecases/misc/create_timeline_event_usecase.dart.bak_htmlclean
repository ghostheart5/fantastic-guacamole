import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_timeline_repository.dart';
import 'package:fantastic_guacamole/domain/usecases/add_timeline_event.dart';

class CreateTimelineEventUsecase {
  const CreateTimelineEventUsecase(this._repository);

  final ITimelineRepository _repository;

  Future<void> call(TimelineEventEntity event) {
    return AddTimelineEvent(_repository).call(event);
  }
}
