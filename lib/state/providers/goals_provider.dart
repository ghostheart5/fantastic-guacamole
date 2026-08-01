import 'package:fantastic_guacamole/core/debug/app_analytics.dart';
import 'package:fantastic_guacamole/core/eventing/domain_event.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/template_entity.dart';
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/config/create_goal_category_usecase.dart';
import 'package:fantastic_guacamole/features/auth/domain/usecases/goals/config/set_goal_priority_usecase.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/state/controllers/profile_controller.dart';
import 'package:fantastic_guacamole/state/models/goal_progress_view.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/task_provider.dart';
import 'package:fantastic_guacamole/state/providers/event_bus_provider.dart';
import 'package:fantastic_guacamole/state/providers/insights_provider.dart';
import 'package:fantastic_guacamole/state/providers/logs_provider.dart';
import 'package:fantastic_guacamole/state/providers/optimization_provider.dart';
import 'package:fantastic_guacamole/state/providers/service_providers.dart';
import 'package:fantastic_guacamole/state/providers/timeline_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final goalsProvider = NotifierProvider<GoalsNotifier, List<GoalEntity>>(
  GoalsNotifier.new,
);

final goalProvider = goalsProvider;
final goalByIdProvider = Provider.family<GoalEntity?, String>((
  Ref ref,
  String id,
) {
  ref.watch(goalsProvider);
  return ref.read(viewGoalUseCaseProvider).call(id);
});

final goalDetailsProvider = Provider.family<GoalEntity?, String>((
  Ref ref,
  String id,
) {
  ref.watch(goalsProvider);
  return ref.read(viewGoalDetailsUseCaseProvider).call(id);
});

final activeGoalsProvider = Provider<List<GoalEntity>>((Ref ref) {
  ref.watch(goalsProvider);
  return ref.read(viewActiveGoalsUseCaseProvider).call();
});

final archivedGoalsProvider = Provider<List<GoalEntity>>((Ref ref) {
  ref.watch(goalsProvider);
  return ref.read(viewArchivedGoalsUseCaseProvider).call();
});

final completedGoalsProvider = Provider<List<GoalEntity>>((Ref ref) {
  ref.watch(goalsProvider);
  return ref.read(viewCompletedGoalsUseCaseProvider).call();
});

final overdueGoalsProvider = Provider<List<GoalEntity>>((Ref ref) {
  ref.watch(goalsProvider);
  return ref.read(viewOverdueGoalsUseCaseProvider).call();
});
final searchedGoalsProvider = Provider.family<List<GoalEntity>, String>((
  Ref ref,
  String query,
) {
  ref.watch(goalsProvider);
  return ref.read(featureSearchGoalsUseCaseProvider).call(query);
});

final goalsWithTargetDateProvider = Provider<List<GoalEntity>>((Ref ref) {
  ref.watch(goalsProvider);
  return ref
      .read(featureFilterGoalsUseCaseProvider)
      .call(withTargetDateOnly: true);
});

final filteredOverdueGoalsProvider = Provider<List<GoalEntity>>((Ref ref) {
  ref.watch(goalsProvider);
  return ref.read(featureFilterGoalsUseCaseProvider).call(overdueOnly: true);
});

final sortedGoalsProvider = Provider<List<GoalEntity>>((Ref ref) {
  ref.watch(goalsProvider);
  return ref.read(featureSortGoalsUseCaseProvider).call();
});

final goalAnalyticsProvider = Provider((Ref ref) {
  ref.watch(goalsProvider);
  return ref.read(featureViewGoalAnalyticsUseCaseProvider).call();
});

final goalRiskResultProvider = Provider((Ref ref) {
  ref.watch(goalsProvider);
  return ref.read(featureDetectGoalRiskUseCaseProvider).call();
});

final goalConflictsProvider = Provider((Ref ref) {
  ref.watch(goalsProvider);
  return ref.read(featureDetectGoalConflictsUseCaseProvider).call();
});

final goalStagnationProvider = Provider((Ref ref) {
  ref.watch(goalsProvider);
  return ref.read(featureDetectGoalStagnationUseCaseProvider).call();
});

final goalCompletionPredictionsProvider = Provider((Ref ref) {
  ref.watch(goalsProvider);
  return ref.read(featurePredictGoalCompletionUseCaseProvider).call();
});

final goalSuccessPredictionsProvider = Provider((Ref ref) {
  ref.watch(goalsProvider);
  return ref.read(featurePredictGoalSuccessUseCaseProvider).call();
});

final goalCompletionRateProvider = Provider((Ref ref) {
  ref.watch(goalsProvider);
  return ref.read(featureViewGoalCompletionRateUseCaseProvider).call();
});

final goalStreaksProvider = Provider((Ref ref) {
  ref.watch(goalsProvider);
  return ref.read(featureViewGoalStreaksUseCaseProvider).call();
});

final goalTrendsProvider = Provider((Ref ref) {
  ref.watch(goalsProvider);
  return ref.read(featureViewGoalTrendsUseCaseProvider).call();
});
final goalSummaryProvider = Provider((Ref ref) {
  ref.watch(goalsProvider);
  return ref.read(featureGenerateGoalSummaryUseCaseProvider).call();
});

final goalInsightsProvider = Provider<List<String>>((Ref ref) {
  ref.watch(goalsProvider);
  return ref.read(featureGenerateGoalInsightsUseCaseProvider).call();
});

final goalRecommendationsProvider = Provider<List<String>>((Ref ref) {
  ref.watch(goalsProvider);
  return ref.read(featureGenerateGoalRecommendationsUseCaseProvider).call();
});

final recommendedGoalsProvider = Provider<List<String>>((Ref ref) {
  ref.watch(goalsProvider);
  return ref.read(featureRecommendGoalsUseCaseProvider).call();
});

final goalBreakdownProvider = FutureProvider.family((
  Ref ref,
  String goalId,
) async {
  ref.watch(goalsProvider);
  ref.watch(tasksProvider);
  return ref.read(featureGenerateGoalBreakdownUseCaseProvider).call(goalId);
});

final goalPlanProvider = FutureProvider.family((Ref ref, String goalId) async {
  ref.watch(goalsProvider);
  ref.watch(tasksProvider);
  return ref.read(featureGenerateGoalPlanUseCaseProvider).call(goalId);
});

final goalNextActionProvider = FutureProvider.family<String?, String>((
  Ref ref,
  String goalId,
) async {
  ref.watch(goalsProvider);
  ref.watch(tasksProvider);
  return ref.read(featureRecommendNextActionUseCaseProvider).call(goalId);
});
final goalTimelineProvider = Provider.family<List<TimelineEventEntity>, String>(
  (Ref ref, String goalId) {
    ref.watch(goalsProvider);
    ref.watch(timelineProvider);
    return ref.read(viewGoalTimelineUseCaseProvider).call(goalId);
  },
);

