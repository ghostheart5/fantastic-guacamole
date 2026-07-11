import 'package:fantastic_guacamole/domain/interfaces/i_subtask_repository.dart';

class DeleteSubtask {
  const DeleteSubtask(this._repository);

  final ISubtaskRepository _repository;

  Future<void> call(String id) => _repository.deleteSubtask(id);
}
