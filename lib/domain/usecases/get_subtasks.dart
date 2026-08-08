import 'package:fantastic_guacamole/domain/entities/subtask_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_subtask_repository.dart';

/// CHRONOSPARK-CLASS: SHIPPING | Feature: Goals/tasks
///
/// Resolved by subtasksProvider.
class GetSubtasks {
  const GetSubtasks(this._repository);

  final ISubtaskRepository _repository;

  /// Returns all subtasks, or only those under [parentTaskId] when given.
  ///
  /// A blank (non-null) [parentTaskId] is a filter that matched nothing, so it
  /// returns empty. Previously it fell through to the unfiltered list, leaking
  /// other tasks' subtasks into the caller's view.
  List<SubtaskEntity> call({String? parentTaskId}) {
    final List<SubtaskEntity> subtasks = _repository.getSubtasks();
    if (parentTaskId == null) {
      return subtasks;
    }
    if (parentTaskId.trim().isEmpty) {
      return const <SubtaskEntity>[];
    }
    return subtasks
        .where((SubtaskEntity subtask) => subtask.parentTaskId == parentTaskId)
        .toList(growable: false);
  }
}
