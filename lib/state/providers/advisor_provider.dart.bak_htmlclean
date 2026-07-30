import 'package:fantastic_guacamole/engine/advisor/product_advisor_engine.dart';
import 'package:fantastic_guacamole/engine/advisor/weekly_advisor.dart';
import 'package:fantastic_guacamole/state/controllers/momentum_controller.dart';
import 'package:fantastic_guacamole/state/providers/goals_provider.dart';
import 'package:fantastic_guacamole/state/providers/milestones_provider.dart';
import 'package:fantastic_guacamole/state/providers/optimization_provider.dart';
import 'package:fantastic_guacamole/state/providers/task_provider.dart';
import 'package:fantastic_guacamole/state/providers/timeline_provider.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final productInsightsProvider = FutureProvider<List<ProductInsight>>((
  ref,
) async {
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
  try {
    final snapshot = await ref.read(localMetricsAccumulatorProvider).snapshot();
    final insights = await ref.watch(productInsightsProvider.future);
    final String baseline = const WeeklyAdvisor().summarize(insights);

    final trajectory = ref.watch(trajectorySummaryProvider);
    final int timelineHealth = ref.watch(timelineHealthScoreProvider);
    final int timelineRisk = ref.watch(timelineRiskScoreProvider);
    final int overdue = ref.watch(timelineOverdueProvider).length;
    final milestoneSummary = ref.watch(milestoneSummaryProvider);
    final int activeGoals = ref.watch(goalsProvider).length;
    final int activeTasks = ref.watch(tasksProvider).asData?.value.length ?? 0;

    final int started = (snapshot['started'] as num?)?.toInt() ?? 0;
    final int completed = (snapshot['completed'] as num?)?.toInt() ?? 0;
    final double completionRate = started <= 0
        ? 0
        : (completed / started).clamp(0.0, 1.0).toDouble();

    final String executionState = completionRate >= 0.75
        ? 'Execution is reliable'
        : completionRate >= 0.45
        ? 'Execution is unstable'
        : 'Execution is breaking down';

    final String pressureState = trajectory.pressureIndex >= 75
        ? 'Pressure is critical'
        : trajectory.pressureIndex >= 55
        ? 'Pressure is elevated'
        : 'Pressure is manageable';

    final String timelineState = overdue > 0 || timelineHealth < 65
        ? 'Timeline integrity is at risk'
        : 'Timeline integrity is stable';

    final String milestoneState = milestoneSummary.overdue > 0
        ? 'Milestone drift detected'
        : milestoneSummary.healthScore >= 70
        ? 'Milestones are on-track'
        : 'Milestones need tighter execution';

    final String oneAction = overdue > 0
        ? 'Clear one overdue timeline item before adding anything new.'
        : trajectory.pressureIndex >= 70
        ? 'Shrink scope to one critical block and finish it today.'
        : completionRate < 0.5
        ? 'Complete one started task fully before opening another.'
        : 'Keep momentum by finishing one high-impact task now.';

    return 'SYSTEM INTEL REPORT\n\n'
        '$executionState (${(completionRate * 100).round()}% completion). '
        '$pressureState (index ${trajectory.pressureIndex}). '
        '$timelineState (health $timelineHealth%, risk $timelineRisk%, overdue $overdue). '
        '$milestoneState (health ${milestoneSummary.healthScore}%, overdue ${milestoneSummary.overdue}).\n\n'
        'Active workload: $activeTasks tasks across $activeGoals goals.\n'
        'Recommendation: $oneAction\n\n'
        'Advisor baseline: $baseline';
  } catch (_) {
    return 'Not enough data yet. Keep using the app to generate insights.';
  }
});
