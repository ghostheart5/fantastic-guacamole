import 'package:fantastic_guacamole/domain/entities/subtask_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_subtask_repository.dart';
import 'package:fantastic_guacamole/domain/policies/input_guard.dart';

/// CHRONOSPARK-CLASS: SHIPPING | Feature: Goals/tasks
///
/// Resolved by subtasksProvider. Empty-batch guarded.
/// Replaces the whole stored subtask collection. Pass `allowClear: true` to
/// clear it deliberately; an empty list is otherwise rejected as an accident.
class SaveSubtasks {
  const SaveSubtasks(this._repository);

  final ISubtaskRepository _repository;

  Future<void> call(
    List<SubtaskEntity> subtasks, {
    bool allowClear = false,
  }) {
    return _repository.saveSubtasks(
      InputGuard.batch(subtasks, 'subtasks', allowClear: allowClear),
    );
  }
}
