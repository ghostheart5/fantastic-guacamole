import 'dart:async';

import 'package:fantastic_guacamole/core/debug/app_analytics.dart';
import 'package:fantastic_guacamole/core/eventing/domain_event.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/state/controllers/profile_controller.dart';
import 'package:fantastic_guacamole/state/models/goal_progress_view.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/event_bus_provider.dart';
import 'package:fantastic_guacamole/state/providers/signals_provider.dart';
import 'package:fantastic_guacamole/state/providers/logs_provider.dart';
import 'package:fantastic_guacamole/state/providers/service_providers.dart';
import 'package:fantastic_guacamole/state/providers/timeline_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final goalsProvider = NotifierProvider<GoalsNotifier, List<GoalEntity>>(
  GoalsNotifier.new,
);

final goalProvider = goalsProvider;

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

class GoalsNotifier extends Notifier<List<GoalEntity>> {
  @override
  List<GoalEntity> build() {
    // Completed goals are retained in storage (CompleteGoal no longer deletes)
    // but stay out of the active list, preserving the previous UI behaviour.
    final List<GoalEntity> goals = ref
        .watch(getGoalsUseCaseProvider)
        .call()
        .where((GoalEntity goal) => !goal.isCompleted)
        .toList(growable: false);
    final reminders = ref.read(reminderOrchestratorServiceProvider);
    unawaited(
      Future<void>(() async {
        await reminders.syncGoalReminders(goals);
        await reminders.ensureDailyPlanningReminder();
      }),
    );
    return goals;
  }

  Future<void> add({
    required String title,
    String? description,
    DateTime? targetDate,
  }) async {
    final goal = GoalEntity(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: title.trim(),
      createdAt: DateTime.now(),
      description: description?.trim().isEmpty ?? true
          ? null
          : description?.trim(),
      targetDate: targetDate,
    );
    await ref.read(createGoalUseCaseProvider).call(goal);
    state = [goal, ...state];
    AppAnalytics.track(
      'goal_created',
      params: <String, Object?>{'has_goal_id': goal.id.isNotEmpty},
    );
    await ref
        .read(reminderOrchestratorServiceProvider)
        .syncGoalReminders(state);
    await _fanOutGoalEvent(goal: goal, action: _GoalAction.created);
    ref.invalidate(goalProgressProvider);
  }

  Future<void> update(GoalEntity updated) async {
    await ref.read(updateGoalUseCaseProvider).call(updated);
    state = state.map((g) => g.id == updated.id ? updated : g).toList();
    await ref
        .read(reminderOrchestratorServiceProvider)
        .syncGoalReminders(state);
    await _fanOutGoalEvent(goal: updated, action: _GoalAction.updated);
    ref.invalidate(goalProgressProvider);
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
        params: <String, Object?>{'has_goal_id': selectedGoal.id.isNotEmpty},
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

    await ref
        .read(logsActionsProvider)
        .addMirroredEntry(source: 'goal_$actionName', message: goal.title);

    await ref
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
        );

    final int progressionXp = switch (action) {
      _GoalAction.created => 12,
      _GoalAction.updated => 6,
      _GoalAction.completed => 40,
    };
    await ref
        .read(profileProvider.notifier)
        .awardXP(progressionXp, source: 'goal_$actionName');
    ref.invalidate(signalsBundleProvider);
    await _refreshPlannerDecision();
    ref
        .read(eventBusProvider)
        .emit(
          GoalLifecycleEvent(
            goalId: goal.id,
            title: goal.title,
            action: actionName,
          ),
        );
  }

  Future<void> _refreshPlannerDecision() async {
    try {
      await ref.read(generateSiDecisionUseCaseProvider).call();
      ref.invalidate(domainSiDecisionProvider);
    } catch (_) {
      // Avoid blocking goal updates if planner refresh fails.
    }
  }
}

enum _GoalAction { created, updated, completed }
