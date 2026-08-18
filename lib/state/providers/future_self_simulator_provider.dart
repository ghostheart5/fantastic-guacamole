import 'package:fantastic_guacamole/domain/predictive/predictive_planning_contract.dart';
import 'package:fantastic_guacamole/domain/trajectory/trajectory_consequence_contract.dart';
import 'package:fantastic_guacamole/state/providers/execution_signals_provider.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum FutureSelfPath { maintain, recover, accelerate }

class FutureSelfSimulation {
  const FutureSelfSimulation({
    required this.path,
    required this.horizon,
    required this.identityShift,
    required this.projectedDirection,
    required this.assumptions,
    required this.confidence,
  });

  final FutureSelfPath path;
  final Duration horizon;
  final String identityShift;
  final String projectedDirection;
  final List<String> assumptions;
  final PredictiveConfidenceProfile confidence;
}

/// Produces bounded, explanation-first future paths. These are directional
/// scenarios, not promised outcomes or fabricated success probabilities.
final futureSelfSimulatorProvider = Provider<List<FutureSelfSimulation>>((
  Ref ref,
) {
  final trajectory = ref.watch(trajectorySummaryProvider);
  final ExecutionSignals execution = ref.watch(executionSignalsProvider);
  final double sample = (execution.actioned7d / 7).clamp(0.0, 1.0);
  final PredictiveConfidenceProfile confidence = PredictiveConfidenceProfile(
    sourceCompleteness: trajectory.sourceState == TrajectorySourceState.ready
        ? .75
        : .4,
    freshness: 1,
    sampleSufficiency: sample,
    intervalPrecision: .5,
    calibration: PredictiveCalibrationState.provisional,
  );
  final bool overloaded = trajectory.pressureIndex >= 70;
  final bool stable = execution.completionStability7d >= .6;

  return <FutureSelfSimulation>[
    FutureSelfSimulation(
      path: FutureSelfPath.recover,
      horizon: const Duration(days: 7),
      identityShift: overloaded
          ? 'Reduce active scope, protect the highest-value commitment, and rebuild one reliable completion loop.'
          : 'Protect one repeatable daily completion before adding more commitments.',
      projectedDirection: overloaded
          ? 'Lower pressure and restore schedule slack.'
          : 'Build a stronger observed execution baseline.',
      assumptions: const <String>[
        'The user reviews and accepts any schedule change.',
        'No unrecorded fixed commitments consume the protected time.',
      ],
      confidence: confidence,
    ),
    FutureSelfSimulation(
      path: FutureSelfPath.maintain,
      horizon: const Duration(days: 14),
      identityShift:
          'Keep current commitments bounded and review drift after each recorded outcome.',
      projectedDirection: stable
          ? 'Preserve current execution stability.'
          : 'Current instability may persist without a smaller recovery action.',
      assumptions: const <String>[
        'Current workload and energy remain broadly comparable.',
      ],
      confidence: confidence,
    ),
    FutureSelfSimulation(
      path: FutureSelfPath.accelerate,
      horizon: const Duration(days: 30),
      identityShift:
          'Expand scope only after the current completion pattern is stable and capacity remains available.',
      projectedDirection: stable && !overloaded
          ? 'Increase throughput without sacrificing reliability.'
          : 'Acceleration is not currently supported by enough stable evidence.',
      assumptions: const <String>[
        'Acceleration begins only after capacity and stability gates pass.',
      ],
      confidence: confidence,
    ),
  ];
});
