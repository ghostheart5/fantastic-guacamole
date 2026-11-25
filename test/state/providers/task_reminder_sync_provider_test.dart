import 'package:fantastic_guacamole/core/storage/account_storage_namespace.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/repository_providers.dart';
import 'package:fantastic_guacamole/state/providers/service_providers.dart';
import 'package:fantastic_guacamole/state/providers/settings_ui_provider.dart';
import 'package:fantastic_guacamole/state/providers/task_reminder_sync_provider.dart';
import 'package:fantastic_guacamole/state/services/notifications_service.dart';
import 'package:fantastic_guacamole/state/services/reminder_orchestrator_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'task_reminder_test_support.dart';

void main() {
  test('a task saved through the task store gets its reminder', () async {
    final fixture = _Fixture();
    await fixture.write((tasks) => tasks.saveTask(fixture.dated('a', 2)));

    expect(fixture.scheduler.pending, {'task_reminder_start_a'});
  });

  test('completing a task cancels its reminder', () async {
    final fixture = _Fixture();
    final task = fixture.dated('a', 2);
    await fixture.write((tasks) => tasks.saveTask(task));
    fixture.scheduler.clearLog();

    // What the completion path stores for the task.
    await fixture.write(
      (tasks) => tasks.saveTask(task.complete(at: fixture.now)),
    );
    expect(fixture.scheduler.cancelled, ['task_reminder_start_a']);
    expect(fixture.scheduler.pending, isEmpty);
  });

  test('rescheduling a task moves its reminder', () async {
    final fixture = _Fixture();
    final task = fixture.dated('a', 2);
    await fixture.write((tasks) => tasks.saveTask(task));
    fixture.scheduler.clearLog();

    final DateTime later = fixture.now.add(const Duration(hours: 6));
    await fixture.container
        .read(updateTaskUseCaseProvider)
        .call(task.copyWith(scheduledFor: later));
    await fixture.idle();
    expect(fixture.scheduler.registered, ['task_reminder_start_a']);
    expect(fixture.scheduler.times['task_reminder_start_a'], later);
  });

  test('deleting a task cancels its reminder', () async {
    final fixture = _Fixture();
    await fixture.write((tasks) => tasks.saveTask(fixture.dated('a', 2)));
    fixture.scheduler.clearLog();

    await fixture.container.read(deleteTaskUseCaseProvider).call('a');
    await fixture.idle();
    expect(fixture.scheduler.cancelled, ['task_reminder_start_a']);
  });

  test('a repeating task successor takes over the reminder', () async {
    final fixture = _Fixture();
    final first = fixture.dated('a', 2);
    await fixture.write((tasks) => tasks.saveTask(first));
    fixture.scheduler.clearLog();

    await fixture.write((tasks) async {
      await tasks.saveTask(first.complete(at: fixture.now));
      await tasks.saveTask(fixture.dated('a-next', 26));
    });
    expect(fixture.scheduler.pending, {'task_reminder_start_a-next'});
  });

  test('restoring a backup updates the task reminders', () async {
    final fixture = _Fixture();
    await fixture.write((tasks) => tasks.saveTask(fixture.dated('a', 2)));
    fixture.scheduler.clearLog();

    await fixture.write(
      (tasks) => (tasks as IExactTaskSnapshotRepository).replaceTaskSnapshot(
        <TaskEntity>[fixture.dated('b', 3)],
      ),
    );
    expect(fixture.scheduler.pending, {'task_reminder_start_b'});
  });

  test('writes made while a sync runs are applied afterwards', () async {
    final fixture = _Fixture();
    final tasks = fixture.container.read(domainTaskRepositoryProvider);
    await tasks.saveTask(fixture.dated('a', 2));
    await tasks.saveTask(fixture.dated('b', 3));
    await tasks.saveTask(fixture.dated('c', 4));
    await fixture.idle();

    expect(fixture.scheduler.pending, {
      'task_reminder_start_a',
      'task_reminder_start_b',
      'task_reminder_start_c',
    });
  });

  test('without permission nothing is registered and nothing fails', () async {
    final fixture = _Fixture()..scheduler.granted = false;
    await fixture.write((tasks) => tasks.saveTask(fixture.dated('a', 2)));

    expect(fixture.scheduler.registered, isEmpty);
    expect(fixture.store.tasks, contains('a'));
  });

  test('before the scheduler is set up a write touches nothing', () async {
    final fixture = _Fixture()..scheduler.isInitialized = false;
    await fixture.write((tasks) => tasks.saveTask(fixture.dated('a', 2)));

    expect(fixture.timezoneRefreshes, 0);
    expect(fixture.scheduler.permissionReads, 0);
    expect(fixture.scheduler.registered, isEmpty);
    expect(fixture.store.tasks, contains('a'));
  });

  test(
    'a sync still running when its container goes settles quietly',
    () async {
      final fixture = _Fixture();
      final tasks = fixture.container.read(domainTaskRepositoryProvider);
      final sync = fixture.container.read(taskReminderSyncProvider);
      await tasks.saveTask(fixture.dated('a', 2));
      final Future<void> running = sync.idle;
      fixture.container.dispose();

      await expectLater(running, completes);
    },
  );
}

class _Fixture {
  _Fixture() {
    container = ProviderContainer(
      overrides: [
        accountStorageScopeProvider.overrideWithValue(
          AccountStorageScope.authenticated('task-reminder-user'),
        ),
        accountLegacyOwnershipProvider.overrideWithValue(
          LegacyScopeOwnership.provenNotOwned,
        ),
        taskStoreProvider.overrideWithValue(store),
        notificationSchedulerProvider.overrideWithValue(scheduler),
        localTimezoneRefresherProvider.overrideWithValue(
          () async => timezoneRefreshes++,
        ),
        reminderOrchestratorServiceProvider.overrideWith(
          (ref) => ReminderOrchestratorService(
            preferences: preferences,
            notifications: NotificationsService(NoNotificationList()),
            scheduler: scheduler,
            accountScope: testReminderScope,
            loadTasks: () => store.getAllTasks(),
            now: () => now,
            isSpanish: () => false,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
  }

  final DateTime now = DateTime.utc(2026, 11, 2, 15);
  final store = MemoryTaskStore();
  final scheduler = RecordingTaskScheduler();
  final preferences = MemoryReminderPrefs();
  int timezoneRefreshes = 0;
  late final ProviderContainer container;

  TaskEntity dated(String id, int hours) => TaskEntity(
    id: id,
    title: 'Task $id',
    createdAt: DateTime.utc(2026, 10, 1),
    scheduledFor: now.add(Duration(hours: hours)),
  );

  Future<void> idle() => container.read(taskReminderSyncProvider).idle;

  Future<void> write(
    Future<void> Function(ITaskRepository tasks) change,
  ) async {
    await change(container.read(domainTaskRepositoryProvider));
    await idle();
  }
}
