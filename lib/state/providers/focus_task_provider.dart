import 'package:fantastic_guacamole/state/models/task_view.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final focusTaskProvider = NotifierProvider<FocusTaskNotifier, TaskView?>(FocusTaskNotifier.new);

class FocusTaskNotifier extends Notifier<TaskView?> {
  @override
  TaskView? build() => null;

  void set(TaskView? value) => state = value;
}
