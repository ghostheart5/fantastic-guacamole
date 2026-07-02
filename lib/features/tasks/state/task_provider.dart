import 'package:fantastic_guacamole/features/tasks/models/tasks_models.dart';

class TasksState {
  final List<TaskModel> tasks;
  final bool isLoading;
  final String? error;

  const TasksState({required this.tasks, required this.isLoading, this.error});

  factory TasksState.initial() =>
      const TasksState(tasks: <TaskModel>[], isLoading: false, error: null);

  TasksState copyWith({
    List<TaskModel>? tasks,
    bool? isLoading,
    String? error,
  }) {
    return TasksState(
      tasks: tasks ?? this.tasks,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}
