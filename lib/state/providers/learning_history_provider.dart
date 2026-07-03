import 'package:fantastic_guacamole/engine/learning/learning_history.dart';
import 'package:fantastic_guacamole/engine/learning/learning_metrics.dart';
import 'package:fantastic_guacamole/engine/learning/learning_state.dart';
import 'package:fantastic_guacamole/state/controllers/learning_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final learningHistoryProvider =
    NotifierProvider<LearningHistoryController, List<LearningHistoryEntry>>(
      LearningHistoryController.new,
    );

final learningMetricsProvider = Provider<LearningMetrics>((ref) {
  final LearningState learning = ref.watch(learningProvider);
  final List<LearningHistoryEntry> history = ref.watch(learningHistoryProvider);
  return const LearningMetricsCalculator().calculate(
    state: learning,
    history: history,
  );
});

class LearningHistoryController extends Notifier<List<LearningHistoryEntry>> {
  @override
  List<LearningHistoryEntry> build() => const <LearningHistoryEntry>[];

  void record({
    required LearningEventType type,
    required int difficulty,
    required LearningState learning,
  }) {
    state = <LearningHistoryEntry>[
      LearningHistoryEntry(
        timestamp: DateTime.now(),
        type: type,
        difficulty: difficulty,
        effortWeight: learning.effortWeight,
        priorityWeight: learning.priorityWeight,
        completed: learning.completed,
        skipped: learning.skipped,
      ),
      ...state,
    ].take(32).toList();
  }

  void clear() {
    state = const <LearningHistoryEntry>[];
  }
}
