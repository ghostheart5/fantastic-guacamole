import 'package:fantastic_guacamole/domain/trajectory/trajectory_consequence_contract.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_consequence_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AlternativeLifePath {
  const AlternativeLifePath({
    required this.name,
    required this.description,
    required this.tradeoff,
    required this.fitScore,
    required this.confidence,
    required this.baselineRevision,
  });

  final String name;
  final String description;
  final String tradeoff;

  /// Relative scenario fit, not a probability of the future occurring.
  final int fitScore;
  final String confidence;
  final String baselineRevision;
}

final alternativeLifePathsProvider = Provider<List<AlternativeLifePath>>((
  Ref ref,
) {
  final AsyncValue<TrajectoryComparison> async = ref.watch(
    trajectoryConsequenceProvider,
  );
  final TrajectoryComparison? comparison = async.isLoading
      ? null
      : async.asData?.value;
  if (comparison == null || comparison.outcomes.isEmpty) {
    return const <AlternativeLifePath>[];
  }
  final List<TrajectoryScenarioOutcome> outcomes = comparison.outcomes;
  final double highest = outcomes.first.utilityScore;
  final double lowest = outcomes.last.utilityScore;
  final double spread = highest - lowest;
  return outcomes
      .take(4)
      .map((TrajectoryScenarioOutcome outcome) {
        final int fit = spread.abs() < .0001
            ? 50
            : (35 + ((outcome.utilityScore - lowest) / spread * 50)).round();
        final int goalDelay = outcome.goals.fold<int>(
          0,
          (int total, GoalDelayProjection goal) => total + goal.delayDays,
        );
        return AlternativeLifePath(
          name: outcome.intervention.title,
          description: outcome.explanation,
          tradeoff:
              'Risk ${outcome.risk.currentScore}% → ${outcome.risk.projectedScore}%; '
              '$goalDelay projected goal-delay day(s); '
              '${outcome.timeline.displacedSubjectIds.length} displaced commitment(s).',
          fitScore: fit.clamp(0, 100),
          confidence: outcome.confidence.band.name,
          baselineRevision: outcome.baselineRevision,
        );
      })
      .toList(growable: false);
});
