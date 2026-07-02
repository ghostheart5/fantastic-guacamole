import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/domain/policies/task_policy.dart';

class CompleteTask {
  CompleteTask(this.repository);

  final ITaskRepository repository;

  Future<void> call(String id) async {
    final task = await repository.getTaskById(id);
    if (task == null) {
      throw StateError('Task not found');
    }
    if (!TaskPolicy.canComplete(task)) {
      throw StateError('Task already completed');
    }

    await repository.saveTask(task.copyWith(isCompleted: true));
  }
}
