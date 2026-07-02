import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';

class GetTasks {
  GetTasks(this.repo);

  final ITaskRepository repo;

  Future<List<TaskEntity>> call() {
    return repo.getAllTasks();
  }
}
