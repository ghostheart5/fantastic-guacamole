import 'dart:async';

import 'package:fantastic_guacamole/core/debug/app_analytics.dart';
import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/core/eventing/domain_event.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/state/controllers/profile_controller.dart';
import 'package:fantastic_guacamole/state/models/goal_progress_view.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/auth_session_boundary_provider.dart';
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

final goalsReadProvider = Provider<AsyncValue<List<GoalEntity>>>((Ref ref) {
  if (!ref.watch(accountStorageScopeProvider).isWritable) {
    return const AsyncData(<GoalEntity>[]);
  }
  try {
    return AsyncData(ref.watch(getGoalsUseCaseProvider).call());
  } catch (error, stack) {
    return AsyncError(error, stack);
  }
});

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
  return GoalProgressView.fromTasks(linked);
});

class GoalsNotifier extends Notifier<List<GoalEntity>> {
  final Map<(String?, int, String), Future<GoalMutationResult>>
  _pendingCompletions = <(String?, int, String), Future<GoalMutationResult>>{};

  @override
  List<GoalEntity> build() {
    // The provider graph can refresh before AppRoot removes the old screen.
    // Fenced storage must produce no account content or reminder work.
    if (!ref.watch(accountStorageScopeProvider).isWritable) {
      return const <GoalEntity>[];
    }
    // Completed goals are retained in storage (CompleteGoal no longer deletes)
    // but stay out of the active list, preserving the previous UI behaviour.
    final read = ref.watch(goalsReadProvider);
    if (read.hasError) return const <GoalEntity>[];
    final List<GoalEntity> goals =
        (read.asData?.value ?? <GoalEntity>[])
            .where((GoalEntity goal) => !goal.isCompleted)
            .toList(growable: false)
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final reminders = ref.read(reminderOrchestratorServiceProvider);
    final operation = _GoalAccountOperation.capture(ref);
    unawaited(
      Future<void>(() async {
        await _auxiliary(operation, 'reminders', () async {
          await reminders.syncGoalReminders(
            goals,
            shouldContinue: () => operation.isCurrent(ref),
          );
          if (!operation.isCurrent(ref)) return;
          await reminders.ensureDailyPlanningReminder(
            shouldContinue: () => operation.isCurrent(ref),
          );
        }, <String>[]);
      }),
    );
    return goals;
  }

  Future<GoalMutationResult> add({
    required String title,
    String? description,
    DateTime? targetDate,
  }) async {
    final operation = _GoalAccountOperation.capture(ref);
    operation.requireCurrent(ref);
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
    if (!operation.isCurrent(ref)) return const GoalMutationResult.stale();
    state = [goal, ...state];
    return _afterSave(operation, goal, _GoalAction.created);
  }

  Future<GoalMutationResult> update(GoalEntity updated) async {
    final operation = _GoalAccountOperation.capture(ref);
    operation.requireCurrent(ref);
    await ref.read(updateGoalUseCaseProvider).call(updated);
    if (!operation.isCurrent(ref)) return const GoalMutationResult.stale();
    state = state.map((g) => g.id == updated.id ? updated : g).toList();
    return _afterSave(operation, updated, _GoalAction.updated);
  }

  Future<void> remove(String id) async {
    await complete(id);
  }

  Future<GoalMutationResult> complete(String id) async {
    final operation = _GoalAccountOperation.capture(ref);
    operation.requireCurrent(ref);
    final key = (operation.namespace, operation.generation, id);
    final pending = _pendingCompletions[key];
    if (pending != null) return pending;
    final completion = _complete(id, operation);
    _pendingCompletions[key] = completion;
    try {
      return await completion;
    } finally {
      if (identical(_pendingCompletions[key], completion)) {
        // This is the same completion already awaited above.
        unawaited(_pendingCompletions.remove(key));
      }
    }
  }

  Future<GoalMutationResult> _complete(
    String id,
    _GoalAccountOperation operation,
  ) async {
    GoalEntity? selectedGoal;
    for (final GoalEntity goal in state) {
      if (goal.id == id) {
        selectedGoal = goal;
        break;
      }
    }

    await ref.read(completeGoalUseCaseProvider).call(id);
    if (!operation.isCurrent(ref)) return const GoalMutationResult.stale();
    state = state.where((g) => g.id != id).toList();
    return _afterSave(operation, selectedGoal, _GoalAction.completed);
  }

