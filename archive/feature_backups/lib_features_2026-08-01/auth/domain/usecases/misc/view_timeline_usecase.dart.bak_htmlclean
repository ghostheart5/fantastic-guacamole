import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_timeline_repository.dart';
import 'package:fantastic_guacamole/domain/usecases/get_timeline_events.dart';

class ViewTimelineUsecase {
  const ViewTimelineUsecase(this._repository);

  final ITimelineRepository _repository;

  List<TimelineEventEntity> call() {
    return GetTimelineEvents(_repository).call();
  }
}
