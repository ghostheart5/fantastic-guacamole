import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_timeline_repository.dart';
import 'package:fantastic_guacamole/domain/policies/input_guard.dart';

/// CHRONOSPARK-CLASS: SHIPPING | Feature: Calendar/timeline
///
/// Registered as saveTimelineEventsUseCaseProvider; bulk replace for
/// import/restore. Empty-batch guarded.
/// Replaces the whole stored timeline collection. Pass `allowClear: true` to
/// clear it deliberately; an empty list is otherwise rejected as an accident.
class SaveTimelineEvents {
  const SaveTimelineEvents(this._repository);

  final ITimelineRepository _repository;

  Future<void> call(
    List<TimelineEventEntity> events, {
    bool allowClear = false,
  }) => _repository.saveEvents(
    InputGuard.batch(events, 'events', allowClear: allowClear),
  );
}
