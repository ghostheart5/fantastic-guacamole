import 'package:fantastic_guacamole/domain/predictive/predictive_planning_contract.dart';
import 'package:fantastic_guacamole/state/providers/execution_signals_provider.dart';
import 'package:fantastic_guacamole/state/providers/momentum_engine_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AdaptiveReplanningType {
  missedCommitment,
  overloadedDay,
  lowEnergy,
  momentumRecovery,
  courseProtection,
}

class AdaptiveReplanningScenario {
  const AdaptiveReplanningScenario({
    required this.type,
    required this.title,
    required this.summary,
    required this.immediateAction,
    required this.recoveryMove,
    required this.dailyAdjustment,
    required this.moves,
    required this.evidence,
    required this.confidence,
    this.subjectId,
  });

  final AdaptiveReplanningType type;
  final String title;
  final String summary;
  final String immediateAction;
  final String recoveryMove;
  final String dailyAdjustment;
  final List<String> moves;
  final List<String> evidence;
  final PredictiveConfidenceProfile confidence;
  final String? subjectId;
}

final adaptiveReplanningProvider = Provider<List<AdaptiveReplanningScenario>>((
  Ref ref,
) {
  final MomentumEngineState momentum = ref.watch(momentumEngineProvider);
  final ExecutionSignals execution = ref.watch(executionSignalsProvider);
  final List<AdaptiveReplanningScenario> scenarios =
      <AdaptiveReplanningScenario>[];

  PredictiveConfidenceProfile confidence({required double precision}) =>
      PredictiveConfidenceProfile(
        sourceCompleteness: execution.actioned7d == 0 ? .35 : .8,
        freshness: 1,
        sampleSufficiency: (execution.actioned7d / 10).clamp(0.0, 1.0),
        intervalPrecision: precision,
        calibration: PredictiveCalibrationState.provisional,
      );

  if (execution.delayedToday + execution.skippedToday > 0) {
    scenarios.add(
      AdaptiveReplanningScenario(
        type: AdaptiveReplanningType.missedCommitment,
        title: 'Missed Commitment Recovery',
        summary:
            'Today has ${execution.delayedToday + execution.skippedToday} recorded deferral(s). Recover the most consequential one before adding work.',
        immediateAction:
            'Choose the highest-priority deferred commitment and reduce it to one finishable step.',
        recoveryMove:
            'Restore execution evidence with one completed step, then reassess the remaining load.',
        dailyAdjustment:
            'Move lower-priority commitments instead of silently carrying every item forward.',
        moves: const <String>[
          'Select the highest-consequence deferred item.',
          'Reduce it to a finishable next step.',
          'Reconcile the remaining day after that step.',
        ],
        evidence: <String>[
          'delayed_today=${execution.delayedToday}',
          'skipped_today=${execution.skippedToday}',
        ],
        confidence: confidence(precision: .7),
      ),
    );
  }

  if (momentum.pressurePercent >= 70 || execution.hasDeferralPressure) {
    scenarios.add(
      AdaptiveReplanningScenario(
        type: AdaptiveReplanningType.overloadedDay,
        title: 'Capacity Protection',
        summary:
            'Current pressure or deferral evidence indicates that active scope should be reduced before more work is accepted.',
        immediateAction:
            'Defer one low-impact commitment and preserve the next feasible execution window.',
        recoveryMove:
            'Lower competing demand before attempting another high-load action.',
        dailyAdjustment:
            'Keep only work that fits the remaining capacity; record every displacement explicitly.',
        moves: const <String>[
          'Defer one low-impact commitment.',
          'Keep the highest-consequence action.',
          'Preserve a recovery buffer.',
        ],
        evidence: <String>[
          'pressure_percent=${momentum.pressurePercent}',
          'deferrals_today=${execution.skippedToday + execution.delayedToday}',
        ],
        confidence: confidence(precision: .72),
      ),
    );
  }

  if (momentum.hasObservedEnergy && momentum.energyPercent < 45) {
    scenarios.add(
      AdaptiveReplanningScenario(
        type: AdaptiveReplanningType.lowEnergy,
        title: 'Low-Energy Rebuild',
        summary:
            'Energy is ${momentum.energyPercent}%. A smaller useful action is safer than claiming full-load capacity.',
        immediateAction:
            'Choose the smallest useful action that fits the current energy level.',
        recoveryMove:
            'Use completion evidence, not intensity, to decide whether to increase load.',
        dailyAdjustment:
            'Split high-load work into a checkpoint and defer the remainder if energy stays low.',
        moves: const <String>[
          'Choose one low-load action.',
          'Complete its first meaningful checkpoint.',
          'Reassess energy before increasing load.',
        ],
        evidence: <String>['energy_percent=${momentum.energyPercent}'],
        confidence: confidence(precision: .65),
      ),
    );
  }

  if (momentum.trend == 'Declining' || momentum.score < 45) {
    scenarios.add(
      AdaptiveReplanningScenario(
        type: AdaptiveReplanningType.momentumRecovery,
        title: 'Momentum Recovery',
        summary: momentum.trendDelta == null
            ? 'Current momentum is low, but there is not yet enough prior-window evidence to claim a trend.'
            : 'The current seven-day completion rate is below the prior comparison window.',
        immediateAction:
            'Close one important open loop before creating another commitment.',
        recoveryMove:
            'Use the next observed outcome to decide whether the plan should contract further.',
        dailyAdjustment:
            'Limit context switching and keep the next action explicit.',
        moves: const <String>[
          'Finish one open loop.',
          'Avoid opening another large commitment.',
          'Recalculate after the outcome is recorded.',
        ],
        evidence: <String>[
          'momentum_score=${momentum.score}',
          if (momentum.trendDelta != null)
            'completion_rate_delta=${momentum.trendDelta!.toStringAsFixed(3)}',
        ],
        confidence: confidence(
          precision: momentum.trendDelta == null ? .35 : .7,
        ),
      ),
    );
  }

  if (scenarios.isEmpty) {
    scenarios.add(
      AdaptiveReplanningScenario(
        type: AdaptiveReplanningType.courseProtection,
        title: 'Course Protection',
        summary: execution.actioned7d == 0
            ? 'No outcome history is available yet. Preserve a narrow plan while the system establishes a baseline.'
            : 'No current recovery trigger is supported by the available signals.',
        immediateAction:
            'Continue with the current highest-impact feasible action.',
        recoveryMove:
            'Replan only when a completion, deferral, energy, or capacity signal changes.',
        dailyAdjustment:
            'Avoid unnecessary plan churn and record the next outcome.',
        moves: const <String>[
          'Execute the current next action.',
          'Record the outcome.',
          'Recalculate only when evidence changes.',
        ],
        evidence: <String>[
          'momentum_score=${momentum.score}',
          'actioned_7d=${execution.actioned7d}',
        ],
        confidence: confidence(precision: .5),
      ),
    );
  }

  return List<AdaptiveReplanningScenario>.unmodifiable(scenarios.take(3));
});
