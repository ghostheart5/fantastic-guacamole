import 'package:fantastic_guacamole/engine/advisor/product_advisor_engine.dart';
import 'package:fantastic_guacamole/state/controllers/momentum_controller.dart';
import 'package:fantastic_guacamole/state/providers/execution_signals_provider.dart';
import 'package:fantastic_guacamole/state/providers/goals_provider.dart';
import 'package:fantastic_guacamole/state/providers/milestones_provider.dart';
import 'package:fantastic_guacamole/state/providers/optimization_provider.dart';
import 'package:fantastic_guacamole/state/providers/task_provider.dart';
import 'package:fantastic_guacamole/state/providers/timeline_provider.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final productRecommendationsProvider =
    FutureProvider<List<ProductRecommendation>>((ref) async {
      try {
        final accumulator = ref.read(localMetricsAccumulatorProvider);
        final snapshot = await accumulator.snapshot();
        final momentum = ref.watch(momentumProvider);
        return const ProductAdvisorEngine().fromSnapshot(
          snapshot,
          momentum.chainCount,
        );
      } catch (_) {
        return const ProductAdvisorEngine().analyze(
          nextSeen: 0,
          started: 0,
          completed: 0,
          momentumPeak: 0,
        );
      }
    });

final weeklySummaryProvider = FutureProvider<String>((ref) async {
  final ExecutionSignals execution = ref.watch(executionSignalsProvider);
  final trajectory = ref.watch(trajectorySummaryProvider);
  final int timelineHealth = ref.watch(timelineHealthScoreProvider);
  final int timelineRisk = ref.watch(timelineRiskScoreProvider);
  final int overdue = ref.watch(timelineOverdueProvider).length;
  final milestoneSummary = ref.watch(milestoneSummaryProvider);
  final int activeGoals = ref.watch(goalsProvider).length;
  final int activeTasks = ref.watch(tasksProvider).asData?.value.length ?? 0;

  return buildProgressionReview(
    execution: execution,
    pressureIndex: trajectory.pressureIndex,
    timelineHealth: timelineHealth,
    timelineRisk: timelineRisk,
    overdue: overdue,
    milestoneHealth: milestoneSummary.healthScore,
    milestoneOverdue: milestoneSummary.overdue,
    activeGoals: activeGoals,
    activeTasks: activeTasks,
  );
});

String buildProgressionReview({
  required ExecutionSignals execution,
  required int pressureIndex,
  required int timelineHealth,
  required int timelineRisk,
  required int overdue,
  required int milestoneHealth,
  required int milestoneOverdue,
  required int activeGoals,
  required int activeTasks,
}) {
  final int actioned = execution.actioned7d;
  final int completed = execution.completed7d;
  final double completionRate = actioned <= 0
      ? 0
      : (completed / actioned).clamp(0.0, 1.0).toDouble();

  final String executionState = actioned == 0
      ? 'A seven-day follow-through baseline is not available yet'
      : completionRate >= 0.75
      ? 'Execution is reliable'
      : completionRate >= 0.45
      ? 'Execution is unstable'
      : 'Execution is breaking down';

  final String pressureState = pressureIndex >= 75
      ? 'Pressure is critical'
      : pressureIndex >= 55
      ? 'Pressure is elevated'
      : 'Pressure is manageable';

  final String timelineState = overdue > 0 || timelineHealth < 65
      ? 'Timeline integrity is at risk'
      : 'Timeline integrity is stable';

  final String milestoneState = milestoneOverdue > 0
      ? 'Milestone drift detected'
      : milestoneHealth >= 70
      ? 'Milestones are on-track'
      : 'Milestones need tighter execution';

  final String oneAction = overdue > 0
      ? 'Clear one overdue timeline item before adding anything new.'
      : pressureIndex >= 70
      ? 'Shrink scope to one critical block and finish it today.'
      : completionRate < 0.5
      ? 'Complete one started task fully before opening another.'
      : 'Keep momentum by finishing one high-impact task now.';

  final String completionDetail = actioned == 0
      ? 'No completed, skipped, or delayed outcomes were recorded in this window.'
      : '$completed of $actioned recorded outcomes were completed '
            '(${(completionRate * 100).round()}%).';

  return 'PROGRESS REVIEW\n\n'
      '$executionState. $completionDetail '
      '$pressureState (index $pressureIndex). '
      '$timelineState (health $timelineHealth%, risk $timelineRisk%, overdue $overdue). '
      '$milestoneState (health $milestoneHealth%, overdue $milestoneOverdue).\n\n'
      'Active workload: $activeTasks tasks across $activeGoals goals.\n'
      'Next practice: $oneAction';
}
