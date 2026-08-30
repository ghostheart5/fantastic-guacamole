import 'package:fantastic_guacamole/engine/si/prediction.dart';
import 'package:fantastic_guacamole/domain/predictive/predictive_planning_contract.dart';
import 'package:fantastic_guacamole/domain/trajectory/trajectory_consequence_contract.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/state/models/completion_score_view.dart';
import 'package:fantastic_guacamole/state/models/trajectory_summary_view.dart';
import 'package:fantastic_guacamole/state/providers/consented_human_context_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final trajectorySummaryProvider = Provider<TrajectorySummaryView>((ref) {
  final tasksAsync = ref.watch(tasksProvider);
  final profile = ref.watch(profileProvider);
  final humanContext = ref.watch(consentedHumanContextProvider);
  final energy = humanContext.siState.energy;
  final learning = ref.watch(learningProvider);
  final learningMetrics = ref.watch(learningMetricsProvider);
  final completionScore = ref.watch(completionScoreProvider);
  final siState = humanContext.siState;
  final personalization = ref.watch(personalizationProfileProvider);

  final int pendingTasks = tasksAsync.maybeWhen(
    data: (tasks) => tasks.length,
    orElse: () => 0,
  );
  final int completedTasks = learning.completed;
  final int completedToday = siState.completedToday;
  final bool hasObservedEnergy = siState.hasObservedEnergy;

  final CompletionScoreView? lastScore = completionScore;
  final int lastCompletionXp = lastScore?.xp ?? 0;
  final double lastCompletionQuality = lastScore?.quality ?? 0.0;

  final int pressureIndex =
      ((pendingTasks * 16) +
              (hasObservedEnergy ? (1 - energy) * 32 : 0) +
              ((1 - learningMetrics.momentum) * 18))
          .clamp(0.0, 100.0)
          .round();

  final int behaviorDivergence =
      ((learningMetrics.completionRate - learningMetrics.momentum).abs() * 100)
          .clamp(0.0, 100.0)
          .round();

  final bool hasTaskData = tasksAsync is AsyncData;
  final String alert = !hasTaskData
      ? 'SI STATUS: trajectory data is temporarily unavailable.'
      : !hasObservedEnergy && pendingTasks == 0
      ? 'SI STATUS: add a current energy check-in before capacity guidance.'
      : pressureIndex >= 70
      ? 'SI ALERT: load is high, reduce task density.'
      : pressureIndex >= 40
      ? 'SI ALERT: trajectory is stable but watch drift.'
      : 'SI STATUS: current load signal is low.';

  final String? predictionTitle = tasksAsync.maybeWhen(
    data: (tasks) => tasks.isEmpty ? null : tasks.first.title,
    orElse: () => null,
  );
  final Prediction? prediction = predictionTitle == null
      ? null
      : ref
            .watch(predictionProvider(predictionTitle))
            .maybeWhen(data: (value) => value, orElse: () => null);
  final TrajectorySourceState sourceState = tasksAsync.hasError
      ? TrajectorySourceState.error
      : tasksAsync.isLoading
      ? TrajectorySourceState.loading
      : pendingTasks == 0 && completedTasks == 0
      ? TrajectorySourceState.empty
      : predictionTitle != null && prediction == null
      ? TrajectorySourceState.partial
      : TrajectorySourceState.ready;
  final TrajectoryRiskBand riskBand = pressureIndex >= 85
      ? TrajectoryRiskBand.critical
      : pressureIndex >= 70
      ? TrajectoryRiskBand.elevated
      : pressureIndex >= 40
      ? TrajectoryRiskBand.watch
      : TrajectoryRiskBand.low;
  final PredictiveConfidenceProfile? predictionConfidence = prediction == null
      ? null
      : PredictiveConfidenceProfile(
          sourceCompleteness: prediction.sampleSize > 0 ? 1 : .35,
          freshness: 1,
          sampleSufficiency: (prediction.sampleSize / 10).clamp(0.0, 1.0),
          intervalPrecision: prediction.safeConfidence,
          calibration: prediction.sampleSize >= 10
              ? PredictiveCalibrationState.monitored
              : PredictiveCalibrationState.provisional,
        );
  final double? intervalMargin = prediction == null
      ? null
      : (.08 + ((1 - prediction.safeConfidence) * .22)).clamp(.08, .3);

  return TrajectorySummaryView(
    pendingTasks: pendingTasks,
    completedTasks: completedTasks,
    completedToday: completedToday,
    level: profile.level,
    streak: profile.streak,
    energy: energy,
    momentum: learningMetrics.momentum,
    adaptability: learningMetrics.adaptability,
    lastCompletionXp: lastCompletionXp,
    lastCompletionQuality: lastCompletionQuality,
    pressureIndex: pressureIndex,
    behaviorDivergence: behaviorDivergence,
    alert: alert,
    sourceState: sourceState,
    riskBand: riskBand,
    statusDetail: alert,
    predictionTitle: predictionTitle,
    predictionOutcome: prediction?.outcome,
    predictionProbability: prediction?.probability,
    predictionExplanation: prediction?.explanation,
    predictionLowerBound: prediction == null
        ? null
        : (prediction.safeProbability - intervalMargin!).clamp(0.0, 1.0),
    predictionUpperBound: prediction == null
        ? null
        : (prediction.safeProbability + intervalMargin!).clamp(0.0, 1.0),
    predictionSampleSize: prediction?.sampleSize ?? 0,
    predictionConfidence: predictionConfidence,
    predictionModelVersion: prediction == null
        ? null
        : 'observed-follow-through-v1',
    personalizationNote:
        'Task ordering reflects the ${personalization.priorityStrategy.name} priority preference. Trajectory scenarios remain deterministic.',
  );
});
