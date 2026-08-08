import 'package:fantastic_guacamole/domain/interfaces/i_routine_repository.dart';
import 'package:fantastic_guacamole/domain/policies/input_guard.dart';

/// CHRONOSPARK-CLASS: SHIPPING | Feature: Future automation
///
/// Resolved by routinesProvider. Blank-id guarded.
class DeleteRoutine {
  const DeleteRoutine(this._repository);

  final IRoutineRepository _repository;

  Future<void> call(String id) =>
      _repository.deleteRoutine(InputGuard.id(id, 'id'));
}
