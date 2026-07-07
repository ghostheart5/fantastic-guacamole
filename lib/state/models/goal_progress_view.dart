import 'package:fantastic_guacamole/domain/entities/task_entity.dart';

class GoalProgressView {
  const GoalProgressView({required this.tasks, required this.completedCount});

  const GoalProgressView.empty()
    : tasks = const <TaskEntity>[],
      completedCount = 0;

  final List<TaskEntity> tasks;
  final int completedCount;

  int get totalCount => tasks.length;

  double get fraction => totalCount == 0 ? 0 : completedCount / totalCount;
}
