import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/domain/policies/task_policy.dart';

class CreateTask {
  CreateTask(this.repo);

  final ITaskRepository repo;

  Future<void> call(TaskEntity task) async {
    if (!TaskPolicy.isValid(task)) {
      throw Exception('Invalid task');
    }
    await repo.saveTask(task);
  }
}