final goalHistoryProvider = Provider.family<List<TimelineEventEntity>, String>((
  Ref ref,
  String goalId,
) {
  ref.watch(goalsProvider);
  ref.watch(timelineProvider);
  return ref.read(viewGoalHistoryUseCaseProvider).call(goalId);
});

final goalActivityProvider = Provider.family<List<TimelineEventEntity>, String>(
  (Ref ref, String goalId) {
    ref.watch(goalsProvider);
    ref.watch(timelineProvider);
    return ref.read(viewGoalActivityUseCaseProvider).call(goalId);
  },
);

final goalProgressProvider = FutureProvider.family<GoalProgressView, String>((
  Ref ref,
  String goalId,
) async {
  final List<TaskEntity> tasks = await ref
      .watch(getTasksUseCaseProvider)
      .call();
  final List<TaskEntity> linked = tasks
      .where((TaskEntity task) => task.goalId == goalId)
      .toList(growable: false);
  final int completed = linked
      .where((TaskEntity task) => task.isCompleted)
      .length;
  return GoalProgressView(tasks: linked, completedCount: completed);
});
final goalScoreProvider = FutureProvider.family((Ref ref, String goalId) async {
  ref.watch(goalsProvider);
  ref.watch(tasksProvider);
  return ref.read(featureCalculateGoalScoreUseCaseProvider).call(goalId);
});

final goalSuccessRateProvider = FutureProvider.family((
  Ref ref,
  String goalId,
) async {
  ref.watch(goalsProvider);
  ref.watch(tasksProvider);
  return ref.read(featureCalculateGoalSuccessRateUseCaseProvider).call(goalId);
});

class GoalsNotifier extends Notifier<List<GoalEntity>> {
  @override
  List<GoalEntity> build() {
    final List<GoalEntity> goals = ref.read(getGoalsUseCaseProvider).call();
    final reminders = ref.read(reminderOrchestratorServiceProvider);
    Future<void>(() async {
      await reminders.syncGoalReminders(goals);
      await reminders.ensureDailyPlanningReminder();
    });
    return goals;
  }

  Future<void> add({
    required String title,
    String? description,
    DateTime? targetDate,
  }) async {
    final goal = GoalEntity(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title.trim(),
      createdAt: DateTime.now(),
      description: description?.trim().isEmpty ?? true
          ? null
          : description?.trim(),
      targetDate: targetDate,
    );
    await ref.read(featureCreateGoalUseCaseProvider).call(goal);
    state = [goal, ...state];
    AppAnalytics.track(
      'goal_created',
      params: <String, Object?>{'goal_id': goal.id},
    );
    await ref
        .read(reminderOrchestratorServiceProvider)
        .syncGoalReminders(state);
    await _fanOutGoalEvent(goal: goal, action: _GoalAction.created);
    ref.invalidate(goalProgressProvider);
  }

  Future<void> update(GoalEntity updated) async {
    await ref.read(featureUpdateGoalUseCaseProvider).call(updated);
    state = state.map((g) => g.id == updated.id ? updated : g).toList();
    await ref
        .read(reminderOrchestratorServiceProvider)
        .syncGoalReminders(state);
    await _fanOutGoalEvent(goal: updated, action: _GoalAction.updated);
    ref.invalidate(goalProgressProvider);
  }

  Future<GoalEntity?> duplicate(String id) async {
    final GoalEntity? duplicate = await ref
        .read(featureDuplicateGoalUseCaseProvider)
        .call(id);

    if (duplicate == null) {
      return null;
    }

    state = [
      duplicate,
      ...state.where((GoalEntity goal) => goal.id != duplicate.id),
    ];

    await ref
        .read(reminderOrchestratorServiceProvider)
        .syncGoalReminders(state);

    await _fanOutGoalEvent(goal: duplicate, action: _GoalAction.created);
    ref.invalidate(goalProgressProvider);

    return duplicate;
  }

  Future<GoalEntity> addDaily({
    required String title,
    String? description,
  }) async {
    final GoalEntity goal = await ref
        .read(featureCreateDailyGoalUseCaseProvider)
        .call(title: title, description: description);

    state = [goal, ...state.where((GoalEntity item) => item.id != goal.id)];

    await ref
        .read(reminderOrchestratorServiceProvider)
        .syncGoalReminders(state);

    await _fanOutGoalEvent(goal: goal, action: _GoalAction.created);
    ref.invalidate(goalProgressProvider);

    return goal;
  }

  Future<GoalEntity> addWeekly({
    required String title,
    String? description,
  }) async {
    final GoalEntity goal = await ref
        .read(featureCreateWeeklyGoalUseCaseProvider)
        .call(title: title, description: description);

    state = [goal, ...state.where((GoalEntity item) => item.id != goal.id)];

    await ref
        .read(reminderOrchestratorServiceProvider)
        .syncGoalReminders(state);

    await _fanOutGoalEvent(goal: goal, action: _GoalAction.created);
    ref.invalidate(goalProgressProvider);

    return goal;
  }

  Future<GoalEntity> addMonthly({
    required String title,
    String? description,
  }) async {
    final GoalEntity goal = await ref
        .read(featureCreateMonthlyGoalUseCaseProvider)
        .call(title: title, description: description);

    state = [goal, ...state.where((GoalEntity item) => item.id != goal.id)];

    await ref
        .read(reminderOrchestratorServiceProvider)
        .syncGoalReminders(state);

    await _fanOutGoalEvent(goal: goal, action: _GoalAction.created);
    ref.invalidate(goalProgressProvider);

    return goal;
  }

  Future<GoalEntity> addYearly({
    required String title,
    String? description,
  }) async {
    final GoalEntity goal = await ref
        .read(featureCreateYearlyGoalUseCaseProvider)
        .call(title: title, description: description);

    state = [goal, ...state.where((GoalEntity item) => item.id != goal.id)];

    await ref
        .read(reminderOrchestratorServiceProvider)
        .syncGoalReminders(state);

    await _fanOutGoalEvent(goal: goal, action: _GoalAction.created);
    ref.invalidate(goalProgressProvider);

    return goal;
  }

  Future<GoalEntity> addSmart({
    required String title,
    String? description,
    DateTime? targetDate,
  }) async {
    final GoalEntity goal = await ref
        .read(featureCreateSmartGoalUseCaseProvider)
        .call(title: title, description: description, targetDate: targetDate);

    state = [goal, ...state.where((GoalEntity item) => item.id != goal.id)];

    await ref
        .read(reminderOrchestratorServiceProvider)
        .syncGoalReminders(state);

    await _fanOutGoalEvent(goal: goal, action: _GoalAction.created);
    ref.invalidate(goalProgressProvider);

    return goal;
  }

  Future<GoalEntity> addMicro({
    required String title,
    String? description,
  }) async {
    final GoalEntity goal = await ref
        .read(featureCreateMicroGoalUseCaseProvider)
        .call(title: title, description: description);

    state = [goal, ...state.where((GoalEntity item) => item.id != goal.id)];

    await ref
        .read(reminderOrchestratorServiceProvider)
        .syncGoalReminders(state);

    await _fanOutGoalEvent(goal: goal, action: _GoalAction.created);
    ref.invalidate(goalProgressProvider);

    return goal;
  }

