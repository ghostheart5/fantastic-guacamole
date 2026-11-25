import 'dart:async';

import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/state/providers/account_operation.dart';
import 'package:fantastic_guacamole/state/providers/notification_provider.dart';
import 'package:fantastic_guacamole/state/providers/repository_providers.dart';
import 'package:fantastic_guacamole/state/providers/service_providers.dart';
import 'package:fantastic_guacamole/state/providers/settings_ui_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final taskReminderSyncProvider = Provider<TaskReminderSync>(
  (Ref ref) => TaskReminderSync(ref),
);

/// Brings this account's task reminders up to date after a task write.
/// Requests that arrive while one runs are folded into one more run, so a
/// burst of writes (a completion and its repeating successor, a restore)
/// costs at most two.
class TaskReminderSync {
  TaskReminderSync(this._ref);

  final Ref _ref;
  Future<void>? _running;
  bool _again = false;

  /// Completes once every request made so far has been applied.
  Future<void> get idle => _running ?? Future<void>.value();

  /// Never throws: the task is already saved, and a reminder that could not
  /// be updated is retried by the next write or resume.
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
      if (!notificationSchedulerReady(_ref)) return;
      await owner.wait(_ref.read(localTimezoneRefresherProvider)());
      // Reads the permission; never shows the system dialog.
      final bool granted = await owner.wait(
        _ref
            .read(notificationSchedulerProvider)
            .init(requestPermissions: false),
      );
      await owner.wait(
        _ref
            .read(reminderOrchestratorServiceProvider)
            .syncTaskReminders(
              permissionGranted: granted,
              shouldContinue: () => owner.isCurrent,
            ),
      );
      _ref.invalidate(automationNotificationsProvider);
    } on StaleAccountOperation {
      // The account changed; its next session reconciles on its own.
    } on Object catch (error) {
      // A container disposed mid-run (sign-out, app teardown) is not an
      // error: there is nothing left to update for it.
      if (!_ref.mounted) return;
      Logger.warn('Task reminders could not be updated ($error).');
    }
  }
}

/// Whether the notification scheduler was set up in this process (startup
/// does it outside mock mode). Before that nothing can be registered, so the
/// write-time syncs wait for the next full reconcile, which sets it up.
/// Never touches a platform channel.
bool notificationSchedulerReady(Ref ref) {
  try {
    return ref.read(notificationSchedulerProvider).isInitialized;
  } on Object {
    // A scheduler that cannot say counts as not set up.
    return false;
  }
}

/// The one place every task write passes through: create, edit, reschedule,
/// complete, skip, delete, the Creator's direct save, a repeating task's
/// successor and restore all reach the store through this wrapper, which
/// asks [TaskReminderSync] to update the task reminders after each write.
ITaskRepository reminderSyncingTaskStore(
  ITaskRepository store,
  void Function() changed,
) => store is IExactTaskSnapshotRepository
    ? _ExactReminderSyncingTaskStore(store, changed)
    : _ReminderSyncingTaskStore(store, changed);

class _ReminderSyncingTaskStore implements ITaskRepository {
  _ReminderSyncingTaskStore(this._store, this._changed);

  final ITaskRepository _store;
  final void Function() _changed;

  @override
  Future<List<TaskEntity>> getAllTasks() => _store.getAllTasks();

  @override
  Future<TaskEntity?> getTaskById(String id) => _store.getTaskById(id);

  @override
  Future<void> saveTask(TaskEntity task) async {
    await _store.saveTask(task);
    _changed();
  }

  @override
  Future<void> deleteTask(String id) async {
    await _store.deleteTask(id);
    _changed();
  }
}

class _ExactReminderSyncingTaskStore extends _ReminderSyncingTaskStore
    implements IExactTaskSnapshotRepository {
  _ExactReminderSyncingTaskStore(super._store, super._changed);

  @override
  Future<void> replaceTaskSnapshot(List<TaskEntity> tasks) async {
    await (_store as IExactTaskSnapshotRepository).replaceTaskSnapshot(tasks);
    _changed();
  }
}
