import 'package:fantastic_guacamole/domain/predictive/predictive_planning_contract.dart';
import 'package:fantastic_guacamole/domain/trajectory/trajectory_consequence_contract.dart';

class TrajectorySummaryView {
  const TrajectorySummaryView({
    required this.pendingTasks,
    required this.completedTasks,
    required this.completedToday,
    required this.level,
    required this.streak,
    required this.energy,
    required this.momentum,
    required this.adaptability,
    required this.lastCompletionXp,
    required this.lastCompletionQuality,
    required this.pressureIndex,
    required this.behaviorDivergence,
    required this.alert,
    required this.predictionTitle,
    required this.predictionOutcome,
    required this.predictionProbability,
    required this.predictionExplanation,
    this.sourceState = TrajectorySourceState.ready,
    this.riskBand = TrajectoryRiskBand.unknown,
    this.statusDetail = '',
    this.predictionLowerBound,
    this.predictionUpperBound,
    this.predictionSampleSize = 0,
    this.predictionConfidence,
    this.predictionModelVersion,
    this.personalizationNote,
  });

  final int pendingTasks;
  final int completedTasks;
  final int completedToday;
  final int level;
  final int streak;
  final double energy;
  final double momentum;
  final double adaptability;
  final int lastCompletionXp;
  final double lastCompletionQuality;
  final int pressureIndex;
  final int behaviorDivergence;
  final String alert;
  final String? predictionTitle;
  final String? predictionOutcome;
  final double? predictionProbability;
  final String? predictionExplanation;
  final TrajectorySourceState sourceState;
  final TrajectoryRiskBand riskBand;
  final String statusDetail;
  final double? predictionLowerBound;
  final double? predictionUpperBound;
  final int predictionSampleSize;
  final PredictiveConfidenceProfile? predictionConfidence;
  final String? predictionModelVersion;
  final String? personalizationNote;

  bool get hasPrediction =>
      predictionTitle != null &&
      predictionOutcome != null &&
      predictionProbability != null &&
      predictionExplanation != null;

  bool get predictionEvidenceSufficient =>
      predictionProbability != null &&
      predictionSampleSize >= 10 &&
      predictionConfidence?.band != PredictiveConfidenceBand.low &&
      predictionConfidence?.band !=
          PredictiveConfidenceBand.insufficientEvidence;
}
