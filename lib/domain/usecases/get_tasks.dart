import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/domain/models/paged_result.dart';

class GetTasks {
  GetTasks(this.repo);

  final ITaskRepository repo;

  Future<List<TaskEntity>> call() {
    return repo.getAllTasks();
  }

  Future<PagedResult<TaskEntity>> page({String? cursor, int limit = 50}) async {
    final List<TaskEntity> tasks = await repo.getAllTasks();
    final int safeLimit = limit < 1 ? 1 : limit;
    final int startIndex = cursor == null
        ? 0
        : tasks.indexWhere((TaskEntity task) => task.id == cursor) + 1;
    if (startIndex >= tasks.length) {
      return const PagedResult<TaskEntity>(items: <TaskEntity>[], nextCursor: null);
    }
    final List<TaskEntity> page = tasks.skip(startIndex).take(safeLimit).toList(growable: false);
    final int nextIndex = startIndex + page.length;
    final String? nextCursor = nextIndex < tasks.length && page.isNotEmpty ? page.last.id : null;
    return PagedResult<TaskEntity>(items: page, nextCursor: nextCursor);
  }
}