  Future<GoalEntity> addStretch({
    required String title,
    String? description,
    DateTime? targetDate,
  }) async {
    final GoalEntity goal = await ref
        .read(featureCreateStretchGoalUseCaseProvider)
        .call(title: title, description: description, targetDate: targetDate);

    state = [goal, ...state.where((GoalEntity item) => item.id != goal.id)];

    await ref
        .read(reminderOrchestratorServiceProvider)
        .syncGoalReminders(state);

    await _fanOutGoalEvent(goal: goal, action: _GoalAction.created);
    ref.invalidate(goalProgressProvider);

    return goal;
  }

  Future<GoalEntity> addLifetime({
    required String title,
    String? description,
  }) async {
    final GoalEntity goal = await ref
        .read(featureCreateLifetimeGoalUseCaseProvider)
        .call(title: title, description: description);

    state = [goal, ...state.where((GoalEntity item) => item.id != goal.id)];

    await ref
        .read(reminderOrchestratorServiceProvider)
        .syncGoalReminders(state);

    await _fanOutGoalEvent(goal: goal, action: _GoalAction.created);
    ref.invalidate(goalProgressProvider);

    return goal;
  }

  Future<GoalEntity> addCareer({
    required String title,
    String? description,
    DateTime? targetDate,
  }) async {
    final GoalEntity goal = await ref
        .read(featureCreateCareerGoalUseCaseProvider)
        .call(title: title, description: description, targetDate: targetDate);

    await _addGeneratedGoal(goal);
    return goal;
  }

  Future<GoalEntity> addFinancial({
    required String title,
    String? description,
    DateTime? targetDate,
  }) async {
    final GoalEntity goal = await ref
        .read(featureCreateFinancialGoalUseCaseProvider)
        .call(title: title, description: description, targetDate: targetDate);

    await _addGeneratedGoal(goal);
    return goal;
  }

  Future<GoalEntity> addFitness({
    required String title,
    String? description,
    DateTime? targetDate,
  }) async {
    final GoalEntity goal = await ref
        .read(featureCreateFitnessGoalUseCaseProvider)
        .call(title: title, description: description, targetDate: targetDate);

    await _addGeneratedGoal(goal);
    return goal;
  }

  Future<GoalEntity> addHealth({
    required String title,
    String? description,
    DateTime? targetDate,
  }) async {
    final GoalEntity goal = await ref
        .read(featureCreateHealthGoalUseCaseProvider)
        .call(title: title, description: description, targetDate: targetDate);

    await _addGeneratedGoal(goal);
    return goal;
  }

  Future<GoalEntity> addLearning({
    required String title,
    String? description,
    DateTime? targetDate,
  }) async {
    final GoalEntity goal = await ref
        .read(featureCreateLearningGoalUseCaseProvider)
        .call(title: title, description: description, targetDate: targetDate);

    await _addGeneratedGoal(goal);
    return goal;
  }

  Future<GoalEntity> addPersonal({
    required String title,
    String? description,
    DateTime? targetDate,
  }) async {
    final GoalEntity goal = await ref
        .read(featureCreatePersonalGoalUseCaseProvider)
        .call(title: title, description: description, targetDate: targetDate);

    await _addGeneratedGoal(goal);
    return goal;
  }

  Future<GoalEntity> addProductivity({
    required String title,
    String? description,
    DateTime? targetDate,
  }) async {
    final GoalEntity goal = await ref
        .read(featureCreateProductivityGoalUseCaseProvider)
        .call(title: title, description: description, targetDate: targetDate);

    await _addGeneratedGoal(goal);
    return goal;
  }

  Future<GoalEntity> addRelationship({
    required String title,
    String? description,
    DateTime? targetDate,
  }) async {
    final GoalEntity goal = await ref
        .read(featureCreateRelationshipGoalUseCaseProvider)
        .call(title: title, description: description, targetDate: targetDate);

    await _addGeneratedGoal(goal);
    return goal;
  }

  Future<GoalEntity> addSpiritual({
    required String title,
    String? description,
    DateTime? targetDate,
  }) async {
    final GoalEntity goal = await ref
        .read(featureCreateSpiritualGoalUseCaseProvider)
        .call(title: title, description: description, targetDate: targetDate);

    await _addGeneratedGoal(goal);
    return goal;
  }

  Future<void> _addGeneratedGoal(GoalEntity goal) async {
    state = [goal, ...state.where((GoalEntity item) => item.id != goal.id)];

    await ref
        .read(reminderOrchestratorServiceProvider)
        .syncGoalReminders(state);

    await _fanOutGoalEvent(goal: goal, action: _GoalAction.created);
    ref.invalidate(goalProgressProvider);
  }

  Future<void> incrementProgress(String goalId) async {
    await ref.read(featureIncrementGoalProgressUseCaseProvider).call(goalId);

    ref.invalidate(tasksProvider);
    ref.invalidate(goalProgressProvider);
    ref.invalidate(goalScoreProvider);
    ref.invalidate(goalSuccessRateProvider);

    await _refreshCoachDecision();
  }

  Future<void> decrementProgress(String goalId) async {
    await ref.read(featureDecrementGoalProgressUseCaseProvider).call(goalId);

    ref.invalidate(tasksProvider);
    ref.invalidate(goalProgressProvider);
    ref.invalidate(goalScoreProvider);
    ref.invalidate(goalSuccessRateProvider);

    await _refreshCoachDecision();
  }

  Future<void> resetProgress(String goalId) async {
    await ref.read(featureResetGoalProgressUseCaseProvider).call(goalId);

    ref.invalidate(tasksProvider);
    ref.invalidate(goalProgressProvider);
    ref.invalidate(goalScoreProvider);
    ref.invalidate(goalSuccessRateProvider);

    await _refreshCoachDecision();
  }

  Future<void> updateProgress({
    required String goalId,
    required int completedTaskCount,
  }) async {
    await ref
        .read(featureUpdateGoalProgressUseCaseProvider)
        .call(goalId: goalId, completedTaskCount: completedTaskCount);

    ref.invalidate(tasksProvider);
    ref.invalidate(goalProgressProvider);
    ref.invalidate(goalScoreProvider);
    ref.invalidate(goalSuccessRateProvider);

    await _refreshCoachDecision();
  }

  Future<TimelineEventEntity?> createMilestone({
    required String goalId,
    required String title,
    String? detail,
    DateTime? dueAt,
  }) async {
    final TimelineEventEntity? milestone = await ref
        .read(featureCreateMilestoneUseCaseProvider)
        .call(goalId: goalId, title: title, detail: detail, dueAt: dueAt);

    if (milestone != null) {
      _invalidateGoalStructure(goalId);
      await _refreshCoachDecision();
    }

    return milestone;
  }

