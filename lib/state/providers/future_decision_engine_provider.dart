import 'package:fantastic_guacamole/domain/predictive/predictive_planning_contract.dart';
import 'package:fantastic_guacamole/state/providers/cognitive_twin_provider.dart';
import 'package:fantastic_guacamole/state/providers/execution_signals_provider.dart';
import 'package:fantastic_guacamole/state/providers/identity_drift_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FutureDecision {
  const FutureDecision({
    required this.recommendedChoice,
    required this.reason,
    required this.alignmentScore,
    this.confidence = PredictiveConfidenceBand.low,
    this.evidence = const <String>[],
    this.modelVersion = 'future-decision-v2',
  });

  final String recommendedChoice;
  final String reason;
  final int alignmentScore;
  final PredictiveConfidenceBand confidence;
  final List<String> evidence;
  final String modelVersion;
}

final futureDecisionEngineProvider = Provider<FutureDecision>((ref) {
  final twin = ref.watch(cognitiveTwinProvider);
  final drift = ref.watch(identityDriftProvider);
  final execution = ref.watch(executionSignalsProvider);

  final int alignmentScore = drift.score.clamp(0, 100);

  final String recommendation = twin.bestAction;

  final String reason = execution.actioned7d == 0
      ? 'This is a provisional action based on your current planning pattern; recent outcome evidence is not yet available.'
      : 'This action aligns with your current planning pattern and a ${(execution.completionStability7d * 100).round()}% observed seven-day completion rate.';

  return FutureDecision(
    recommendedChoice: recommendation,
    reason: reason,
    alignmentScore: alignmentScore,
    confidence: drift.confidence,
    evidence: <String>[
      ...drift.evidence,
      'recommended_action_source=cognitive_twin',
    ],
  );
});
