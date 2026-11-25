import 'package:fantastic_guacamole/core/storage/account_storage_namespace.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/notification_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/domain/ports/notification_scheduler_port.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/goal_reminder_sync_provider.dart';
import 'package:fantastic_guacamole/state/providers/repository_providers.dart';
import 'package:fantastic_guacamole/state/providers/service_providers.dart';
import 'package:fantastic_guacamole/state/providers/settings_ui_provider.dart';
import 'package:fantastic_guacamole/state/providers/task_reminder_sync_provider.dart';
import 'package:fantastic_guacamole/state/services/notifications_service.dart';
import 'package:fantastic_guacamole/state/services/reminder_orchestrator_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'task_reminder_test_support.dart';

const String _deadline = 'goal_reminder_g_3d';

void main() {
  test('linking a task to a goal updates that goal\'s reminder text', () async {
    final fixture = _Fixture();
    await fixture.write(
      (tasks) => tasks.saveTask(fixture.step('a', done: true)),
    );
    expect(fixture.scheduler.bodies[_deadline], endsWith('1 of 1 steps done.'));
    fixture.scheduler.clearLog();

    // A task created on its own and then linked to the goal.
    final loose = TaskEntity(
      id: 'b',
      title: 'Loose task',
      createdAt: DateTime.utc(2026, 10, 1),
    );
    await fixture.write((tasks) => tasks.saveTask(loose));
    expect(fixture.goalRegistrations, isEmpty);
    await fixture.write((tasks) => tasks.saveTask(loose.copyWith(goalId: 'g')));
    expect(fixture.goalRegistrations, contains(_deadline));
    expect(fixture.scheduler.bodies[_deadline], endsWith('1 of 2 steps done.'));
  });

  test('unlinking a task updates the goal it left', () async {
    final fixture = _Fixture();
    await fixture.write((tasks) async {
      await tasks.saveTask(fixture.step('a', done: true));
      await tasks.saveTask(fixture.step('b'));
    });
    expect(fixture.scheduler.bodies[_deadline], endsWith('1 of 2 steps done.'));
    fixture.scheduler.clearLog();

    await fixture.write(
      (tasks) async => tasks.saveTask(
        (await tasks.getTaskById('b'))!.copyWith(clearGoalId: true),
      ),
    );
    expect(fixture.scheduler.bodies[_deadline], endsWith('1 of 1 steps done.'));
  });

  test(
    'completing, skipping and deleting a linked task each update the goal',
    () async {
      final fixture = _Fixture();
      await fixture.write((tasks) async {
        for (final id in ['a', 'b', 'c', 'd']) {
          await tasks.saveTask(fixture.step(id));
        }
      });
      expect(
        fixture.scheduler.bodies[_deadline],
        endsWith('0 of 4 steps done.'),
      );

      fixture.scheduler.clearLog();
      await fixture.write(
        (tasks) async => tasks.saveTask(
          (await tasks.getTaskById('a'))!.complete(at: fixture.now),
        ),
      );
      expect(
        fixture.scheduler.bodies[_deadline],
        endsWith('1 of 4 steps done.'),
      );

      fixture.scheduler.clearLog();
      await fixture.write(
        (tasks) async => tasks.saveTask(
          (await tasks.getTaskById(
            'b',
          ))!.copyWith(isSkipped: true, skippedAt: fixture.now),
        ),
      );
      expect(fixture.goalRegistrations, contains(_deadline));
      expect(
        fixture.scheduler.bodies[_deadline],
        endsWith('1 of 3 steps done.'),
      );

      fixture.scheduler.clearLog();
      await fixture.write((tasks) => tasks.deleteTask('d'));
      expect(fixture.goalRegistrations, contains(_deadline));
      expect(
        fixture.scheduler.bodies[_deadline],
        endsWith('1 of 2 steps done.'),
      );
    },
  );

  test('a task with no goal leaves goal reminders alone', () async {
    final fixture = _Fixture();
    await fixture.write((tasks) => tasks.saveTask(fixture.step('a')));
    fixture.scheduler.clearLog();
    fixture.goalReads = 0;

    await fixture.write(
      (tasks) => tasks.saveTask(
        TaskEntity(id: 'x', title: 'Other', createdAt: DateTime.utc(2026, 10)),
      ),
    );
    await fixture.write((tasks) => tasks.deleteTask('x'));
    expect(fixture.goalReads, 0);
    expect(fixture.goalRegistrations, isEmpty);
  });

  test('restoring tasks updates the goal reminders only when a goal is '
      'involved', () async {
    final fixture = _Fixture();
    await fixture.write((tasks) => tasks.saveTask(fixture.step('a')));
    expect(fixture.scheduler.bodies[_deadline], endsWith('0 of 1 steps done.'));
    fixture.scheduler.clearLog();

    await fixture.write(
      (tasks) => (tasks as IExactTaskSnapshotRepository).replaceTaskSnapshot([
        fixture.step('a', done: true),
        fixture.step('b'),
      ]),
    );
    expect(fixture.scheduler.bodies[_deadline], endsWith('1 of 2 steps done.'));

    // From linked tasks to none: the goal still hears about it.
    await fixture.write(
      (tasks) =>
          (tasks as IExactTaskSnapshotRepository).replaceTaskSnapshot(const []),
    );
    fixture.goalReads = 0;
    await fixture.write(
      (tasks) =>
          (tasks as IExactTaskSnapshotRepository).replaceTaskSnapshot(const []),
    );
    expect(fixture.goalReads, 0);
  });
}

