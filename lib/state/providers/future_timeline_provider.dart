import 'package:fantastic_guacamole/state/providers/future_decision_engine_provider.dart';
import 'package:fantastic_guacamole/state/providers/identity_drift_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FutureTimelineCheckpoint {
  const FutureTimelineCheckpoint({
    required this.label,
    required this.days,
    required this.prediction,
  });

  final String label;
  final int days;
  final String prediction;
}

class FutureTimelineState {
  const FutureTimelineState({required this.checkpoints});

  final List<FutureTimelineCheckpoint> checkpoints;
}

final futureTimelineProvider = Provider<FutureTimelineState>((ref) {
  final decision = ref.watch(futureDecisionEngineProvider);
  final drift = ref.watch(identityDriftProvider);

  final checkpoints = <FutureTimelineCheckpoint>[
    FutureTimelineCheckpoint(
      label: '7 DAYS',
      days: 7,
      prediction:
          'Consistent execution of "${decision.recommendedChoice}" increases stability.',
    ),
    FutureTimelineCheckpoint(
      label: '30 DAYS',
      days: 30,
      prediction: drift.score >= 70
          ? 'Identity alignment strengthens and momentum compounds.'
          : 'Corrections will be required to maintain future alignment.',
    ),
    const FutureTimelineCheckpoint(
      label: '90 DAYS',
      days: 90,
      prediction:
          'Current behavioral trajectory becomes increasingly reinforced.',
    ),
  ];

  return FutureTimelineState(checkpoints: checkpoints);
});
