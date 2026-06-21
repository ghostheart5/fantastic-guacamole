import '../../entities/task_entity.dart';

class ToggleTaskCompletionUseCase {
  TaskEntity call(TaskEntity task) {
    return task.copyWith(done: !task.done);
  }
}
