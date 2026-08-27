import 'package:fantastic_guacamole/domain/predictive/predictive_planning_contract.dart';
import 'package:fantastic_guacamole/state/providers/execution_signals_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProgressionIntelligence {
  const ProgressionIntelligence({
    required this.status,
    required this.changedSincePriorWindow,
    required this.whyItMatters,
    required this.nextBestAction,
    required this.confidence,
    required this.evidence,
  });

  final String status;
  final String changedSincePriorWindow;
  final String whyItMatters;
  final String nextBestAction;
  final PredictiveConfidenceProfile confidence;
  final List<String> evidence;
}

final progressionIntelligenceProvider = Provider<ProgressionIntelligence>((
  Ref ref,
) {
  final ExecutionSignals signals = ref.watch(executionSignalsProvider);
  final double? delta = signals.completionTrendDelta;
  final PredictiveConfidenceProfile confidence = PredictiveConfidenceProfile(
    sourceCompleteness: signals.actioned7d == 0 ? .25 : .85,
    freshness: signals.actioned7d == 0 ? .35 : 1,
    sampleSufficiency: (signals.actioned7d / 14).clamp(0.0, 1.0),
    intervalPrecision: delta == null ? .2 : .65,
    calibration: PredictiveCalibrationState.provisional,
  );
  final String change = delta == null
      ? 'No prior seven-day outcome window is available for comparison.'
      : delta >= .1
      ? 'Completion rate improved by ${(delta * 100).round()} percentage points versus the prior seven days.'
      : delta <= -.1
      ? 'Completion rate declined by ${(-delta * 100).round()} percentage points versus the prior seven days.'
      : 'Completion rate is within 10 percentage points of the prior seven-day window.';
  final bool deferralPressure =
      signals.hasDeferralPressure ||
      signals.skipped7d + signals.delayed7d > signals.completed7d;

  return ProgressionIntelligence(
    status: signals.actioned7d == 0
        ? 'Baseline pending'
        : '${(signals.completionRate7d * 100).round()}% observed completion rate',
    changedSincePriorWindow: change,
    whyItMatters: deferralPressure
        ? 'Deferrals currently outnumber or cluster against completions, which weakens reliable forward planning.'
        : 'Observed completions provide the strongest available evidence that the current plan is executable.',
    nextBestAction: deferralPressure
        ? 'Resolve or explicitly reschedule one deferred commitment before adding work.'
        : 'Complete the next feasible high-impact action and record its outcome.',
    confidence: confidence,
    evidence: <String>[
      'completed_7d=${signals.completed7d}',
      'skipped_7d=${signals.skipped7d}',
      'delayed_7d=${signals.delayed7d}',
      'actioned_previous_7d=${signals.actionedPrevious7d}',
    ],
  );
});
