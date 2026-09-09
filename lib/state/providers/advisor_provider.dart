import 'package:fantastic_guacamole/engine/advisor/product_advisor_engine.dart';
import 'package:fantastic_guacamole/domain/trajectory/trajectory_consequence_contract.dart';
import 'package:fantastic_guacamole/state/controllers/momentum_controller.dart';
import 'package:fantastic_guacamole/state/controllers/prediction_controller.dart';
import 'package:fantastic_guacamole/state/providers/execution_signals_provider.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/goals_provider.dart';
import 'package:fantastic_guacamole/state/providers/milestones_provider.dart';
import 'package:fantastic_guacamole/state/providers/logs_provider.dart';
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

enum ProgressionReviewStatus { ready, empty, loading, unavailable }

class ProgressionReview {
  const ProgressionReview(
    this.text, {
    this.status = ProgressionReviewStatus.ready,
  });

  final String text;
  final ProgressionReviewStatus status;

  bool get canAct =>
      status == ProgressionReviewStatus.ready ||
      status == ProgressionReviewStatus.empty;
}

final progressionReviewProvider = FutureProvider<ProgressionReview>((
  ref,
) async {
  if (!ref.watch(accountStorageScopeProvider).isWritable) {
    return const ProgressionReview(
      'Progress review is unavailable until your account data is ready.',
      status: ProgressionReviewStatus.unavailable,
    );
  }
  // Read source health before using projections that intentionally default to
  // zero/empty while loading. Those defaults are not evidence of healthy work.
  final tasks = ref.watch(tasksProvider);
  final goals = ref.watch(goalsReadProvider);
  final logs = ref.watch(logsProvider);
  final milestones = ref.watch(milestonesProvider);
  final trajectory = ref.watch(trajectorySummaryProvider);
  if (tasks.hasError ||
      goals.hasError ||
      logs.error != null ||
      milestones.hasError ||
      trajectory.sourceState == TrajectorySourceState.error ||
      trajectory.sourceState == TrajectorySourceState.partial ||
      trajectory.sourceState == TrajectorySourceState.offline) {
    return const ProgressionReview(
      'Progress review is unavailable because some saved planning evidence '
      'could not be read. Retry after your data is available. '
      'No workload or progress rating has been inferred from missing data.',
      status: ProgressionReviewStatus.unavailable,
    );
  }
  if (tasks.isLoading ||
      goals.isLoading ||
      logs.isLoading ||
      milestones.isLoading ||
      trajectory.sourceState == TrajectorySourceState.loading) {
    return const ProgressionReview(
      'Loading your saved planning evidence. Your progress review will appear '
      'when the required data is ready.',
      status: ProgressionReviewStatus.loading,
    );
  }
  if (ref.watch(timelinePersistenceCorruptedProvider)) {
    return const ProgressionReview(
      'Progress review is unavailable because saved Timeline evidence could '
      'not be read completely. Recover that data before relying on a rating.',
      status: ProgressionReviewStatus.unavailable,
    );
  }
  final activeTasks = tasks.requireValue
      .where((task) => !task.isCompleted)
      .length;
  final activeGoals = goals.requireValue
      .where((goal) => !goal.isCompleted)
      .length;
  if (tasks.requireValue.isEmpty &&
      goals.requireValue.isEmpty &&
      logs.entries.isEmpty) {
    return const ProgressionReview(
      'No saved planning history yet. Create a task or goal and record an '
      'outcome to begin your progress review. A progress rating is not available yet.',
      status: ProgressionReviewStatus.empty,
    );
  }
  final ExecutionSignals execution = ref.watch(executionSignalsProvider);
  final int timelineHealth = ref.watch(timelineHealthScoreProvider);
  final int timelineRisk = ref.watch(timelineRiskScoreProvider);
  final int overdue = ref.watch(timelineOverdueProvider).length;
  final milestoneSummary = ref.watch(milestoneSummaryProvider);
  return ProgressionReview(
    buildProgressionReview(
      execution: execution,
      pressureIndex: trajectory.pressureIndex,
      timelineHealth: timelineHealth,
      timelineRisk: timelineRisk,
      overdue: overdue,
      milestoneHealth: milestoneSummary.healthScore,
      milestoneOverdue: milestoneSummary.overdue,
      activeGoals: activeGoals,
      activeTasks: activeTasks,
    ),
  );
});

// Preserve the existing text consumer contract while exposing typed availability
// to the screen, so unavailable text can never receive a healthy-state action.
final weeklySummaryProvider = FutureProvider<String>(
  (ref) async => (await ref.watch(progressionReviewProvider.future)).text,
);

void retryProgressionReview(WidgetRef ref) {
  ref.invalidate(tasksProvider);
  ref.invalidate(goalsReadProvider);
  ref.invalidate(logsProvider);
  ref.invalidate(milestonesProvider);
  ref.invalidate(timelineProvider);
  ref.invalidate(predictionProvider);
  ref.invalidate(trajectorySummaryProvider);
  ref.invalidate(progressionReviewProvider);
}

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

  final String oneAction = activeTasks == 0 && overdue == 0
      ? 'Choose a new task when you are ready to build your next outcome.'
      : overdue > 0
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
