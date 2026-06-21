import '../../entities/routine_entity.dart';
import '../../entities/task_entity.dart';

class BuildRoutineUseCase {
  RoutineEntity call({
    required String id,
    required String name,
    required List<TaskEntity> tasks,
  }) {
    return RoutineEntity(id: id, name: name, tasks: tasks);
  }
}
