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
class TaskReminderSync extends ReminderSyncRunner {
  TaskReminderSync(super.ref) : super(name: 'Task', sync: _syncTasks);

  static Future<void> _syncTasks(
    Ref ref,
    AccountOperation owner,
    bool granted,
  ) async {
    await owner.wait(
      ref
          .read(reminderOrchestratorServiceProvider)
          .syncTaskReminders(
            permissionGranted: granted,
            shouldContinue: () => owner.isCurrent,
          ),
    );
    ref.invalidate(automationNotificationsProvider);
  }
}

/// One run of a write-time reminder sync, after the shared checks.
typedef ReminderSyncRun =
    Future<void> Function(Ref ref, AccountOperation owner, bool granted);

/// Runs one write-time reminder sync per request. Requests that arrive while
/// one runs are folded into one more run, so a burst of writes (a completion
/// and its repeating successor, a restore) costs at most two. Each run checks
/// the account, waits until the scheduler is set up, refreshes the time zone
/// and reads the permission (never showing the system dialog) before handing
/// over to [sync].
class ReminderSyncRunner {
  ReminderSyncRunner(this._ref, {required this._name, required this._sync});

  final Ref _ref;
  final String _name;
  final ReminderSyncRun _sync;
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
      await _sync(_ref, owner, granted);
    } on StaleAccountOperation {
      // The account changed; its next session reconciles on its own.
    } on Object catch (error) {
      // A container disposed mid-run (sign-out, app teardown) is not an
      // error: there is nothing left to update for it.
      if (!_ref.mounted) return;
      Logger.warn('$_name reminders could not be updated ($error).');
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
/// calls [changed] after each write.
///
/// With [concerns], only writes to a task that matches it before or after
/// the write call [changed]; when the stored task cannot be read, the write
/// counts as matching.
ITaskRepository reminderSyncingTaskStore(
  ITaskRepository store,
  void Function() changed, {
  bool Function(TaskEntity task)? concerns,
}) => store is IExactTaskSnapshotRepository
    ? _ExactReminderSyncingTaskStore(store, changed, concerns)
    : _ReminderSyncingTaskStore(store, changed, concerns);

class _ReminderSyncingTaskStore implements ITaskRepository {
  _ReminderSyncingTaskStore(this._store, this._changed, this._concerns);

  final ITaskRepository _store;
  final void Function() _changed;
  final bool Function(TaskEntity task)? _concerns;

  @override
  Future<List<TaskEntity>> getAllTasks() => _store.getAllTasks();

  @override
  Future<TaskEntity?> getTaskById(String id) => _store.getTaskById(id);

  @override
  Future<void> saveTask(TaskEntity task) async {
    final bool relevant = _matches(task) || await _storedMatches(task.id);
    await _store.saveTask(task);
    if (relevant) _changed();
  }

  @override
  Future<void> deleteTask(String id) async {
    final bool relevant = await _storedMatches(id);
    await _store.deleteTask(id);
    if (relevant) _changed();
  }

  bool _matches(TaskEntity task) => _concerns?.call(task) ?? true;

  Future<bool> _storedMatches(String id) => _readMatches(() async {
    final TaskEntity? stored = await _store.getTaskById(id);
    return stored != null && _matches(stored);
  });

  Future<bool> _readMatches(Future<bool> Function() read) async {
    if (_concerns == null) return true;
    try {
      return await read();
    } on Object {
      return true;
    }
  }
}

class _ExactReminderSyncingTaskStore extends _ReminderSyncingTaskStore
    implements IExactTaskSnapshotRepository {
  _ExactReminderSyncingTaskStore(super._store, super._changed, super._concerns);

  @override
  Future<void> replaceTaskSnapshot(List<TaskEntity> tasks) async {
    final bool relevant =
        tasks.any(_matches) ||
        await _readMatches(
          () async => (await _store.getAllTasks()).any(_matches),
        );
    await (_store as IExactTaskSnapshotRepository).replaceTaskSnapshot(tasks);
    if (relevant) _changed();
  }
}
