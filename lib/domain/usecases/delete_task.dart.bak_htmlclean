import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';

class DeleteTask {
  DeleteTask(this.repository);

  final ITaskRepository repository;

  Future<void> call(String id) {
    return repository.deleteTask(id);
  }
}
