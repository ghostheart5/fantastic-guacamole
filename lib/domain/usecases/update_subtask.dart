import 'package:fantastic_guacamole/domain/entities/subtask_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_subtask_repository.dart';

/// CHRONOSPARK-CLASS: SHIPPING | Feature: Goals/tasks
///
/// Resolved by subtasksProvider.
class UpdateSubtask {
  const UpdateSubtask(this._repository);

  final ISubtaskRepository _repository;

  Future<void> call(SubtaskEntity subtask) => _repository.saveSubtask(subtask);
}
