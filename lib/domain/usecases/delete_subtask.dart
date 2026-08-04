import 'package:fantastic_guacamole/domain/interfaces/i_subtask_repository.dart';
import 'package:fantastic_guacamole/domain/policies/input_guard.dart';

/// CHRONOSPARK-CLASS: SHIPPING | Feature: Goals/tasks
///
/// Resolved by subtasksProvider. Blank-id guarded.
class DeleteSubtask {
  const DeleteSubtask(this._repository);

  final ISubtaskRepository _repository;

  Future<void> call(String id) =>
      _repository.deleteSubtask(InputGuard.id(id, 'id'));
}
