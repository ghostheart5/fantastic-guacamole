import 'package:fantastic_guacamole/domain/operating_system/operating_system_contract.dart';
import 'package:fantastic_guacamole/domain/trajectory/trajectory_consequence_contract.dart';
import 'package:fantastic_guacamole/state/providers/execution_signals_provider.dart';
import 'package:fantastic_guacamole/state/providers/operating_system_provider.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum IntelligenceOperatingMode {
  recovery,
  stabilization,
  execution,
  acceleration,
}

class IntelligenceFusionState {
  const IntelligenceFusionState({
    required this.mode,
    required this.nextAction,
    required this.primaryConstraint,
    required this.rationale,
    required this.evidence,
    required this.confidence,
  });

  final IntelligenceOperatingMode mode;
  final String nextAction;
  final String primaryConstraint;
  final String rationale;
  final List<String> evidence;
  final double confidence;

  String get operatingMode => switch (mode) {
    IntelligenceOperatingMode.recovery => 'Recovery',
    IntelligenceOperatingMode.stabilization => 'Stabilization',
    IntelligenceOperatingMode.execution => 'Execution',
    IntelligenceOperatingMode.acceleration => 'Acceleration',
  };
}

/// Fuses the current operating receipt with local trajectory and execution
/// outcomes. It never invents probabilities; confidence reflects source
/// coverage and observed outcomes only.
final intelligenceFusionProvider = Provider<IntelligenceFusionState>((Ref ref) {
  final trajectory = ref.watch(trajectorySummaryProvider);
  final ExecutionSignals execution = ref.watch(executionSignalsProvider);
  final AsyncValue<DecisionIntelligence> decisionAsync = ref.watch(
    decisionIntelligenceProvider,
  );
  final DecisionIntelligence? intelligence = decisionAsync.asData?.value;

  final IntelligenceOperatingMode mode =
      trajectory.energy <= .3 || trajectory.pressureIndex >= 85
      ? IntelligenceOperatingMode.recovery
      : execution.hasDeferralPressure || trajectory.pressureIndex >= 65
      ? IntelligenceOperatingMode.stabilization
      : trajectory.momentum >= .7 && trajectory.pressureIndex < 55
      ? IntelligenceOperatingMode.acceleration
      : IntelligenceOperatingMode.execution;

  final String nextAction =
      intelligence?.decision.recommendedAction ??
      (trajectory.pendingTasks == 0
          ? 'Capture one accountable action in Creator.'
          : 'Open Smart Planner to rank the next feasible action.');
  final String primaryConstraint =
      intelligence?.snapshot.activeRisks.isNotEmpty == true
      ? intelligence!.snapshot.activeRisks.first
      : trajectory.pressureIndex >= 70
      ? 'Current load is compressing schedule flexibility.'
      : execution.hasDeferralPressure
      ? 'Repeated deferral is weakening execution stability.'
      : 'No material constraint is supported by current local evidence.';
  final int observedOutcomes = execution.actioned7d;
  final double coverage =
      intelligence?.snapshot.evidenceCoverage ??
      (trajectory.sourceState == TrajectorySourceState.ready ? .65 : .3);
  final double confidence =
      (coverage * .7 + (observedOutcomes.clamp(0, 7) / 7) * .3).clamp(0.0, 1.0);

  return IntelligenceFusionState(
    mode: mode,
    nextAction: nextAction,
    primaryConstraint: primaryConstraint,
    rationale:
        intelligence?.decision.rationale ??
        'The recommendation uses local load, momentum, and recent execution evidence.',
    evidence: <String>[
      'pressure=${trajectory.pressureIndex}',
      'momentum=${trajectory.momentum.toStringAsFixed(3)}',
      'outcomes_7d=$observedOutcomes',
      'coverage=${coverage.toStringAsFixed(3)}',
    ],
    confidence: confidence,
  );
});
