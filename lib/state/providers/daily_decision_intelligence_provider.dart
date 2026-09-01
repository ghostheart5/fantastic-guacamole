import 'package:fantastic_guacamole/domain/operating_system/operating_system_contract.dart';
import 'package:fantastic_guacamole/state/providers/momentum_engine_provider.dart';
import 'package:fantastic_guacamole/state/providers/adaptive_replanning_provider.dart';
import 'package:fantastic_guacamole/state/providers/execution_signals_provider.dart';
import 'package:fantastic_guacamole/state/providers/operating_system_provider.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DailyDecisionIntelligence {
  const DailyDecisionIntelligence({
    required this.primaryAction,
    required this.momentum,
    required this.trajectory,
    required this.energy,
    required this.warning,
    required this.recovery,
    required this.recommendedAction,
    required this.rationale,
    required this.changeSummary,
    required this.evidence,
    required this.confidence,
    required this.observedOutcomes,
    this.replanTitle,
    this.replanAction,
  });

  final String primaryAction;
  final String momentum;
  final String trajectory;
  final String energy;
  final String warning;
  final String recovery;
  final String recommendedAction;
  final String rationale;
  final String changeSummary;
  final List<String> evidence;
  final double confidence;
  final int observedOutcomes;
  final String? replanTitle;
  final String? replanAction;
}

final dailyDecisionIntelligenceProvider = Provider<DailyDecisionIntelligence>((
  Ref ref,
) {
  final momentum = ref.watch(momentumEngineProvider);
  final replans = ref.watch(adaptiveReplanningProvider);
  final trajectory = ref.watch(trajectorySummaryProvider);
  final ExecutionSignals execution = ref.watch(executionSignalsProvider);
  final AsyncValue<DecisionIntelligence> intelligenceAsync = ref.watch(
    decisionIntelligenceProvider,
  );
  final DecisionIntelligence? intelligence = intelligenceAsync.asData?.value;
  final OperatingDecisionReceipt? currentDecision = intelligence?.decision;
  final OperatingDecisionReceipt? decision = currentDecision?.isExpired == true
      ? null
      : currentDecision;
  final replan = replans.isEmpty ? null : replans.first;

  final String fallbackAction =
      replan?.immediateAction ??
      (intelligenceAsync.hasError
          ? 'Review unavailable decision evidence in SI Console.'
          : intelligenceAsync.isLoading
          ? 'Wait for current decision evidence before changing the plan.'
          : trajectory.pendingTasks == 0
          ? 'Capture one meaningful commitment in Creator.'
          : momentum.hasObservedEnergy && momentum.energyPercent < 35
          ? 'Choose the smallest feasible step from the current plan.'
          : 'Open Smart Planner to rank the next feasible action.');
  final String primaryAction = decision?.recommendedAction ?? fallbackAction;

  final String trajectoryText =
      trajectory.predictionOutcome ?? 'Future path is still stabilizing.';

  final String warning = intelligenceAsync.hasError
      ? 'Decision evidence is unavailable. ChronoSpark is not treating missing data as a clear plan.'
      : intelligenceAsync.isLoading
      ? 'Decision evidence is still loading; constraints are not yet resolved.'
      : decision?.warnings.isNotEmpty == true
      ? decision!.warnings.first
      : execution.hasDeferralPressure
      ? 'Recent deferrals show that the current plan needs less load or a smaller next step.'
      : momentum.pressurePercent >= 75
      ? 'Available time and current load are in conflict. Reduce or move work before adding more.'
      : 'No material constraint is supported by the current evidence.';

  final String recovery = momentum.recovery;

  final String recommendedAction =
      decision?.recommendedAction ?? fallbackAction;
  final List<String> evidence = decision == null
      ? <String>[
          'momentum=${momentum.score}',
          'pressure=${momentum.pressurePercent}',
          if (momentum.hasObservedEnergy)
            'energy=${momentum.energyPercent}'
          else
            'energy=unavailable',
          'completed_7d=${execution.completed7d}',
          'deferred_7d=${execution.skipped7d + execution.delayed7d}',
        ]
      : decision.evidence
            .map((OperatingEvidence item) => item.description)
            .toList(growable: false);
  final double confidence =
      decision?.recommendationConfidence ??
      (execution.actioned7d == 0 ? .2 : .4);

  return DailyDecisionIntelligence(
    primaryAction: primaryAction,
    momentum: '${momentum.score}% ${momentum.trend}',
    trajectory: trajectoryText,
    energy: momentum.hasObservedEnergy
        ? '${momentum.energyPercent}% energy'
        : 'Energy not checked',
    warning: warning,
    recovery: recovery,
    recommendedAction: recommendedAction,
    rationale:
        decision?.rationale ??
        'The current recommendation is provisional until task, schedule, and outcome evidence is ready.',
    changeSummary:
        intelligence?.delta.summary ??
        'Waiting for a comparable planning state.',
    evidence: evidence,
    confidence: confidence,
    observedOutcomes: execution.actioned7d,
    replanTitle: replan?.title,
    replanAction: replan?.immediateAction,
  );
});
