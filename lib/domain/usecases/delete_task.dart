import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/domain/policies/input_guard.dart';

/// CHRONOSPARK-CLASS: SHIPPING | Feature: Goals/tasks
///
/// Used by the Timeline task-delete flow through taskProvider. Blank-id
/// guarded.
class DeleteTask {
  DeleteTask(this.repository);

  final ITaskRepository repository;

  Future<void> call(String id) {
    return repository.deleteTask(InputGuard.id(id, 'id'));
  }
}
