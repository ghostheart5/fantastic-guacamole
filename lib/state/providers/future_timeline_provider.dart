import 'package:fantastic_guacamole/domain/entities/completion_event_entity.dart';
import 'package:fantastic_guacamole/state/providers/future_decision_engine_provider.dart';
import 'package:fantastic_guacamole/state/providers/identity_drift_provider.dart';
import 'package:fantastic_guacamole/state/providers/completion_events_provider.dart';
import 'package:fantastic_guacamole/state/providers/execution_signals_provider.dart';
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
  final execution = ref.watch(executionSignalsProvider);
  final completionEvents = ref.watch(completionEventsProvider);
  final int stabilityPercent = (execution.completionStability7d * 100).round();
  final int completedCount = completionEvents
      .where((event) => event.eventType == CompletionEventType.completed)
      .length;
  final int deferralCount = completionEvents
      .where(
        (event) =>
            event.eventType == CompletionEventType.skipped ||
            event.eventType == CompletionEventType.notCompleted ||
            event.eventType == CompletionEventType.overdue,
      )
      .length;

  final checkpoints = <FutureTimelineCheckpoint>[
    FutureTimelineCheckpoint(
      label: '7 DAYS',
      days: 7,
      prediction: execution.hasDeferralPressure
          ? 'Recent deferrals are elevated ($deferralCount events). Complete delayed items before adding new commitments.'
          : 'Consistent execution of "${decision.recommendedChoice}" increases stability ($completedCount completion events).',
    ),
    FutureTimelineCheckpoint(
      label: '30 DAYS',
      days: 30,
      prediction: drift.score >= 70
          ? 'Identity alignment strengthens and momentum compounds (stability $stabilityPercent%).'
          : 'Corrections will be required to maintain future alignment (stability $stabilityPercent%).',
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
