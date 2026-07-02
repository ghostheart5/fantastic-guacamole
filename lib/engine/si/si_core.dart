import 'package:fantastic_guacamole/data/models/si_state.dart';
import 'package:fantastic_guacamole/data/models/task.dart';
import 'package:fantastic_guacamole/engine/learning/adaptive_learning.dart';
import 'package:fantastic_guacamole/engine/learning/learning_state.dart';
import 'package:fantastic_guacamole/engine/si/si_decision.dart';
import 'package:fantastic_guacamole/engine/si/si_engine.dart';

class SICore {
  SICore({required this.si, required this.learning})
    : engine = SIEngine(si, learning);

  late final SIEngine engine;
  final SIState si;
  final LearningState learning;

  Decision? decide(List<Task> tasks) {
    return engine.decide(tasks);
  }

  String explain(Task task) {
    return engine.reasoning(task);
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
