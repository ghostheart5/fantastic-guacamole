import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/entities/notification_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_habit_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_notification_repository.dart';
import 'package:fantastic_guacamole/domain/ports/notification_scheduler_port.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/habit_occurrence_provider.dart';
import 'package:fantastic_guacamole/state/providers/habits_provider.dart';
import 'package:fantastic_guacamole/state/providers/repository_providers.dart';
import 'package:fantastic_guacamole/state/providers/service_providers.dart';
import 'package:fantastic_guacamole/state/providers/settings_ui_provider.dart';
import 'package:fantastic_guacamole/state/providers/sync_provider.dart';
import 'package:fantastic_guacamole/state/services/notifications_service.dart';
import 'package:fantastic_guacamole/state/services/reflection_reminder_service.dart';
import 'package:fantastic_guacamole/state/services/reminder_orchestrator_service.dart';
import 'package:fantastic_guacamole/system/notifications/notification_scheduler.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _legacy = 'habit_reminder_daily';
const _done = 'legacy_habit_reminder_migrated';

/// The one-time move from the old shared 8 PM rhythm reminder to per-rhythm
/// times must win against every other reminder path, whichever runs first.
void main() {
  test(
    'app start or resume reconcile first, then the habits build, keeps 8 PM',
    () async {
      final fixture = _Fixture(legacyPending: true);
      await fixture.resumeReconcile();
      expect(
        fixture.log,
        isNot(contains('os-cancel:$_legacy')),
        reason: 'The reconcile must leave the old reminder for the migration.',
      );
      await fixture.buildHabits();
      fixture.expectMigrated();
    },
  );

  test(
    'a cloud restore reconcile first, then the habits build, keeps 8 PM',
    () async {
      final fixture = _Fixture(legacyPending: true);
      await fixture.restoreReconcile();
      expect(fixture.log, isNot(contains('os-cancel:$_legacy')));
      await fixture.buildHabits();
      fixture.expectMigrated();
    },
  );

  test('the habits build first, then a reconcile, keeps 8 PM', () async {
    final fixture = _Fixture(legacyPending: true);
    await fixture.buildHabits();
    await fixture.resumeReconcile();
    fixture.expectMigrated();
  });

  test(
    'the habits build migrates before its first reminder sync registers',
    () async {
      final fixture = _Fixture(legacyPending: true);
      await fixture.buildHabits();
      fixture.expectMigrated();
      final save = fixture.log.indexOf('save');
      final cancel = fixture.log.indexOf('os-cancel:$_legacy');
      final registered = fixture.log.indexOf('cadence:habit_reminder_a@20:00');
      expect(save, greaterThanOrEqualTo(0));
      expect(cancel, greaterThan(save));
      expect(registered, greaterThan(cancel));
      expect(
        fixture.container
            .read(habitsProvider)
            .requireValue
            .first
            .reminderMinutes,
        20 * 60,
      );
    },
  );

  test('running every path twice changes nothing more', () async {
    final fixture = _Fixture(legacyPending: true);
    await fixture.resumeReconcile();
    await fixture.restoreReconcile();
    await fixture.buildHabits();
    final habits = fixture.habits.values;
    await fixture.resumeReconcile();
    await fixture.restoreReconcile();
    fixture.container.invalidate(habitsProvider);
    await fixture.buildHabits();
    expect(fixture.habits.values, habits);
    expect(fixture.log.where((entry) => entry == 'save'), hasLength(1));
    fixture.expectMigrated();
  });

  test('an account that never had the old reminder is untouched', () async {
    final fixture = _Fixture(legacyPending: false);
    await fixture.resumeReconcile();
    await fixture.restoreReconcile();
    await fixture.buildHabits();
    expect(fixture.habits.values.map((habit) => habit.reminderMinutes), [
      null,
      null,
      9 * 60,
    ]);
    expect(fixture.log, isNot(contains('save')));
    expect(fixture.preferences.load(_done), 'true');
  });

  test(
    'turning rhythm reminders off then on still gives each rhythm 8 PM',
    () async {
      final fixture = _Fixture(legacyPending: true);
      final actions = fixture.container.read(settingsUiActionsProvider);
      await actions.setHabitRemindersEnabled(false);
      // The user's choice wins: the old reminder is gone while they are off.
      expect(fixture.scheduler.pending, isNot(contains(_legacy)));
      await actions.setHabitRemindersEnabled(true);
      await fixture.buildHabits();
      expect(fixture.habits.values.map((habit) => habit.reminderMinutes), [
        20 * 60,
        null,
        9 * 60,
      ]);
      expect(fixture.preferences.load(_done), 'true');
      expect(fixture.scheduler.pending, contains('habit_reminder_a'));
    },
  );

  test('turned off, nothing is re-created', () async {
    final fixture = _Fixture(legacyPending: true);
    await fixture.container
        .read(settingsUiActionsProvider)
        .setHabitRemindersEnabled(false);
    await fixture.resumeReconcile();
    await fixture.buildHabits();
    expect(fixture.scheduler.pending, isNot(contains(_legacy)));
    expect(
      fixture.scheduler.pending.where((id) => id.startsWith('habit_')),
      isEmpty,
    );
    expect(fixture.log, isNot(contains('save')));
  });
}

