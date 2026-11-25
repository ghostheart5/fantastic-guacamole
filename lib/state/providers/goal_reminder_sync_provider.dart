import 'dart:async';

import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/state/providers/account_operation.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/repository_providers.dart';
import 'package:fantastic_guacamole/state/providers/service_providers.dart';
import 'package:fantastic_guacamole/state/providers/settings_ui_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final goalReminderSyncProvider = Provider<GoalReminderSync>(
  (Ref ref) => GoalReminderSync(ref),
);

/// Brings this account's goal reminders up to date after a change to a
/// goal's linked tasks, so the step counts and the "almost there" nudge stay
/// current. Requests that arrive while one runs are folded into one more run.
class GoalReminderSync {
  GoalReminderSync(this._ref);

  final Ref _ref;
  Future<void>? _running;
  bool _again = false;

  /// Completes once every request made so far has been applied.
  Future<void> get idle => _running ?? Future<void>.value();

  /// Never throws: the task is already saved, and a reminder that could not
  /// be updated is retried by the next change or resume.
  Future<void> request() {
    _again = true;
    return _running ??= _drain();
  }

  Future<void> _drain() async {
    try {
      while (_again) {
        _again = false;
        await _syncOnce();
      }
    } finally {
      _running = null;
    }
  }

  Future<void> _syncOnce() async {
    if (!_ref.mounted) return;
    try {
      final AccountOperation owner = AccountOperation.capture(_ref);
      if (!owner.isCurrent) return;
      await owner.wait(_ref.read(localTimezoneRefresherProvider)());
      // Reads the permission; never shows the system dialog.
      final bool granted = await owner.wait(
        _ref
            .read(notificationSchedulerProvider)
            .init(requestPermissions: false),
      );
      final List<GoalEntity> goals = _ref.read(getGoalsUseCaseProvider).call();
      owner.check();
      await owner.wait(
        _ref
            .read(reminderOrchestratorServiceProvider)
            .syncGoalReminderGroup(
              goals: goals,
              permissionGranted: granted,
              shouldContinue: () => owner.isCurrent,
            ),
      );
    } on StaleAccountOperation {
      // The account changed; its next session reconciles on its own.
    } on Object catch (error) {
      Logger.warn('Goal reminders could not be updated ($error).');
    }
  }
}

/// Wraps the task store so every write to a task that has or had a goal
/// (create, edit including linking and unlinking, complete, skip, delete,
/// restore) asks [GoalReminderSync] to update the goal reminders.
ITaskRepository goalReminderSyncingTaskStore(
  ITaskRepository store,
  void Function() goalsChanged,
) => store is IExactTaskSnapshotRepository
    ? _ExactGoalReminderSyncingTaskStore(store, goalsChanged)
    : _GoalReminderSyncingTaskStore(store, goalsChanged);

class _GoalReminderSyncingTaskStore implements ITaskRepository {
  _GoalReminderSyncingTaskStore(this._store, this._goalsChanged);

  final ITaskRepository _store;
  final void Function() _goalsChanged;

  @override
  Future<List<TaskEntity>> getAllTasks() => _store.getAllTasks();

  @override
  Future<TaskEntity?> getTaskById(String id) => _store.getTaskById(id);

  @override
  Future<void> saveTask(TaskEntity task) async {
    final bool linked = _hasGoal(task) || await _hadGoal(task.id);
    await _store.saveTask(task);
    if (linked) _goalsChanged();
  }

  @override
  Future<void> deleteTask(String id) async {
    final bool linked = await _hadGoal(id);
    await _store.deleteTask(id);
    if (linked) _goalsChanged();
  }

  static bool _hasGoal(TaskEntity? task) =>
      task?.goalId?.trim().isNotEmpty ?? false;

  /// Whether the stored task belongs to a goal. When it cannot be read the
  /// goal reminders are updated anyway.
  Future<bool> _hadGoal(String id) async {
    try {
      return _hasGoal(await _store.getTaskById(id));
    } on Object {
      return true;
    }
  }
}

class _ExactGoalReminderSyncingTaskStore extends _GoalReminderSyncingTaskStore
    implements IExactTaskSnapshotRepository {
  _ExactGoalReminderSyncingTaskStore(super._store, super._goalsChanged);

  @override
  Future<void> replaceTaskSnapshot(List<TaskEntity> tasks) async {
    // A restore can change any goal's steps.
    final bool linked =
        tasks.any(_GoalReminderSyncingTaskStore._hasGoal) ||
        await _anyHadGoal();
    await (_store as IExactTaskSnapshotRepository).replaceTaskSnapshot(tasks);
    if (linked) _goalsChanged();
  }

  Future<bool> _anyHadGoal() async {
    try {
      return (await _store.getAllTasks()).any(
        _GoalReminderSyncingTaskStore._hasGoal,
      );
    } on Object {
      return true;
    }
  }
}
