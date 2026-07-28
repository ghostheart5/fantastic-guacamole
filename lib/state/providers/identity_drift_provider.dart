import 'package:fantastic_guacamole/state/providers/cognitive_twin_provider.dart';
import 'package:fantastic_guacamole/state/providers/future_self_simulator_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum IdentityAlignment { aligned, drifting, diverging }

class IdentityDriftState {
  const IdentityDriftState({
    required this.alignment,
    required this.score,
    required this.summary,
    required this.correction,
  });

  final IdentityAlignment alignment;
  final int score;
  final String summary;
  final String correction;
}

final identityDriftProvider = Provider<IdentityDriftState>((ref) {
  final twin = ref.watch(cognitiveTwinProvider);
  final simulations = ref.watch(futureSelfSimulatorProvider);

  final int score = twin.mode == CognitiveTwinMode.accelerating
      ? 85
      : twin.mode == CognitiveTwinMode.executing
      ? 70
      : twin.mode == CognitiveTwinMode.stabilizing
      ? 50
      : 30;

  final IdentityAlignment alignment = score >= 75
      ? IdentityAlignment.aligned
      : score >= 50
      ? IdentityAlignment.drifting
      : IdentityAlignment.diverging;

  final String summary = alignment == IdentityAlignment.aligned
      ? 'Current behavior matches the future identity being developed.'
      : alignment == IdentityAlignment.drifting
      ? 'Small deviations are occurring between intent and execution.'
      : 'Current actions are diverging from the desired future self.';

  final String correction = simulations.first.identityShift;

  return IdentityDriftState(
    alignment: alignment,
    score: score,
    summary: summary,
    correction: correction,
  );
});
