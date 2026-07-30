import 'package:fantastic_guacamole/domain/entities/learning_entity.dart';

class LearningPolicy {
  static LearningEntity applyFeedback({
    required LearningEntity current,
    required bool success,
    required int difficulty,
  }) {
    final double effortDelta = success ? 0.05 : -0.05;
    final double priorityDelta = difficulty >= 4
        ? (success ? 0.03 : -0.02)
        : 0.0;

    return current.copyWith(
      effortWeight: (current.effortWeight + effortDelta).clamp(0.5, 2.0),
      priorityWeight: (current.priorityWeight + priorityDelta).clamp(0.5, 2.0),
      completed: success ? current.completed + 1 : current.completed,
      skipped: success ? current.skipped : current.skipped + 1,
    );
  }
}
