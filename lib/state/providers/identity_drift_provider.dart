import 'package:fantastic_guacamole/domain/predictive/predictive_planning_contract.dart';
import 'package:fantastic_guacamole/state/providers/cognitive_twin_provider.dart';
import 'package:fantastic_guacamole/state/providers/execution_signals_provider.dart';
import 'package:fantastic_guacamole/state/providers/future_self_simulator_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum IdentityAlignment { aligned, drifting, diverging }

class IdentityDriftState {
  const IdentityDriftState({
    required this.alignment,
    required this.score,
    required this.summary,
    required this.correction,
    this.confidence = PredictiveConfidenceBand.low,
    this.evidence = const <String>[],
  });

  final IdentityAlignment alignment;
  final int score;
  final String summary;
  final String correction;
  final PredictiveConfidenceBand confidence;
  final List<String> evidence;
}

final identityDriftProvider = Provider<IdentityDriftState>((ref) {
  final twin = ref.watch(cognitiveTwinProvider);
  final simulations = ref.watch(futureSelfSimulatorProvider);
  final execution = ref.watch(executionSignalsProvider);

  final int modePrior = twin.mode == CognitiveTwinMode.accelerating
      ? 75
      : twin.mode == CognitiveTwinMode.executing
      ? 65
      : twin.mode == CognitiveTwinMode.stabilizing
      ? 52
      : 38;
  final int score =
      ((modePrior * .45) + (execution.completionStability7d * 100 * .55))
          .round()
          .clamp(0, 100);

  final IdentityAlignment alignment = score >= 75
      ? IdentityAlignment.aligned
      : score >= 50
      ? IdentityAlignment.drifting
      : IdentityAlignment.diverging;

  final bool hasObservedOutcomes = execution.actioned7d > 0;
  final String summary = !hasObservedOutcomes
      ? 'Identity alignment is provisional because no recent execution outcomes are available.'
      : alignment == IdentityAlignment.aligned
      ? 'Recent execution is consistent with the current planning direction.'
      : alignment == IdentityAlignment.drifting
      ? 'Recent intent and execution show a measurable gap.'
      : 'Recent outcomes materially diverge from the current planning direction.';

  final String correction = simulations.first.identityShift;

  return IdentityDriftState(
    alignment: alignment,
    score: score,
    summary: summary,
    correction: correction,
    confidence: execution.actioned7d >= 7
        ? PredictiveConfidenceBand.moderate
        : PredictiveConfidenceBand.low,
    evidence: <String>[
      'cognitive_mode=${twin.mode.name}',
      'actioned_7d=${execution.actioned7d}',
      'completion_stability_7d=${execution.completionStability7d.toStringAsFixed(3)}',
    ],
  );
});
