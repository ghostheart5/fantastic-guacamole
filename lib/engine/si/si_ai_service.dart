import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/data/models/si_state.dart';
import 'package:fantastic_guacamole/data/models/task.dart';
import 'package:fantastic_guacamole/engine/learning/learning_state.dart';
import 'package:fantastic_guacamole/engine/si/ai_personality.dart';
import 'package:fantastic_guacamole/engine/si/ai_response.dart';
import 'package:fantastic_guacamole/engine/si/si_core.dart';
import 'package:fantastic_guacamole/engine/si/si_intent.dart';

class SIAIService {
  const SIAIService();

  AIResponse handleInput(
    String input, {
    required List<Task> tasks,
    required double energy,
    required LearningState learning,
    AIPersonality personality = AIPersonality.coach,
  }) {
    final SIIntent intent = SIIntentParser.parse(input);

    switch (intent) {
      case SIIntent.getTask:
        return generate(
          tasks: tasks,
          si: SIState(
            energy: energy,
            fatigue: (1 - energy).clamp(0.0, 1.0),
            completedToday: learning.completed,
          ),
          learning: learning,
          personality: personality,
        );
      case SIIntent.startFocus:
        return const AIResponse(
          task: null,
          message: 'Starting focus session.',
          reasoning: 'Starting focus session.',
          emotion: 'focused',
          confidence: 1.0,
        );
      case SIIntent.reflect:
        return const AIResponse(
          task: null,
          message: 'Opening reflection view.',
          reasoning: 'Opening reflection view.',
          emotion: 'balanced',
          confidence: 0.9,
        );
      case SIIntent.unknown:
        return const AIResponse(
          task: null,
          message: 'I did not understand that.',
          reasoning: 'I did not understand that.',
          emotion: 'neutral',
          confidence: 0.3,
        );
    }
  }

  AIResponse generate({
    required List<Task> tasks,
    required SIState si,
    required LearningState learning,
    AIPersonality personality = AIPersonality.coach,
  }) {
    if (tasks.isEmpty) {
      return const AIResponse(
        task: null,
        message: 'No tasks available. System idle.',
        reasoning: 'No actionable tasks in the queue.',
        emotion: 'balanced',
        confidence: 0.35,
      );
    }

    final SICore core = SICore(si: si, learning: learning);
    final decision = core.decide(tasks);

    if (decision == null) {
      return const AIResponse(
        task: null,
        message: 'No tasks available. System idle.',
        reasoning: 'No actionable tasks in the queue.',
        emotion: 'balanced',
        confidence: 0.35,
      );
    }

    final String message = _buildMessage(
      task: decision.task,
      reasoning: decision.reasoning,
      si: si,
      personality: personality,
    );

    Logger.log('AI', 'Response generated: $message');

    return AIResponse(
      task: decision.task,
      message: message,
      reasoning: decision.reasoning,
      emotion: _emotionFor(si),
      confidence: _confidenceFor(decision.score),
    );
  }

  String _buildMessage({
    required Task task,
    required String reasoning,
    required SIState si,
    required AIPersonality personality,
  }) {
    switch (personality) {
      case AIPersonality.coach:
        if (si.fatigue > 0.7) {
          return 'You are close to overload. Keep this efficient: ${task.title}.';
        }
        if (si.energy > 0.7) {
          return 'You are ready. Lock in and execute ${task.title}.';
        }
        return 'Solid next move: ${task.title}. Stay consistent.';
      case AIPersonality.strict:
        if (si.fatigue > 0.7) {
          return 'Discipline first. Execute ${task.title} cleanly, then recover.';
        }
        return 'Stop hesitating. Execute ${task.title} now.';
      case AIPersonality.calm:
        if (si.fatigue > 0.7) {
          return 'Take it steady. ${task.title} is the right low-friction step.';
        }
        return 'Breathe and move forward with ${task.title}.';
      case AIPersonality.neutral:
        return '$reasoning -> ${task.title}';
    }
  }

  String _emotionFor(SIState si) {
    if (si.fatigue > 0.75) return 'cautious';
    if (si.energy > 0.75) return 'driven';
    if (si.energy > 0.55) return 'focused';
    return 'balanced';
  }

  double _confidenceFor(double score) {
    return (score / 60).clamp(0.35, 0.98);
  }
}
