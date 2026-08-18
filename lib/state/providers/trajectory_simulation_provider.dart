import 'package:fantastic_guacamole/domain/predictive/predictive_planning_contract.dart';
import 'package:fantastic_guacamole/domain/trajectory/trajectory_consequence_contract.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_consequence_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum TrajectorySimulationType {
  momentumBoost,
  recoveryPlan,
  protectedExecutionBlock,
  goalReduction,
  driftWarning,
}

/// Presentation compatibility model backed by a typed consequence outcome.
class TrajectorySimulationResult {
  const TrajectorySimulationResult({
    required this.type,
    required this.title,
    required this.summary,
    required this.projectedMomentum,
    required this.projectedPressure,
    required this.projectedRecovery,
    required this.projectedOutcome,
    this.classification = 'Unverified compatibility fixture',
    this.confidence = 'Low',
    this.assumptions = const <String>[],
    this.modelVersion = 'trajectory-compatibility-v1',
    this.generatedAt,
    this.uncertainty = 18,
    this.evidence = const <String>[],
    this.baselineRevision,
    this.horizon = const Duration(days: 7),
    this.risk,
    this.timeline,
    this.goalDelays = const <GoalDelayProjection>[],
    this.progression,
    this.isRecommended = false,
  });

  final TrajectorySimulationType type;
  final String title;
  final String summary;
  final int projectedMomentum;
  final int projectedPressure;
  final String projectedRecovery;
  final String projectedOutcome;
  final String classification;
  final String confidence;
  final List<String> assumptions;
  final String modelVersion;
  final DateTime? generatedAt;
  final int uncertainty;
  final List<String> evidence;
  final String? baselineRevision;
  final Duration horizon;
  final TrajectoryRiskProjection? risk;
  final TimelineConsequence? timeline;
  final List<GoalDelayProjection> goalDelays;
  final ProgressionConsequence? progression;
  final bool isRecommended;

  String get momentumRange => _range(projectedMomentum, uncertainty);
  String get pressureRange => _range(projectedPressure, uncertainty);

  static String _range(int center, int uncertainty) {
    final int low = (center - uncertainty).clamp(0, 100);
    final int high = (center + uncertainty).clamp(0, 100);
    return '$low–$high%';
  }
}

final trajectorySimulationProvider = Provider<List<TrajectorySimulationResult>>(
  (Ref ref) {
    final AsyncValue<TrajectoryComparison> comparisonAsync = ref.watch(
      trajectoryConsequenceProvider,
    );
    final TrajectoryComparison? comparison = comparisonAsync.isLoading
        ? null
        : comparisonAsync.asData?.value;
    if (comparison == null) return const <TrajectorySimulationResult>[];
    return comparison.outcomes
        .map(
          (TrajectoryScenarioOutcome outcome) => _toPresentation(
            outcome,
            baseline: comparison.baseline,
            isRecommended: outcome.id == comparison.recommendedScenarioId,
          ),
        )
        .toList(growable: false);
  },
);

TrajectorySimulationResult _toPresentation(
  TrajectoryScenarioOutcome outcome, {
  required TrajectoryBaseline baseline,
  required bool isRecommended,
}) {
  final TrajectorySimulationType type = switch (outcome.intervention.type) {
    TrajectoryInterventionType.maintainCourse ||
    TrajectoryInterventionType.delayTask =>
      TrajectorySimulationType.driftWarning,
    TrajectoryInterventionType.applySmartPlanner =>
      TrajectorySimulationType.protectedExecutionBlock,
    TrajectoryInterventionType.completeTask =>
      TrajectorySimulationType.momentumBoost,
    TrajectoryInterventionType.reduceScope =>
      TrajectorySimulationType.goalReduction,
    TrajectoryInterventionType.recoverCommitment =>
      TrajectorySimulationType.recoveryPlan,
  };
  final String recovery = switch (outcome.risk.band) {
    TrajectoryRiskBand.critical => 'Recovery required',
    TrajectoryRiskBand.elevated => 'Recovery recommended',
    TrajectoryRiskBand.watch => 'Watch load',
    TrajectoryRiskBand.low => 'Stable',
    TrajectoryRiskBand.unknown => 'Unknown',
  };
  return TrajectorySimulationResult(
    type: type,
    title: outcome.intervention.title,
    summary: outcome.intervention.description,
    projectedMomentum: outcome.projectedMomentum,
    projectedPressure: outcome.projectedPressure,
    projectedRecovery: recovery,
    projectedOutcome: outcome.explanation,
    classification: 'Conditional deterministic scenario',
    confidence: _confidenceLabel(outcome.confidence.band),
    assumptions: outcome.assumptions,
    modelVersion: outcome.modelVersion,
    generatedAt: outcome.generatedAt,
    uncertainty: outcome.uncertainty,
    evidence: outcome.evidence,
    baselineRevision: outcome.baselineRevision,
    horizon: outcome.intervention.horizon,
    risk: outcome.risk,
    timeline: outcome.timeline,
    goalDelays: outcome.goals,
    progression: outcome.progression,
    isRecommended: isRecommended,
  );
}

String _confidenceLabel(PredictiveConfidenceBand band) => switch (band) {
  PredictiveConfidenceBand.high => 'High',
  PredictiveConfidenceBand.moderate => 'Moderate',
  PredictiveConfidenceBand.low => 'Low',
  PredictiveConfidenceBand.insufficientEvidence => 'Insufficient evidence',
};