  Future<bool> updateMilestone(TimelineEventEntity milestone) async {
    final bool updated = await ref
        .read(featureUpdateMilestoneUseCaseProvider)
        .call(milestone);

    if (updated) {
      _invalidateGoalStructure(milestone.relatedId);
      await _refreshCoachDecision();
    }

    return updated;
  }

  Future<void> deleteMilestone({
    required String milestoneId,
    String? goalId,
  }) async {
    await ref.read(featureDeleteMilestoneUseCaseProvider).call(milestoneId);

    _invalidateGoalStructure(goalId);
    await _refreshCoachDecision();
  }

  Future<TimelineEventEntity?> completeMilestone(String milestoneId) async {
    final TimelineEventEntity? milestone = await ref
        .read(featureCompleteMilestoneUseCaseProvider)
        .call(milestoneId);

    if (milestone != null) {
      _invalidateGoalStructure(milestone.relatedId);
      await _refreshCoachDecision();
    }

    return milestone;
  }

  Future<TimelineEventEntity?> reopenMilestone(String milestoneId) async {
    final TimelineEventEntity? milestone = await ref
        .read(featureReopenMilestoneUseCaseProvider)
        .call(milestoneId);

    if (milestone != null) {
      _invalidateGoalStructure(milestone.relatedId);
      await _refreshCoachDecision();
    }

    return milestone;
  }

  void _invalidateGoalStructure(String? goalId) {
    ref.invalidate(timelineProvider);

    final String? targetGoalId = goalId?.trim();
    if (targetGoalId == null || targetGoalId.isEmpty) {
      return;
    }

    ref.invalidate(goalTimelineProvider(targetGoalId));
    ref.invalidate(goalHistoryProvider(targetGoalId));
    ref.invalidate(goalActivityProvider(targetGoalId));
  }

  Future<TimelineEventEntity?> createSubgoal({
    required String goalId,
    required String title,
    String? detail,
    DateTime? dueAt,
  }) async {
    final TimelineEventEntity? subgoal = await ref
        .read(featureCreateSubgoalUseCaseProvider)
        .call(goalId: goalId, title: title, detail: detail, dueAt: dueAt);

    if (subgoal != null) {
      _invalidateGoalStructure(goalId);
      await _refreshCoachDecision();
    }

    return subgoal;
  }

  Future<bool> updateSubgoal(TimelineEventEntity subgoal) async {
    final bool updated = await ref
        .read(featureUpdateSubgoalUseCaseProvider)
        .call(subgoal);

    if (updated) {
      _invalidateGoalStructure(subgoal.relatedId);
      await _refreshCoachDecision();
    }

    return updated;
  }

  Future<void> deleteSubgoal({
    required String subgoalId,
    String? goalId,
  }) async {
    await ref.read(featureDeleteSubgoalUseCaseProvider).call(subgoalId);

    _invalidateGoalStructure(goalId);
    await _refreshCoachDecision();
  }

  Future<TimelineEventEntity?> completeSubgoal(String subgoalId) async {
    final TimelineEventEntity? subgoal = await ref
        .read(featureCompleteSubgoalUseCaseProvider)
        .call(subgoalId);

    if (subgoal != null) {
      _invalidateGoalStructure(subgoal.relatedId);
      await _refreshCoachDecision();
    }

    return subgoal;
  }

  Future<GoalEntity?> setDeadline({
    required String goalId,
    required DateTime deadline,
  }) async {
    final GoalEntity? updated = await ref
        .read(featureSetGoalDeadlineUseCaseProvider)
        .call(goalId: goalId, deadline: deadline);

    if (updated == null) {
      return null;
    }

    state = state
        .map((GoalEntity goal) => goal.id == updated.id ? updated : goal)
        .toList(growable: false);

    await ref
        .read(reminderOrchestratorServiceProvider)
        .syncGoalReminders(state);

    await _fanOutGoalEvent(goal: updated, action: _GoalAction.updated);
    ref.invalidate(goalProgressProvider);
    ref.invalidate(goalByIdProvider(goalId));
    ref.invalidate(goalDetailsProvider(goalId));
    ref.invalidate(overdueGoalsProvider);
    ref.invalidate(filteredOverdueGoalsProvider);
    ref.invalidate(goalsWithTargetDateProvider);
    ref.invalidate(goalSummaryProvider);
    ref.invalidate(goalAnalyticsProvider);
    ref.invalidate(goalRiskResultProvider);

    return updated;
  }

  Future<GoalEntity?> updateDeadline({
    required String goalId,
    required DateTime deadline,
  }) async {
    final GoalEntity? updated = await ref
        .read(featureUpdateGoalDeadlineUseCaseProvider)
        .call(goalId: goalId, deadline: deadline);

    if (updated == null) {
      return null;
    }

    state = state
        .map((GoalEntity goal) => goal.id == updated.id ? updated : goal)
        .toList(growable: false);

    await ref
        .read(reminderOrchestratorServiceProvider)
        .syncGoalReminders(state);

    await _fanOutGoalEvent(goal: updated, action: _GoalAction.updated);
    ref.invalidate(goalProgressProvider);
    ref.invalidate(goalByIdProvider(goalId));
    ref.invalidate(goalDetailsProvider(goalId));
    ref.invalidate(overdueGoalsProvider);
    ref.invalidate(filteredOverdueGoalsProvider);
    ref.invalidate(goalsWithTargetDateProvider);
    ref.invalidate(goalSummaryProvider);
    ref.invalidate(goalAnalyticsProvider);
    ref.invalidate(goalRiskResultProvider);

    return updated;
  }

  Future<GoalEntity?> removeDeadline(String goalId) async {
    final GoalEntity? updated = await ref
        .read(featureRemoveGoalDeadlineUseCaseProvider)
        .call(goalId);

    if (updated == null) {
      return null;
    }

    state = state
        .map((GoalEntity goal) => goal.id == updated.id ? updated : goal)
        .toList(growable: false);

    await ref
        .read(reminderOrchestratorServiceProvider)
        .syncGoalReminders(state);

    await _fanOutGoalEvent(goal: updated, action: _GoalAction.updated);
    ref.invalidate(goalProgressProvider);
    ref.invalidate(goalByIdProvider(goalId));
    ref.invalidate(goalDetailsProvider(goalId));
    ref.invalidate(overdueGoalsProvider);
    ref.invalidate(filteredOverdueGoalsProvider);
    ref.invalidate(goalsWithTargetDateProvider);
    ref.invalidate(goalSummaryProvider);
    ref.invalidate(goalAnalyticsProvider);
    ref.invalidate(goalRiskResultProvider);

    return updated;
  }

  Future<TimelineEventEntity?> startGoal(String goalId) async {
    final TimelineEventEntity? event = await ref
        .read(featureStartGoalUseCaseProvider)
        .call(goalId);

    if (event != null) {
      _invalidateGoalStructure(event.relatedId);
      await _refreshCoachDecision();
    }

    return event;
  }

