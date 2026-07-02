import 'package:fantastic_guacamole/features/tasks/state/tasks_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TasksController extends Notifier<TasksState> {
  @override
  TasksState build() => TasksState.initial();
}
