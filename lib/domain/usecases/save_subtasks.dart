import 'package:fantastic_guacamole/domain/entities/subtask_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_subtask_repository.dart';

class SaveSubtasks {
  const SaveSubtasks(this._repository);

  final ISubtaskRepository _repository;

  Future<void> call(List<SubtaskEntity> subtasks) {
    return _repository.saveSubtasks(subtasks);
  }
}