  Future<TimelineEventEntity?> pauseGoal(String goalId) async {
    final TimelineEventEntity? event = await ref
        .read(featurePauseGoalUseCaseProvider)
        .call(goalId);

    if (event != null) {
      _invalidateGoalStructure(event.relatedId);
      await _refreshCoachDecision();
    }

    return event;
  }

  Future<TimelineEventEntity?> resumeGoal(String goalId) async {
    final TimelineEventEntity? event = await ref
        .read(featureResumeGoalUseCaseProvider)
        .call(goalId);

    if (event != null) {
      _invalidateGoalStructure(event.relatedId);
      await _refreshCoachDecision();
    }

    return event;
  }

  Future<TimelineEventEntity?> reopenGoalLifecycle(String goalId) async {
    final TimelineEventEntity? event = await ref
        .read(featureReopenGoalUseCaseProvider)
        .call(goalId);

    if (event != null) {
      _invalidateGoalStructure(event.relatedId);
      await _refreshCoachDecision();
    }

    return event;
  }

  Future<TimelineEventEntity?> abandonGoal(String goalId) async {
    final TimelineEventEntity? event = await ref
        .read(featureAbandonGoalUseCaseProvider)
        .call(goalId);

    if (event != null) {
      _invalidateGoalStructure(event.relatedId);
      await _refreshCoachDecision();
    }

    return event;
  }

  Future<TimelineEventEntity?> completeGoalLifecycle(String goalId) async {
    final TimelineEventEntity? event = await ref
        .read(featureLifecycleCompleteGoalUseCaseProvider)
        .call(goalId);

    if (event != null) {
      _invalidateGoalStructure(event.relatedId);
      await _refreshCoachDecision();
    }

    return event;
  }

  Future<TimelineEventEntity?> markGoalCompleted(String goalId) async {
    final TimelineEventEntity? event = await ref
        .read(featureMarkGoalCompletedUseCaseProvider)
        .call(goalId);

    if (event != null) {
      _invalidateGoalStructure(event.relatedId);
      await _refreshCoachDecision();
    }

    return event;
  }

  Future<TimelineEventEntity?> markGoalFailed(String goalId) async {
    final TimelineEventEntity? event = await ref
        .read(featureMarkGoalFailedUseCaseProvider)
        .call(goalId);

    if (event != null) {
      _invalidateGoalStructure(event.relatedId);
      await _refreshCoachDecision();
    }

    return event;
  }

  Future<TimelineEventEntity?> markGoalInProgress(String goalId) async {
    final TimelineEventEntity? event = await ref
        .read(featureMarkGoalInProgressUseCaseProvider)
        .call(goalId);

    if (event != null) {
      _invalidateGoalStructure(event.relatedId);
      await _refreshCoachDecision();
    }

    return event;
  }

  Future<TaskEntity?> linkTask({
    required String taskId,
    required String goalId,
  }) async {
    final TaskEntity? updatedTask = await ref
        .read(featureLinkTaskToGoalUseCaseProvider)
        .call(taskId: taskId, goalId: goalId);

    if (updatedTask == null) {
      return null;
    }

    _invalidateGoalTaskLinks(goalId);
    await _refreshCoachDecision();

    return updatedTask;
  }

  Future<TaskEntity?> unlinkTask({
    required String taskId,
    required String goalId,
  }) async {
    final TaskEntity? updatedTask = await ref
        .read(featureUnlinkTaskFromGoalUseCaseProvider)
        .call(taskId: taskId, goalId: goalId);

    if (updatedTask == null) {
      return null;
    }

    _invalidateGoalTaskLinks(goalId);
    await _refreshCoachDecision();

    return updatedTask;
  }

  void _invalidateGoalTaskLinks(String goalId) {
    final String targetGoalId = goalId.trim();

    ref.invalidate(tasksProvider);
    ref.invalidate(goalProgressProvider);
    ref.invalidate(goalScoreProvider);
    ref.invalidate(goalSuccessRateProvider);

    if (targetGoalId.isEmpty) {
      return;
    }

    ref.invalidate(goalProgressProvider(targetGoalId));
    ref.invalidate(goalScoreProvider(targetGoalId));
    ref.invalidate(goalSuccessRateProvider(targetGoalId));
    ref.invalidate(goalBreakdownProvider(targetGoalId));
    ref.invalidate(goalPlanProvider(targetGoalId));
    ref.invalidate(goalNextActionProvider(targetGoalId));
  }

  Future<GoalEntity?> createReminder({
    required String goalId,
    required DateTime targetDate,
  }) async {
    final GoalEntity? updated = await ref
        .read(featureCreateGoalReminderUseCaseProvider)
        .call(goalId: goalId, targetDate: targetDate);

    if (updated == null) {
      return null;
    }

    state = state
        .map((GoalEntity goal) => goal.id == updated.id ? updated : goal)
        .toList(growable: false);

    await _fanOutGoalEvent(goal: updated, action: _GoalAction.updated);

    ref.invalidate(goalByIdProvider(goalId));
    ref.invalidate(goalDetailsProvider(goalId));
    ref.invalidate(goalsWithTargetDateProvider);
    ref.invalidate(overdueGoalsProvider);
    ref.invalidate(filteredOverdueGoalsProvider);
    ref.invalidate(goalSummaryProvider);
    ref.invalidate(goalAnalyticsProvider);
    ref.invalidate(goalRiskResultProvider);

    return updated;
  }

  Future<GoalEntity?> updateReminder({
    required String goalId,
    required DateTime targetDate,
  }) async {
    final GoalEntity? updated = await ref
        .read(featureUpdateGoalReminderUseCaseProvider)
        .call(goalId: goalId, targetDate: targetDate);

    if (updated == null) {
      return null;
    }

    state = state
        .map((GoalEntity goal) => goal.id == updated.id ? updated : goal)
        .toList(growable: false);

    await _fanOutGoalEvent(goal: updated, action: _GoalAction.updated);

    ref.invalidate(goalByIdProvider(goalId));
    ref.invalidate(goalDetailsProvider(goalId));
    ref.invalidate(goalsWithTargetDateProvider);
    ref.invalidate(overdueGoalsProvider);
    ref.invalidate(filteredOverdueGoalsProvider);
    ref.invalidate(goalSummaryProvider);
    ref.invalidate(goalAnalyticsProvider);
    ref.invalidate(goalRiskResultProvider);

    return updated;
  }

  Future<GoalEntity?> deleteReminder(String goalId) async {
    final GoalEntity? updated = await ref
        .read(featureDeleteGoalReminderUseCaseProvider)
        .call(goalId);

    if (updated == null) {
      return null;
    }

    state = state
        .map((GoalEntity goal) => goal.id == updated.id ? updated : goal)
        .toList(growable: false);

    await _fanOutGoalEvent(goal: updated, action: _GoalAction.updated);

    ref.invalidate(goalByIdProvider(goalId));
    ref.invalidate(goalDetailsProvider(goalId));
    ref.invalidate(goalsWithTargetDateProvider);
    ref.invalidate(overdueGoalsProvider);
    ref.invalidate(filteredOverdueGoalsProvider);
    ref.invalidate(goalSummaryProvider);
    ref.invalidate(goalAnalyticsProvider);
    ref.invalidate(goalRiskResultProvider);

    return updated;
  }