class _Fixture {
  _Fixture({required bool legacyPending}) {
    if (legacyPending) scheduler.pending.add(_legacy);
    habits = _Habits(log, [
      habit('a'),
      habit('b', status: HabitStatus.paused),
      habit('c', reminderMinutes: 9 * 60),
    ]);
    container = ProviderContainer(
      overrides: [
        accountStorageScopeProvider.overrideWithValue(
          AccountStorageScope.authenticated('legacy-reminder-user'),
        ),
        domainHabitRepositoryProvider.overrideWithValue(habits),
        domainGoalRepositoryProvider.overrideWithValue(_Goals()),
        habitOccurrenceCoordinatorProvider.overrideWithValue(null),
        notificationSchedulerProvider.overrideWithValue(scheduler),
        reminderOrchestratorServiceProvider.overrideWithValue(
          ReminderOrchestratorService(
            preferences: preferences,
            notifications: NotificationsService(_Notifications(scheduler)),
            scheduler: scheduler,
            accountScope: 'qa',
            now: () => DateTime(2026, 11, 23, 10),
            loadHabitOccurrences: () async => [],
          ),
        ),
        reflectionReminderServiceProvider.overrideWithValue(
          ReflectionReminderService(
            preferences: preferences,
            scheduler: scheduler,
            permissionListenable: ValueNotifier<bool?>(true),
            accountScope: 'qa',
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
  }

  final log = <String>[];
  final preferences = _Preferences();
  late final scheduler = _Scheduler(log);
  late final _Habits habits;
  late final ProviderContainer container;

  Future<void> resumeReconcile() => container
      .read(settingsUiActionsProvider)
      .refreshNotificationPermissionAndReminders();

  Future<void> restoreReconcile() async {
    await container.read(restoredReminderReconciliationProvider)();
  }

  Future<void> buildHabits() async {
    await container.read(habitsProvider.future);
  }

  void expectMigrated() {
    expect(habits.values.map((habit) => habit.reminderMinutes), [
      20 * 60,
      null,
      9 * 60,
    ]);
    final save = log.indexOf('save');
    expect(save, greaterThanOrEqualTo(0));
    expect(
      log.take(save),
      isNot(contains('os-cancel:$_legacy')),
      reason: 'The old reminder is cancelled only after the times are saved.',
    );
    expect(log.skip(save), contains('os-cancel:$_legacy'));
    expect(scheduler.pending, isNot(contains(_legacy)));
    expect(preferences.load(_done), 'true');
  }

  HabitEntity habit(
    String id, {
    int? reminderMinutes,
    HabitStatus status = HabitStatus.active,
  }) => HabitEntity(
    id: id,
    title: '$id rhythm',
    createdAt: DateTime(2026, 1, 1),
    status: status,
    reminderMinutes: reminderMinutes,
  );
}

class _Habits implements IHabitRepository {
  _Habits(this.log, this.values);
  final List<String> log;
  List<HabitEntity> values;
  @override
  Future<List<HabitEntity>> getHabits() async => values;
  @override
  Future<void> saveHabits(List<HabitEntity> habits) async {
    log.add('save');
    values = habits;
  }
}

class _Goals implements IGoalRepository {
  @override
  List<GoalEntity> getGoals() => const [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Preferences implements SharedPrefsStore {
  final values = <String, String>{};
  @override
  Future<void> init() async {}
  @override
  String? load(String key) => values[key];
  @override
  Future<void> save(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<void> clear() async {
    values.clear();
  }
}

/// Stands in for the OS: [pending] is what would fire.
class _Scheduler implements NotificationScheduler {
  _Scheduler(this.log);
  final List<String> log;
  final pending = <String>{};
  final _permission = ValueNotifier<bool?>(true);

  @override
  ValueListenable<bool?> get permissionStatusListenable => _permission;
  // Set up, as startup does outside mock mode.
  @override
  bool get isInitialized => true;
  @override
  Future<bool> init({bool requestPermissions = false}) async => true;
  @override
  Future<bool> requestPermissions() async => true;
  @override
  Future<List<String>> pendingIdsForAccount(String accountScope) async =>
      pending.toList();
  @override
  Future<bool> cancel(String id, {String? accountScope}) async {
    log.add('os-cancel:$id');
    pending.remove(id);
    return true;
  }

  @override
  Future<NotificationScheduleResult> schedule(
    NotificationEntity notification, {
    String? accountScope,
  }) async {
    pending.add(notification.id);
    return NotificationScheduleResult.scheduled;
  }

  @override
  Future<NotificationScheduleResult> scheduleDailyAt({
    required String id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    String? accountScope,
  }) async {
    pending.add(id);
    return NotificationScheduleResult.scheduled;
  }

  @override
  Future<NotificationScheduleResult> scheduleCadenceAt({
    required String id,
    required String title,
    required String body,
    required HabitCadence cadence,
    required DateTime firstAt,
    String? accountScope,
  }) async {
    final time =
        '${firstAt.hour.toString().padLeft(2, '0')}:'
        '${firstAt.minute.toString().padLeft(2, '0')}';
    log.add('cadence:$id@$time');
    pending.add(id);
    return NotificationScheduleResult.scheduled;
  }

  @override
  Future<bool> cancelAll() async {
    pending.clear();
    return true;
  }

  @override
  void clearTappedPayload() {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The notification list cancels through the same OS scheduler.
class _Notifications implements INotificationRepository {
  _Notifications(this.scheduler);
  final _Scheduler scheduler;
  @override
  Future<void> cancelNotification(String id) => scheduler.cancel(id);
  @override
  Future<List<NotificationEntity>> getNotifications() async => [];
  @override
  Future<void> scheduleNotification(NotificationEntity notification) async {}
  @override
  Future<void> markRead(String id) async {}
  @override
  Future<void> delete(String id) async {}
}
