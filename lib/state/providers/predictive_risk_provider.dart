import 'package:fantastic_guacamole/domain/predictive/predictive_planning_contract.dart';
import 'package:fantastic_guacamole/domain/trajectory/trajectory_consequence_contract.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_consequence_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// CHRONOSPARK-CLASS: INTERNAL ARCHITECTURE ADAPTER
// Not a destination or model-backed prediction. This is a compatibility view
// over the canonical deterministic Trajectory consequence model.

enum PredictiveRiskLevel { unknown, low, medium, high }

class PredictiveRisk {
  const PredictiveRisk({
    required this.title,
    required this.level,
    required this.summary,
    required this.mitigation,
    this.confidence = PredictiveConfidenceBand.low,
    this.evidenceCodes = const <String>[],
  });

  final String title;
  final PredictiveRiskLevel level;
  final String summary;
  final String mitigation;
  final PredictiveConfidenceBand confidence;
  final List<String> evidenceCodes;
}

class PredictiveRiskState {
  const PredictiveRiskState({required this.risks});

  final List<PredictiveRisk> risks;
}

/// Compatibility risk view backed by the same revisioned consequence model as
/// Trajectory Engine. Unknown source state is never represented as low risk.
final predictiveRiskProvider = Provider<PredictiveRiskState>((Ref ref) {
  final AsyncValue<TrajectoryComparison> async = ref.watch(
    trajectoryConsequenceProvider,
  );
  final TrajectoryComparison? comparison = async.isLoading
      ? null
      : async.asData?.value;
  if (comparison == null || comparison.outcomes.isEmpty) {
    return const PredictiveRiskState(
      risks: <PredictiveRisk>[
        PredictiveRisk(
          title: 'Risk evidence unavailable',
          level: PredictiveRiskLevel.unknown,
          summary:
              'No risk conclusion is valid until current planning evidence is reconciled.',
          mitigation: 'Restore current evidence, then recalculate risk.',
          confidence: PredictiveConfidenceBand.insufficientEvidence,
          evidenceCodes: <String>['source_unavailable'],
        ),
      ],
    );
  }
  final TrajectoryScenarioOutcome currentCourse = comparison.outcomes
      .firstWhere(
        (TrajectoryScenarioOutcome outcome) =>
            outcome.intervention.type ==
            TrajectoryInterventionType.maintainCourse,
        orElse: () => comparison.outcomes.first,
      );
  final List<PredictiveRisk> risks =
      currentCourse.risk.contributions
          .map(
            (TrajectoryRiskContribution contribution) => PredictiveRisk(
              title: '${contribution.label} risk',
              level: _riskLevel(contribution.projectedScore),
              summary:
                  '${contribution.explanation} Current ${contribution.currentScore}%; conditional current-course projection ${contribution.projectedScore}%.',
              mitigation: _mitigation(contribution.code),
              confidence: currentCourse.confidence.band,
              evidenceCodes: <String>[
                'baseline=${comparison.baseline.revision}',
                'risk=${contribution.code}',
              ],
            ),
          )
          .toList(growable: false)
        ..sort((PredictiveRisk a, PredictiveRisk b) {
          return b.level.index.compareTo(a.level.index);
        });
  return PredictiveRiskState(risks: List<PredictiveRisk>.unmodifiable(risks));
});

PredictiveRiskLevel _riskLevel(int score) {
  if (score >= 70) return PredictiveRiskLevel.high;
  if (score >= 40) return PredictiveRiskLevel.medium;
  return PredictiveRiskLevel.low;
}

String _mitigation(String code) => switch (code) {
  'pressure' => 'Reduce active load or schedule a recovery block.',
  'deferral' => 'Resolve one deferred commitment before adding another.',
  'deadline' => 'Protect the nearest feasible deadline block on Timeline.',
  'capacity' => 'Apply Smart Planner and reconcile displaced commitments.',
  _ => 'Review the supporting evidence before choosing an intervention.',
};