  Future<TimelineEventEntity?> dismissReminder(String goalId) async {
    final TimelineEventEntity? event = await ref
        .read(featureDismissGoalReminderUseCaseProvider)
        .call(goalId);

    if (event != null) {
      _invalidateGoalStructure(event.relatedId);
      await _refreshCoachDecision();
    }

    return event;
  }

  Future<TimelineEventEntity?> snoozeReminder({
    required String goalId,
    required DateTime snoozedUntil,
  }) async {
    final TimelineEventEntity? event = await ref
        .read(featureSnoozeGoalReminderUseCaseProvider)
        .call(goalId: goalId, snoozedUntil: snoozedUntil);

    if (event != null) {
      _invalidateGoalStructure(event.relatedId);
      await _refreshCoachDecision();
    }

    return event;
  }

  Future<bool> awardGoalAchievement({
    required String goalId,
    int xp = 25,
    String? title,
    String? detail,
  }) async {
    final reward = ref
        .read(featureAwardGoalAchievementUseCaseProvider)
        .call(goalId: goalId, xp: xp, title: title, detail: detail);

    if (reward == null) {
      return false;
    }

    ref.read(profileProvider.notifier).addXP(reward.xp);

    await ref
        .read(timelineActionsProvider)
        .addMirroredEvent(
          TimelineEventEntity(
            id: 'goal-achievement-${reward.goal.id}-${DateTime.now().microsecondsSinceEpoch}',
            type: TimelineEventType.levelUp,
            title: reward.title,
            detail: reward.detail,
            timestamp: DateTime.now(),
            status: TimelineEventStatus.info,
            relatedId: reward.goal.id,
            phase: 'reward.achievement',
          ),
        );

    _invalidateGoalStructure(reward.goal.id);
    ref.invalidate(goalAnalyticsProvider);
    ref.invalidate(goalTrendsProvider);
    ref.invalidate(goalInsightsProvider);
    await _refreshCoachDecision();

    return true;
  }

  Future<bool> celebrateGoalCompletion({
    required String goalId,
    int bonusXp = 15,
  }) async {
    final celebration = ref
        .read(featureCelebrateGoalCompletionUseCaseProvider)
        .call(goalId: goalId, bonusXp: bonusXp);

    if (celebration == null) {
      return false;
    }

    ref.read(profileProvider.notifier).addXP(celebration.bonusXp);

    await ref
        .read(timelineActionsProvider)
        .addMirroredEvent(
          TimelineEventEntity(
            id: 'goal-celebration-${celebration.goal.id}-${DateTime.now().microsecondsSinceEpoch}',
            type: TimelineEventType.goalComplete,
            title: celebration.title,
            detail: celebration.detail,
            timestamp: DateTime.now(),
            status: TimelineEventStatus.completed,
            relatedId: celebration.goal.id,
            phase: 'reward.celebration',
          ),
        );

    _invalidateGoalStructure(celebration.goal.id);
    ref.invalidate(goalAnalyticsProvider);
    ref.invalidate(goalTrendsProvider);
    ref.invalidate(goalInsightsProvider);
    await _refreshCoachDecision();

    return true;
  }

  Future<GoalEntity> createFromTemplate(
    TemplateEntity template, {
    DateTime? targetDate,
  }) async {
    final GoalEntity goal = await ref
        .read(featureCreateGoalFromTemplateUseCaseProvider)
        .call(template, targetDate: targetDate);

    state = [goal, ...state.where((GoalEntity item) => item.id != goal.id)];

    await ref
        .read(reminderOrchestratorServiceProvider)
        .syncGoalReminders(state);

    await _fanOutGoalEvent(goal: goal, action: _GoalAction.created);
    ref.invalidate(goalProgressProvider);
    ref.invalidate(goalSummaryProvider);
    ref.invalidate(goalAnalyticsProvider);
    ref.invalidate(goalInsightsProvider);
    ref.invalidate(goalRecommendationsProvider);

    return goal;
  }

  TemplateEntity? saveAsTemplate(String goalId) {
    return ref.read(featureSaveGoalAsTemplateUseCaseProvider).call(goalId);
  }

  TemplateEntity updateTemplate({
    required TemplateEntity template,
    String? name,
    String? description,
  }) {
    return ref
        .read(featureUpdateGoalTemplateUseCaseProvider)
        .call(template: template, name: name, description: description);
  }

  Future<GoalCategoryConfig> createCategory({
    required String name,
    String? description,
  }) async {
    final GoalCategoryConfig category = ref
        .read(featureCreateGoalCategoryUseCaseProvider)
        .call(name: name, description: description);

    await ref
        .read(timelineActionsProvider)
        .addMirroredEvent(
          TimelineEventEntity(
            id: 'goal-category-created-${category.id}-${DateTime.now().microsecondsSinceEpoch}',
            type: TimelineEventType.reflection,
            title: 'Goal category created',
            detail: category.name,
            timestamp: DateTime.now(),
            status: TimelineEventStatus.info,
            phase: 'goal.config.category.created',
            relatedId: category.id,
          ),
        );

    ref.invalidate(goalInsightsProvider);
    ref.invalidate(goalRecommendationsProvider);
    await _refreshCoachDecision();

    return category;
  }

  Future<GoalCategoryConfig> updateCategory({
    required GoalCategoryConfig category,
    String? name,
    String? description,
  }) async {
    final GoalCategoryConfig updated = ref
        .read(featureUpdateGoalCategoryUseCaseProvider)
        .call(category: category, name: name, description: description);

    await ref
        .read(timelineActionsProvider)
        .addMirroredEvent(
          TimelineEventEntity(
            id: 'goal-category-updated-${updated.id}-${DateTime.now().microsecondsSinceEpoch}',
            type: TimelineEventType.reflection,
            title: 'Goal category updated',
            detail: updated.name,
            timestamp: DateTime.now(),
            status: TimelineEventStatus.info,
            phase: 'goal.config.category.updated',
            relatedId: updated.id,
          ),
        );

    ref.invalidate(goalInsightsProvider);
    ref.invalidate(goalRecommendationsProvider);
    await _refreshCoachDecision();

    return updated;
  }

