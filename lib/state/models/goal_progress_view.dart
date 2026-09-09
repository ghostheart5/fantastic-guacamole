import 'package:fantastic_guacamole/domain/entities/task_entity.dart';

class GoalProgressView {
  const GoalProgressView({required this.tasks, required this.completedCount});

  const GoalProgressView.empty()
    : tasks = const <TaskEntity>[],
      completedCount = 0;

  final List<TaskEntity> tasks;
  final int completedCount;

  /// Ongoing series have no finite completion denominator. Report their
  /// completed occurrences separately from the goal's one-time action ratio.
  int get totalCount => tasks.where(_countsTowardFiniteProgress).length;

  int get recurringCompletedCount =>
      tasks.where((task) => task.isRecurring && task.isCompleted).length;

  int get excludedCount =>
      tasks.where((task) => task.isSkipped || task.isCanceled).length;

  factory GoalProgressView.fromTasks(List<TaskEntity> tasks) =>
      GoalProgressView(
        tasks: List.unmodifiable(tasks),
        completedCount: tasks
            .where(
              (task) => _countsTowardFiniteProgress(task) && task.isCompleted,
            )
            .length,
      );

  static bool _countsTowardFiniteProgress(TaskEntity task) =>
      !task.isRecurring && !task.isSkipped && !task.isCanceled;

  double get fraction => totalCount == 0 ? 0 : completedCount / totalCount;
}
