import 'package:fantastic_guacamole/domain/interfaces/i_timeline_repository.dart';
import 'package:fantastic_guacamole/domain/policies/input_guard.dart';

/// CHRONOSPARK-CLASS: SHIPPING | Feature: Calendar/timeline
///
/// Resolved by timelineProvider. Blank-id guarded.
class RemoveTimelineEvent {
  const RemoveTimelineEvent(this._repository);

  final ITimelineRepository _repository;

  Future<void> call(String id) =>
      _repository.removeEvent(InputGuard.id(id, 'id'));
}