  Future<GoalCategoryConfig> deleteCategory(GoalCategoryConfig category) async {
    final GoalCategoryConfig deleted = ref
        .read(featureDeleteGoalCategoryUseCaseProvider)
        .call(category);

    await ref
        .read(timelineActionsProvider)
        .addMirroredEvent(
          TimelineEventEntity(
            id: 'goal-category-deleted-${deleted.id}-${DateTime.now().microsecondsSinceEpoch}',
            type: TimelineEventType.reflection,
            title: 'Goal category deleted',
            detail: deleted.name,
            timestamp: DateTime.now(),
            status: TimelineEventStatus.info,
            phase: 'goal.config.category.deleted',
            relatedId: deleted.id,
          ),
        );

    ref.invalidate(goalInsightsProvider);
    ref.invalidate(goalRecommendationsProvider);
    await _refreshCoachDecision();

    return deleted;
  }

  Future<GoalPriorityConfig?> setPriority({
    required String goalId,
    required int priority,
  }) async {
    final GoalPriorityConfig? result = ref
        .read(featureSetGoalPriorityUseCaseProvider)
        .call(goalId: goalId, priority: priority);

    if (result == null) {
      return null;
    }

    await ref
        .read(timelineActionsProvider)
        .addMirroredEvent(
          TimelineEventEntity(
            id: 'goal-priority-set-${result.goal.id}-${DateTime.now().microsecondsSinceEpoch}',
            type: TimelineEventType.reflection,
            title: 'Goal priority set',
            detail: '${result.goal.title}: ${result.priority}',
            timestamp: DateTime.now(),
            status: TimelineEventStatus.info,
            phase: 'goal.config.priority.set',
            relatedId: result.goal.id,
          ),
        );

    ref.invalidate(goalByIdProvider(goalId));
    ref.invalidate(goalDetailsProvider(goalId));
    ref.invalidate(goalInsightsProvider);
    ref.invalidate(goalRecommendationsProvider);
    await _refreshCoachDecision();

    return result;
  }

  Future<GoalPriorityConfig?> updatePriority({
    required String goalId,
    required int priority,
  }) async {
    final GoalPriorityConfig? result = ref
        .read(featureUpdateGoalPriorityUseCaseProvider)
        .call(goalId: goalId, priority: priority);

    if (result == null) {
      return null;
    }

    await ref
        .read(timelineActionsProvider)
        .addMirroredEvent(
          TimelineEventEntity(
            id: 'goal-priority-updated-${result.goal.id}-${DateTime.now().microsecondsSinceEpoch}',
            type: TimelineEventType.reflection,
            title: 'Goal priority updated',
            detail: '${result.goal.title}: ${result.priority}',
            timestamp: DateTime.now(),
            status: TimelineEventStatus.info,
            phase: 'goal.config.priority.updated',
            relatedId: result.goal.id,
          ),
        );

    ref.invalidate(goalByIdProvider(goalId));
    ref.invalidate(goalDetailsProvider(goalId));
    ref.invalidate(goalInsightsProvider);
    ref.invalidate(goalRecommendationsProvider);
    await _refreshCoachDecision();

    return result;
  }

  String backupGoals() {
    return ref.read(featureBackupGoalsUseCaseProvider).call();
  }

  String exportGoals() {
    return ref.read(featureExportGoalsUseCaseProvider).call();
  }

  Future<List<GoalEntity>> importGoals(String jsonPayload) async {
    final List<GoalEntity> goals = await ref
        .read(featureImportGoalsUseCaseProvider)
        .call(jsonPayload);

    state = goals;

    await ref
        .read(reminderOrchestratorServiceProvider)
        .syncGoalReminders(state);

    ref.invalidate(goalSummaryProvider);
    ref.invalidate(goalAnalyticsProvider);
    ref.invalidate(goalInsightsProvider);
    ref.invalidate(goalRecommendationsProvider);
    ref.invalidate(goalProgressProvider);
    await _refreshCoachDecision();

    return goals;
  }

  Future<List<GoalEntity>> restoreGoals(List<GoalEntity> goals) async {
    final List<GoalEntity> restored = await ref
        .read(featureRestoreGoalsUseCaseProvider)
        .call(goals);

    state = restored;

    await ref
        .read(reminderOrchestratorServiceProvider)
        .syncGoalReminders(state);

    ref.invalidate(goalSummaryProvider);
    ref.invalidate(goalAnalyticsProvider);
    ref.invalidate(goalInsightsProvider);
    ref.invalidate(goalRecommendationsProvider);
    ref.invalidate(goalProgressProvider);
    await _refreshCoachDecision();

    return restored;
  }

  Future<TimelineEventEntity?> linkEmotion({
    required String goalId,
    required String emotionId,
  }) async {
    final TimelineEventEntity? event = await ref
        .read(featureLinkEmotionToGoalUseCaseProvider)
        .call(goalId: goalId, emotionId: emotionId);

    if (event != null) {
      _invalidateGoalStructure(event.relatedId);
      await _refreshCoachDecision();
    }

    return event;
  }

  Future<TimelineEventEntity?> unlinkEmotion({
    required String goalId,
    required String emotionId,
  }) async {
    final TimelineEventEntity? event = await ref
        .read(featureUnlinkEmotionFromGoalUseCaseProvider)
        .call(goalId: goalId, emotionId: emotionId);

    if (event != null) {
      _invalidateGoalStructure(event.relatedId);
      await _refreshCoachDecision();
    }

    return event;
  }

  Future<TimelineEventEntity?> linkHabit({
    required String goalId,
    required String habitId,
  }) async {
    final TimelineEventEntity? event = await ref
        .read(featureLinkHabitToGoalUseCaseProvider)
        .call(goalId: goalId, habitId: habitId);

    if (event != null) {
      _invalidateGoalStructure(event.relatedId);
      await _refreshCoachDecision();
    }

    return event;
  }

  Future<TimelineEventEntity?> unlinkHabit({
    required String goalId,
    required String habitId,
  }) async {
    final TimelineEventEntity? event = await ref
        .read(featureUnlinkHabitFromGoalUseCaseProvider)
        .call(goalId: goalId, habitId: habitId);

    if (event != null) {
      _invalidateGoalStructure(event.relatedId);
      await _refreshCoachDecision();
    }

    return event;
  }

  Future<TimelineEventEntity?> linkJournalEntry({
    required String goalId,
    required String journalEntryId,
  }) async {
    final TimelineEventEntity? event = await ref
        .read(featureLinkJournalEntryToGoalUseCaseProvider)
        .call(goalId: goalId, journalEntryId: journalEntryId);

    if (event != null) {
      _invalidateGoalStructure(event.relatedId);
      await _refreshCoachDecision();
    }

    return event;
  }

  Future<TimelineEventEntity?> unlinkJournalEntry({
    required String goalId,
    required String journalEntryId,
  }) async {
    final TimelineEventEntity? event = await ref
        .read(featureUnlinkJournalEntryFromGoalUseCaseProvider)
        .call(goalId: goalId, journalEntryId: journalEntryId);

    if (event != null) {
      _invalidateGoalStructure(event.relatedId);
      await _refreshCoachDecision();
    }

    return event;
  }

