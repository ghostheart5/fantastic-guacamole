import 'package:fantastic_guacamole/data/models/task.dart';

class AIResponse {
  const AIResponse({
    required this.task,
    required this.message,
    required this.reasoning,
    required this.emotion,
    required this.confidence,
  });

  final Task? task;
  final String message;
  final String reasoning;
  final String emotion;
  final double confidence;

  String get taskTitle => task?.title ?? 'No active tasks';
}
