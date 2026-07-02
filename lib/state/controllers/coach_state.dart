import 'package:fantastic_guacamole/state/models/task_view.dart';

class CoachState {
  const CoachState({
    this.loading = false,
    this.error,
    this.response,
    this.task,
  });

  final bool loading;
  final String? error;
  final String? response;
  final TaskView? task;

  CoachState copyWith({
    bool? loading,
    String? error,
    String? response,
    TaskView? task,
  }) {
    return CoachState(
      loading: loading ?? this.loading,
      error: error ?? this.error,
      response: response ?? this.response,
      task: task ?? this.task,
    );
  }
}
