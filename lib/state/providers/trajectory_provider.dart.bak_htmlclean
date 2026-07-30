import 'package:fantastic_guacamole/engine/si/prediction.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/state/models/session_score_view.dart';
import 'package:fantastic_guacamole/state/models/trajectory_summary_view.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final trajectorySummaryProvider = Provider<TrajectorySummaryView>((ref) {
  final tasksAsync = ref.watch(tasksProvider);
  final profile = ref.watch(profileProvider);
  final energy = ref.watch(energyProvider);
  final learning = ref.watch(learningProvider);
  final learningMetrics = ref.watch(learningMetricsProvider);
  final sessionScore = ref.watch(sessionScoreProvider);
  final siState = ref.watch(siStateProvider);

  final int pendingTasks = tasksAsync.maybeWhen(
    data: (tasks) => tasks.length,
    orElse: () => 0,
  );
  final int completedTasks = learning.completed;
  final int completedToday = siState.completedToday;

  final SessionScoreView? lastScore = sessionScore;
  final int lastSessionXp = lastScore?.xp ?? 0;
  final double lastSessionQuality = lastScore?.quality ?? 0.0;

  final int pressureIndex =
      ((pendingTasks * 16) +
              ((1 - energy) * 32) +
              ((1 - learningMetrics.momentum) * 18))
          .clamp(0.0, 100.0)
          .round();

  final int behaviorDivergence =
      ((learningMetrics.completionRate - learningMetrics.momentum).abs() * 100)
          .clamp(0.0, 100.0)
          .round();

  final String alert = pressureIndex >= 70
      ? 'SI ALERT: load is high, reduce task density.'
      : pressureIndex >= 40
      ? 'SI ALERT: trajectory is stable but watch drift.'
      : 'SI ALERT: trajectory is calm.';

  final String? predictionTitle = tasksAsync.maybeWhen(
    data: (tasks) => tasks.isEmpty ? null : tasks.first.title,
    orElse: () => null,
  );
  final Prediction? prediction = predictionTitle == null
      ? null
      : ref
            .watch(predictionProvider(predictionTitle))
            .maybeWhen(data: (value) => value, orElse: () => null);

  return TrajectorySummaryView(
    pendingTasks: pendingTasks,
    completedTasks: completedTasks,
    completedToday: completedToday,
    level: profile.level,
    streak: profile.streak,
    energy: energy,
    momentum: learningMetrics.momentum,
    adaptability: learningMetrics.adaptability,
    lastSessionXp: lastSessionXp,
    lastSessionQuality: lastSessionQuality,
    pressureIndex: pressureIndex,
    behaviorDivergence: behaviorDivergence,
    alert: alert,
    predictionTitle: predictionTitle,
    predictionOutcome: prediction?.outcome,
    predictionProbability: prediction?.probability,
    predictionExplanation: prediction?.explanation,
  );
});
