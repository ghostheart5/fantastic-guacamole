import 'package:fantastic_guacamole/data/models/task.dart';

class AIResponse {
  const AIResponse({
    this.task,
    this.message = '',
    this.reasoning = '',
    this.emotion = 'balanced',
    this.confidence = 0.5,
  });

  final Task? task;
  final String message;
  final String reasoning;
  final String emotion;
  final double confidence;
}
