import 'package:fantastic_guacamole/engine/si/ai_response.dart';
import 'package:fantastic_guacamole/state/models/task_view.dart';

class AIRecommendation {
  const AIRecommendation({
    required this.message,
    this.task,
    this.reasoning,
    this.emotion,
    this.confidence,
  });

  final TaskView? task;
  final String message;
  final String? reasoning;
  final String? emotion;
  final double? confidence;

  factory AIRecommendation.fromResponse(AIResponse response) {
    final task = response.task;
    return AIRecommendation(
      task: task == null ? null : TaskView.fromTask(task),
      message: response.message,
      reasoning: response.reasoning,
      emotion: response.emotion,
      confidence: response.confidence,
    );
  }
}
