import 'package:fantastic_guacamole/data/models/task.dart';

/// âœ… Structured AI output
class AIResponse {
  final String taskTitle;
  final String reasoning;
  final String emotion;
  final double confidence;

  const AIResponse({
    required this.taskTitle,
    required this.reasoning,
    required this.emotion,
    required this.confidence,
  });
}

/// âœ… Converts AI internal logic â†’ user-facing output
class ResponseEngine {
  const ResponseEngine();

  AIResponse build({required Task task, required double energy}) {
    final bool highEnergy = energy >= 0.7;
    final String reasoning = highEnergy
        ? 'High-energy window detected; prioritize deep impact work.'
        : 'Moderate energy detected; prioritize momentum and completion.';

    return AIResponse(
      taskTitle: task.title,
      reasoning: reasoning,
      emotion: highEnergy ? 'driven' : 'balanced',
      confidence: highEnergy ? 0.82 : 0.64,
    );
  }
}
