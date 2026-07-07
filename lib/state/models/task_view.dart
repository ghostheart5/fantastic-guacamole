import 'package:fantastic_guacamole/domain/entities/task.dart';

class TaskView {
  const TaskView({
    required this.id,
    required this.title,
    required this.priority,
    required this.difficulty,
    required this.energyRequired,
  });

  final String id;
  final String title;
  final int priority;
  final int difficulty;
  final int energyRequired;

  factory TaskView.fromTask(Task task) {
    return TaskView(
      id: task.id,
      title: task.title,
      priority: task.priority,
      difficulty: task.difficulty,
      energyRequired: task.energyRequired,
    );
  }

  Task toTask() {
    return Task(
      id: id,
      title: title,
      priority: priority,
      difficulty: difficulty,
      energyRequired: energyRequired,
    );
  }
}
