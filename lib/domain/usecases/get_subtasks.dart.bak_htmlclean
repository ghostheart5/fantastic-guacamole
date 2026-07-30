import 'package:fantastic_guacamole/domain/entities/subtask_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_subtask_repository.dart';

class GetSubtasks {
  const GetSubtasks(this._repository);

  final ISubtaskRepository _repository;

  List<SubtaskEntity> call({String? parentTaskId}) {
    final List<SubtaskEntity> subtasks = _repository.getSubtasks();
    if (parentTaskId == null || parentTaskId.trim().isEmpty) {
      return subtasks;
    }
    return subtasks
        .where((SubtaskEntity subtask) => subtask.parentTaskId == parentTaskId)
        .toList(growable: false);
  }
}
