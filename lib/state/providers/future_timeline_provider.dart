import 'package:fantastic_guacamole/domain/predictive/predictive_planning_contract.dart';
import 'package:fantastic_guacamole/domain/trajectory/trajectory_consequence_contract.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_consequence_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FutureTimelineCheckpoint {
  const FutureTimelineCheckpoint({
    required this.label,
    required this.days,
    required this.prediction,
    this.classification = 'Conditional scenario',
    this.confidence = PredictiveConfidenceBand.low,
    this.assumptions = const <String>[],
    this.evidence = const <String>[],
  });

  final String label;
  final int days;
  final String prediction;
  final String classification;
  final PredictiveConfidenceBand confidence;
  final List<String> assumptions;
  final List<String> evidence;
}

class FutureTimelineState {
  const FutureTimelineState({required this.checkpoints});

  final List<FutureTimelineCheckpoint> checkpoints;
}

final futureTimelineProvider = Provider<FutureTimelineState>((ref) {
  final AsyncValue<TrajectoryComparison> async = ref.watch(
    trajectoryConsequenceProvider,
  );
  final TrajectoryComparison? comparison = async.isLoading
      ? null
      : async.asData?.value;
  final TrajectoryScenarioOutcome? selected = comparison?.recommended;
  if (comparison == null || selected == null) {
    return const FutureTimelineState(checkpoints: <FutureTimelineCheckpoint>[]);
  }
  final checkpoints = <FutureTimelineCheckpoint>[];
  for (final int days in const <int>[7, 30, 90]) {
    final TrajectoryIntervention source = selected.intervention;
    final TrajectoryScenarioOutcome outcome = ref
        .watch(futureConsequenceEngineProvider)
        .project(
          baseline: comparison.baseline,
          generatedAt: selected.generatedAt,
          intervention: TrajectoryIntervention(
            id: '${source.id}-$days-days',
            type: source.type,
            title: source.title,
            horizon: Duration(days: days),
            description: source.description,
            subjectId: source.subjectId,
            delay: source.delay,
            proposedBlocks: source.proposedBlocks,
            displacedSubjectIds: source.displacedSubjectIds,
            assumptions: source.assumptions,
          ),
        );
    final int low = (outcome.projectedMomentum - outcome.uncertainty).clamp(
      0,
      100,
    );
    final int high = (outcome.projectedMomentum + outcome.uncertainty).clamp(
      0,
      100,
    );
    checkpoints.add(
      FutureTimelineCheckpoint(
        label: '$days DAYS',
        days: days,
        prediction:
            '${outcome.intervention.title}: momentum $low–$high%, risk ${outcome.risk.band.name}. ${outcome.timeline.summary}',
        classification: days == 90
            ? 'Exploratory conditional scenario'
            : 'Conditional deterministic scenario',
        confidence: outcome.confidence.band,
        assumptions: outcome.assumptions,
        evidence: outcome.evidence,
      ),
    );
  }
  return FutureTimelineState(
    checkpoints: List<FutureTimelineCheckpoint>.unmodifiable(checkpoints),
  );
});