class _Fixture {
  _Fixture() {
    container = ProviderContainer(
      overrides: [
        accountStorageScopeProvider.overrideWithValue(
          AccountStorageScope.authenticated('goal-reminder-user'),
        ),
        accountLegacyOwnershipProvider.overrideWithValue(
          LegacyScopeOwnership.provenNotOwned,
        ),
        taskStoreProvider.overrideWithValue(store),
        domainGoalRepositoryProvider.overrideWithValue(
          _Goals(this, <GoalEntity>[
            GoalEntity(
              id: 'g',
              title: 'Run a 5K',
              createdAt: DateTime.utc(2026, 10, 1),
              targetDate: DateTime(2026, 11, 20),
            ),
          ]),
        ),
        notificationSchedulerProvider.overrideWithValue(scheduler),
        localTimezoneRefresherProvider.overrideWithValue(() async {}),
        reminderOrchestratorServiceProvider.overrideWith(
          (ref) => ReminderOrchestratorService(
            preferences: preferences,
            notifications: NotificationsService(NoNotificationList()),
            scheduler: scheduler,
            accountScope: testReminderScope,
            loadTasks: () => store.getAllTasks(),
            loadGoalTasks: () => store.getAllTasks(),
            now: () => now,
            isSpanish: () => false,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
  }

  final DateTime now = DateTime(2026, 11, 2, 15);
  final store = MemoryTaskStore();
  final scheduler = _BodyRecordingScheduler();
  final preferences = MemoryReminderPrefs();
  late final ProviderContainer container;
  int goalReads = 0;

  Iterable<String> get goalRegistrations => scheduler.registered.where(
    (String id) => id.startsWith('goal_reminder_'),
  );

  TaskEntity step(String id, {bool done = false}) => TaskEntity(
    id: id,
    title: 'Step $id',
    createdAt: DateTime.utc(2026, 10, 1),
    goalId: 'g',
    isCompleted: done,
  );

  Future<void> write(
    Future<void> Function(ITaskRepository tasks) change,
  ) async {
    await change(container.read(domainTaskRepositoryProvider));
    await container.read(taskReminderSyncProvider).idle;
    await container.read(goalReminderSyncProvider).idle;
  }
}

class _BodyRecordingScheduler extends RecordingTaskScheduler {
  final Map<String, String> bodies = <String, String>{};

  @override
  Future<NotificationScheduleResult> schedule(
    NotificationEntity notification, {
    String? accountScope,
  }) {
    bodies[notification.id] = notification.message;
    return super.schedule(notification, accountScope: accountScope);
  }
}

class _Goals implements IGoalRepository {
  _Goals(this._fixture, this._goals);

  final _Fixture _fixture;
  final List<GoalEntity> _goals;

  @override
  List<GoalEntity> getGoals() {
    _fixture.goalReads++;
    return List<GoalEntity>.of(_goals);
  }

  @override
  Future<void> saveGoal(GoalEntity goal) async {}

  @override
  Future<void> saveGoals(List<GoalEntity> goals) async {}

  @override
  Future<void> deleteGoal(String id) async {}
}