  Future<GoalMutationResult> _afterSave(
    _GoalAccountOperation operation,
    GoalEntity? goal,
    _GoalAction action,
  ) async {
    final List<String> warnings = <String>[];
    await _auxiliary(operation, 'reminders', () async {
      await ref
          .read(reminderOrchestratorServiceProvider)
          .syncGoalReminders(
            state,
            shouldContinue: () => operation.isCurrent(ref),
          );
    }, warnings);
    if (goal != null) {
      await _auxiliary(operation, 'analytics', () async {
        AppAnalytics.track(
          'goal_${action.name}',
          params: <String, Object?>{'has_goal_id': goal.id.isNotEmpty},
        );
      }, warnings);
      await _fanOutGoalEvent(
        operation: operation,
        goal: goal,
        action: action,
        warnings: warnings,
      );
    }
    if (operation.isCurrent(ref)) {
      ref.invalidate(goalProgressProvider);
      ref.invalidate(goalsReadProvider);
      ref.invalidate(signalsBundleProvider);
    }
    return GoalMutationResult(
      warnings: List<String>.unmodifiable(warnings),
      accountChanged: !operation.isCurrent(ref),
    );
  }

  Future<void> _fanOutGoalEvent({
    required _GoalAccountOperation operation,
    required GoalEntity goal,
    required _GoalAction action,
    required List<String> warnings,
  }) async {
    final DateTime now = DateTime.now();
    final String actionName = action.name;
    final String detailPrefix = switch (action) {
      _GoalAction.created => 'Goal created',
      _GoalAction.updated => 'Goal updated',
      _GoalAction.completed => 'Goal completed',
    };

    await _auxiliary(operation, 'history', () async {
      await ref
          .read(logsActionsProvider)
          .addMirroredEntry(
            source: 'goal_$actionName',
            message: goal.title,
            shouldContinue: () => operation.isCurrent(ref),
          );
    }, warnings);

    await _auxiliary(operation, 'timeline', () async {
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
            shouldContinue: () => operation.isCurrent(ref),
          );
    }, warnings);

    final int progressionXp = switch (action) {
      _GoalAction.created => 12,
      _GoalAction.updated => 6,
      _GoalAction.completed => 40,
    };
    await _auxiliary(operation, 'progress', () async {
      await ref
          .read(profileProvider.notifier)
          .awardXP(
            progressionXp,
            source: 'goal_$actionName',
            shouldContinue: () => operation.isCurrent(ref),
          );
    }, warnings);
    await _auxiliary(operation, 'planner', () async {
      await ref.read(generateSiDecisionUseCaseProvider).call();
      if (operation.isCurrent(ref)) ref.invalidate(domainSiDecisionProvider);
    }, warnings);
    await _auxiliary(operation, 'activity', () async {
      ref
          .read(eventBusProvider)
          .emit(
            GoalLifecycleEvent(
              goalId: goal.id,
              title: goal.title,
              action: actionName,
            ),
          );
    }, warnings);
  }

  Future<void> _auxiliary(
    _GoalAccountOperation operation,
    String label,
    Future<void> Function() action,
    List<String> warnings,
  ) async {
    if (!operation.isCurrent(ref)) return;
    try {
      await action();
    } catch (error, stack) {
      warnings.add(label);
      Logger.errorCategory(
        'GoalSupportingUpdate',
        'Goal saved, but its $label update could not finish.',
        error,
        stack,
      );
    }
  }
}

/// Returned only after the canonical goal mutation has completed. Auxiliary
/// failures must never invite the UI to retry an already durable goal save.
class GoalMutationResult {
  const GoalMutationResult({
    this.warnings = const <String>[],
    this.accountChanged = false,
  });
  const GoalMutationResult.stale()
    : warnings = const <String>[],
      accountChanged = true;

  final List<String> warnings;
  final bool accountChanged;
  bool get hasWarnings => warnings.isNotEmpty;
}

final class _GoalAccountOperation {
  const _GoalAccountOperation(this.namespace, this.generation);

  factory _GoalAccountOperation.capture(Ref ref) => _GoalAccountOperation(
    ref.read(accountStorageScopeProvider).v2Namespace,
    ref.read(authSessionBoundaryProvider).generation,
  );

  final String? namespace;
  final int generation;

  bool isCurrent(Ref ref) {
    if (!ref.mounted) return false;
    try {
      final AccountStorageScope scope = ref.read(accountStorageScopeProvider);
      return scope.isWritable &&
          scope.v2Namespace == namespace &&
          ref.read(authSessionBoundaryProvider).generation == generation;
    } on Object {
      // A broken or unavailable boundary must stop supporting work, including
      // after a durable save. It cannot safely authorize any account effects.
      return false;
    }
  }

  void requireCurrent(Ref ref) {
    if (!isCurrent(ref)) {
      throw StateError('Goals require authenticated account storage.');
    }
  }
}

enum _GoalAction { created, updated, completed }
