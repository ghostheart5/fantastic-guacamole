import 'package:fantastic_guacamole/data/models/si_state.dart';
import 'package:fantastic_guacamole/data/models/task.dart';
import 'package:fantastic_guacamole/engine/learning/learning_state.dart';
import 'package:fantastic_guacamole/engine/si/ai_personality.dart';
import 'package:fantastic_guacamole/engine/si/ai_response.dart';

class SIAIService {
  const SIAIService();

  AIResponse generate({
    required List<Task> tasks,
    required SIState si,
    required LearningState learning,
    AIPersonality personality = AIPersonality.coach,
  }) {
    final task = tasks.isEmpty ? null : tasks.first;
    final message = task != null
        ? 'Focus on: ${task.title}. Energy at ${(si.energy * 100).round()}%.'
        : 'Your task queue is empty. Add tasks to get recommendations.';
    return AIResponse(
      task: task,
      message: message,
      reasoning: 'Selected based on current energy and priority.',
      emotion: si.energy > 0.6 ? 'confident' : 'balanced',
      confidence: si.energy,
    );
  }

  AIResponse handleInput(
    String prompt, {
    required List<Task> tasks,
    required double energy,
    required LearningState learning,
    AIPersonality personality = AIPersonality.coach,
  }) {
    return AIResponse(
      message: prompt.isNotEmpty ? 'Understood: $prompt' : 'How can I help?',
      reasoning: 'Processed input.',
      emotion: energy > 0.6 ? 'confident' : 'balanced',
      confidence: energy,
    );
  }
}
