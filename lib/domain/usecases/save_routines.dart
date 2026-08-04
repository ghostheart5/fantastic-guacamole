import 'package:fantastic_guacamole/domain/entities/routine_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_routine_repository.dart';
import 'package:fantastic_guacamole/domain/policies/input_guard.dart';

/// CHRONOSPARK-CLASS: SHIPPING | Feature: Future automation
///
/// Resolved by routinesProvider. Empty-batch guarded.
/// Replaces the whole stored routine collection. Pass `allowClear: true` to
/// clear it deliberately; an empty list is otherwise rejected as an accident.
class SaveRoutines {
  const SaveRoutines(this._repository);

  final IRoutineRepository _repository;

  Future<void> call(
    List<RoutineEntity> routines, {
    bool allowClear = false,
  }) {
    return _repository.saveRoutines(
      InputGuard.batch(routines, 'routines', allowClear: allowClear),
    );
  }
}
