import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/data/models/si_state.dart';
import 'package:fantastic_guacamole/data/models/task.dart';
import 'package:fantastic_guacamole/engine/learning/learning_state.dart';
import 'package:fantastic_guacamole/engine/si/si_decision.dart';

class SIEngine {
  const SIEngine(this.si, this.learning);

  final SIState si;
  final LearningState learning;

  Decision? decide(List<Task> tasks) {
    if (tasks.isEmpty) return null;

    final List<Task> ranked = List<Task>.from(tasks)
      ..sort((Task a, Task b) => _score(b).compareTo(_score(a)));

    final Task best = ranked.first;
    final double score = _score(best);
    final String decisionReasoning = reasoning(best);

    Logger.log('AI', 'Selected task: ${best.title}');

    return Decision(task: best, score: score, reasoning: decisionReasoning);
  }

  double _score(Task task) {
    final double energyNeed = task.energyRequired / 5;
    final double energyMatch = 1 - (si.energy - energyNeed).abs();

    double score = task.priority * learning.priorityWeight * 10;
    score += energyMatch.clamp(0.0, 1.0) * 12;
    score += (1 - si.fatigue) * 6;
    score -= task.difficulty * learning.effortWeight * si.fatigue * 4;

    if (si.energy >= energyNeed) {
      score += 4;
    }

    if (si.fatigue > 0.7 && task.difficulty <= 2) {
      score += 3;
    }

    Logger.log(
      'SI',
      '${task.title} -> score=$score '
          '(priority=${task.priority}, difficulty=${task.difficulty}, '
          'energyRequired=${task.energyRequired}, energy=${si.energy}, '
          'fatigue=${si.fatigue}, effort=${learning.effortWeight}, '
          'priorityWeight=${learning.priorityWeight})',
    );

    return score;
  }

  String reasoning(Task task) {
    if (si.fatigue > 0.75) {
      return 'Fatigue is elevated. Picking a lower-friction task to keep momentum stable.';
    }

    if (si.energy > 0.75) {
      return 'Energy is high. This is the right window for a higher-impact task.';
    }

    if (task.priority >= 4) {
      return 'Priority pressure is dominant, so this task is leading the queue.';
    }

    if (learning.effortWeight > 1.2) {
      return 'Your learning profile is tolerating more effort, so the engine is leaning upward.';
    }

    return 'Balancing energy, fatigue, and task weight for the next best move.';
  }
}
