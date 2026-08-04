import 'package:fantastic_guacamole/domain/interfaces/i_calendar_repository.dart';
import 'package:fantastic_guacamole/domain/policies/input_guard.dart';

/// CHRONOSPARK-CLASS: PLANNED | Feature: Calendar/timeline
///
/// Persisted-calendar path. Blank-id guarded.
class RemoveCalendarEntry {
  RemoveCalendarEntry(this.repository);

  final ICalendarRepository repository;

  Future<void> call(String id) {
    return repository.removeEntry(InputGuard.id(id, 'id'));
  }
}