  Future<TimelineEventEntity?> linkFocusSession({
    required String goalId,
    required String focusSessionId,
  }) async {
    final TimelineEventEntity? event = await ref
        .read(featureLinkFocusSessionToGoalUseCaseProvider)
        .call(goalId: goalId, focusSessionId: focusSessionId);

    if (event != null) {
      _invalidateGoalStructure(event.relatedId);
      await _refreshCoachDecision();
    }

    return event;
  }

  Future<TimelineEventEntity?> unlinkFocusSession({
    required String goalId,
    required String focusSessionId,
  }) async {
    final TimelineEventEntity? event = await ref
        .read(featureUnlinkFocusSessionFromGoalUseCaseProvider)
        .call(goalId: goalId, focusSessionId: focusSessionId);

    if (event != null) {
      _invalidateGoalStructure(event.relatedId);
      await _refreshCoachDecision();
    }

    return event;
  }

  Future<TimelineEventEntity?> archiveGoal(String goalId) async {
    final TimelineEventEntity? event = await ref
        .read(featureArchiveGoalUseCaseProvider)
        .call(goalId);

    if (event != null) {
      _invalidateGoalStructure(event.relatedId);
      ref.invalidate(archivedGoalsProvider);
      ref.invalidate(activeGoalsProvider);
      ref.invalidate(goalInsightsProvider);
      ref.invalidate(goalRecommendationsProvider);
      await _refreshCoachDecision();
    }

    return event;
  }

  Future<TimelineEventEntity?> restoreGoalMetadata(String goalId) async {
    final TimelineEventEntity? event = await ref
        .read(featureRestoreGoalMetadataUseCaseProvider)
        .call(goalId);

    if (event != null) {
      _invalidateGoalStructure(event.relatedId);
      ref.invalidate(archivedGoalsProvider);
      ref.invalidate(activeGoalsProvider);
      ref.invalidate(goalInsightsProvider);
      ref.invalidate(goalRecommendationsProvider);
      await _refreshCoachDecision();
    }

    return event;
  }

  Future<TimelineEventEntity?> favoriteGoal(String goalId) async {
    final TimelineEventEntity? event = await ref
        .read(featureFavoriteGoalUseCaseProvider)
        .call(goalId);

    if (event != null) {
      _invalidateGoalStructure(event.relatedId);
      ref.invalidate(goalInsightsProvider);
      ref.invalidate(goalRecommendationsProvider);
      await _refreshCoachDecision();
    }

    return event;
  }

  Future<TimelineEventEntity?> unfavoriteGoal(String goalId) async {
    final TimelineEventEntity? event = await ref
        .read(featureUnfavoriteGoalUseCaseProvider)
        .call(goalId);

    if (event != null) {
      _invalidateGoalStructure(event.relatedId);
      ref.invalidate(goalInsightsProvider);
      ref.invalidate(goalRecommendationsProvider);
      await _refreshCoachDecision();
    }

    return event;
  }

  Future<TimelineEventEntity?> pinGoal(String goalId) async {
    final TimelineEventEntity? event = await ref
        .read(featurePinGoalUseCaseProvider)
        .call(goalId);

    if (event != null) {
      _invalidateGoalStructure(event.relatedId);
      ref.invalidate(goalInsightsProvider);
      ref.invalidate(goalRecommendationsProvider);
      await _refreshCoachDecision();
    }

    return event;
  }

  Future<TimelineEventEntity?> unpinGoal(String goalId) async {
    final TimelineEventEntity? event = await ref
        .read(featureUnpinGoalUseCaseProvider)
        .call(goalId);

    if (event != null) {
      _invalidateGoalStructure(event.relatedId);
      ref.invalidate(goalInsightsProvider);
      ref.invalidate(goalRecommendationsProvider);
      await _refreshCoachDecision();
    }

    return event;
  }

  Future<void> remove(String id) async {
    await complete(id);
  }

  Future<void> complete(String id) async {
    GoalEntity? selectedGoal;
    for (final GoalEntity goal in state) {
      if (goal.id == id) {
        selectedGoal = goal;
        break;
      }
    }

    await ref.read(completeGoalUseCaseProvider).call(id);
    state = state.where((g) => g.id != id).toList();
    await ref
        .read(reminderOrchestratorServiceProvider)
        .syncGoalReminders(state);
    if (selectedGoal != null) {
      AppAnalytics.track(
        'goal_completed',
        params: <String, Object?>{'goal_id': selectedGoal.id},
      );
      await _fanOutGoalEvent(goal: selectedGoal, action: _GoalAction.completed);
    }
    ref.invalidate(goalProgressProvider);
  }

  Future<void> _fanOutGoalEvent({
    required GoalEntity goal,
    required _GoalAction action,
  }) async {
    final DateTime now = DateTime.now();
    final String actionName = action.name;
    final String detailPrefix = switch (action) {
      _GoalAction.created => 'Goal created',
      _GoalAction.updated => 'Goal updated',
      _GoalAction.completed => 'Goal completed',
    };

    await _bestEffort(
      () => ref
          .read(logsActionsProvider)
          .addMirroredEntry(source: 'goal_$actionName', message: goal.title),
    );

    if (action == _GoalAction.created) {
      await _bestEffort(
        () => ref.read(timelineActionsProvider).connectGoal(goal),
      );
    } else {
      await _bestEffort(
        () => ref
            .read(timelineActionsProvider)
            .addMirroredEvent(
              TimelineEventEntity(
                id: 'timeline-goal-$actionName-${now.microsecondsSinceEpoch}',
                type: action == _GoalAction.completed
                    ? TimelineEventType.goalComplete
                    : TimelineEventType.reflection,
                title: detailPrefix,
                detail: goal.title,
                timestamp: now,
              ),
            ),
      );
    }

    final int progressionXp = switch (action) {
      _GoalAction.created => 12,
      _GoalAction.updated => 6,
      _GoalAction.completed => 40,
    };
    await _bestEffort(() async {
      ref.read(profileProvider.notifier).addXP(progressionXp);
    });
    ref.invalidate(insightsBundleProvider);
    await _refreshCoachDecision();
    ref
        .read(eventBusProvider)
        .emit(
          GoalLifecycleEvent(
            goalId: goal.id,
            title: goal.title,
            action: actionName,
          ),
        );
    await _bestEffort(
      () => ref
          .read(localMetricsAccumulatorProvider)
          .recordAutomationCheckpoint('goal_${actionName}_event_emitted'),
    );
  }

  Future<void> _refreshCoachDecision() async {
    try {
      await ref.read(generateSiDecisionUseCaseProvider).call();
      ref.invalidate(domainSiDecisionProvider);
    } catch (_) {
      // Avoid blocking goal updates if coach refresh fails.
    }
  }

  Future<void> _bestEffort(Future<void> Function() operation) async {
    try {
      await operation();
    } catch (_) {
      // Goal mutation already succeeded. Auxiliary automation should not fail
      // the user-facing action.
    }
  }
}

enum _GoalAction { created, updated, completed }
