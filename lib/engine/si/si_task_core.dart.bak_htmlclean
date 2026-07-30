import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/engine/learning/adaptive_learning.dart';
import 'package:fantastic_guacamole/engine/learning/learning_state.dart';
import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/engine/si/si_decision.dart';

class SICore {
  SICore({required this.si, required this.learning});

  final SIState si;
  final LearningState learning;

  Decision? decide(List<Task> tasks) {
    if (tasks.isEmpty) {
      return null;
    }

    Task best = tasks.first;
    double bestScore = -1;
    for (final Task task in tasks) {
      final double urgency = task.priority.toDouble() * 0.5;
      final double energyFit = (si.energy - (task.energyRequired / 5)).abs();
      final double difficultyPenalty = (task.difficulty / 5) * si.fatigue;
      final double score = urgency + (1 - energyFit) - difficultyPenalty;
      if (score > bestScore) {
        bestScore = score;
        best = task;
      }
    }

    return Decision(task: best, score: bestScore, reasoning: explain(best));
  }

  String explain(Task task) {
    return 'Selected ${task.title} using priority, energy fit, and fatigue-aware scoring.';
  }

  SICoreUpdate onComplete(Task task) {
    final LearningState nextLearning = AdaptiveLearning(
      learning,
    ).onTaskComplete(task.difficulty);
    final SIState nextSi = si.copyWith(
      energy: (si.energy - 0.08).clamp(0.0, 1.0),
      fatigue: (si.fatigue + 0.10).clamp(0.0, 1.0),
      completedToday: si.completedToday + 1,
    );

    return SICoreUpdate(si: nextSi, learning: nextLearning);
  }

  SICoreUpdate onSkip(Task task) {
    final LearningState nextLearning = AdaptiveLearning(
      learning,
    ).onTaskSkipped(task.difficulty);
    final SIState nextSi = si.copyWith(
      fatigue: (si.fatigue + 0.05).clamp(0.0, 1.0),
    );

    return SICoreUpdate(si: nextSi, learning: nextLearning);
  }

  Map<String, dynamic> snapshot() {
    return <String, dynamic>{
      'energy': si.energy,
      'fatigue': si.fatigue,
      'completed': learning.completed,
      'skipped': learning.skipped,
    };
  }
}

class SICoreUpdate {
  const SICoreUpdate({required this.si, required this.learning});

  final SIState si;
  final LearningState learning;
}
