import 'package:fantastic_guacamole/engine/learning/learning_history.dart';
import 'package:fantastic_guacamole/engine/learning/learning_state.dart';

class LearningMetrics {
  const LearningMetrics({
    required this.completionRate,
    required this.momentum,
    required this.adaptability,
  });

  final double completionRate;
  final double momentum;
  final double adaptability;
}

class LearningMetricsCalculator {
  const LearningMetricsCalculator();

  LearningMetrics calculate({
    required LearningState state,
    required List<LearningHistoryEntry> history,
  }) {
    final int totalAttempts = state.completed + state.skipped;
    final double completionRate = totalAttempts == 0
        ? 0
        : state.completed / totalAttempts;
    final List<LearningHistoryEntry> recent = history.take(5).toList();
    final int positive = recent
        .where(
          (LearningHistoryEntry entry) =>
              entry.type == LearningEventType.completed,
        )
        .length;
    final double momentum = recent.isEmpty ? 0 : positive / recent.length;
    final double adaptability =
        ((state.effortWeight + state.priorityWeight) / 4).clamp(0.0, 1.0);

    return LearningMetrics(
      completionRate: completionRate,
      momentum: momentum,
      adaptability: adaptability,
    );
  }
}
