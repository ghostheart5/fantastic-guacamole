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
import 'package:fantastic_guacamole/state/providers/goals_provider.dart';
import 'package:fantastic_guacamole/state/providers/habit_occurrence_provider.dart';
import 'package:fantastic_guacamole/state/providers/habits_provider.dart';
import 'package:fantastic_guacamole/state/providers/repository_providers.dart';
import 'package:fantastic_guacamole/state/providers/service_providers.dart';
import 'package:fantastic_guacamole/state/services/notifications_service.dart';
import 'package:fantastic_guacamole/state/services/reminder_orchestrator_service.dart';
import 'package:fantastic_guacamole/system/notifications/notification_scheduler.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// When Android has stopped the app, every cold start rebuilds the goals and
/// rhythms lists. A rebuild with nothing changed must leave the OS reminders
/// alone: a cancel also removes a reminder already shown in the tray, and a
/// new registration moves a waiting alarm.
void main() {
  test('a goals rebuild with nothing changed cancels and registers nothing, '
      'for goals and daily planning', () async {
    final fixture = _Fixture()
      ..goals.values = [_goal('trip', DateTime(2026, 11, 30))];
    fixture.container.read(goalsProvider);
    await pumpEventQueue();
    expect(fixture.scheduler.pending, contains('goal_reminder_trip_due'));
    expect(fixture.scheduler.pending, contains('daily_planning_reminder'));

    fixture.scheduler.log.clear();
    fixture.container.invalidate(goalsProvider);
    fixture.container.read(goalsProvider);
    await pumpEventQueue();
    expect(fixture.scheduler.log, isEmpty);
  });

  test(
    'a goals rebuild keeps a goal reminder that was already shown',
    () async {
      // The "three days before" reminder is at 9 AM today.
      final fixture = _Fixture()
        ..goals.values = [_goal('trip', DateTime(2026, 11, 26))];
      fixture.container.read(goalsProvider);
      await pumpEventQueue();
      expect(fixture.scheduler.pending, contains('goal_reminder_trip_3d'));

      // It went off and sits in the tray; Android dropped it from pending.
      fixture.now = DateTime(2026, 11, 23, 9, 30);
      fixture.scheduler.pending.remove('goal_reminder_trip_3d');
      fixture.scheduler.log.clear();
      fixture.container.invalidate(goalsProvider);
      fixture.container.read(goalsProvider);
      await pumpEventQueue();
      expect(
        fixture.scheduler.log,
        isNot(contains('cancel:goal_reminder_trip_3d')),
      );
      expect(fixture.scheduler.log, isEmpty);
    },
  );

  test('a rhythms rebuild with nothing changed cancels and registers '
      'nothing', () async {
    final fixture = _Fixture()
      ..habits.values = [
        HabitEntity(
          id: 'walk',
          title: 'Walk',
          createdAt: DateTime(2026, 1, 1),
          reminderMinutes: 7 * 60,
        ),
      ];
    await fixture.container.read(habitsProvider.future);
    expect(fixture.scheduler.pending, contains('habit_reminder_walk'));
    expect(
      fixture.service.lastHabitReminderResult.value,
      NotificationScheduleResult.scheduled,
    );

    fixture.scheduler.log.clear();
    fixture.container.invalidate(habitsProvider);
    await fixture.container.read(habitsProvider.future);
    expect(fixture.scheduler.log, isEmpty);
    expect(
      fixture.service.lastHabitReminderResult.value,
      NotificationScheduleResult.scheduled,
    );
  });

  test('a rhythms build with a new time replaces only that rhythm', () async {
    HabitEntity habit(String id, int minutes) => HabitEntity(
      id: id,
      title: id,
      createdAt: DateTime(2026, 1, 1),
      reminderMinutes: minutes,
    );
    final fixture = _Fixture()
      ..habits.values = [habit('walk', 7 * 60), habit('read', 21 * 60)];
    await fixture.container.read(habitsProvider.future);

    fixture.scheduler.log.clear();
    fixture.habits.values = [habit('walk', 8 * 60), habit('read', 21 * 60)];
    fixture.container.invalidate(habitsProvider);
    await fixture.container.read(habitsProvider.future);
    expect(fixture.scheduler.log, ['cadence:habit_reminder_walk@08:00']);
  });

  test('without permission a rhythms build is not an error', () async {
    final fixture = _Fixture()
      ..habits.values = [
        HabitEntity(
          id: 'walk',
          title: 'Walk',
          createdAt: DateTime(2026, 1, 1),
          reminderMinutes: 7 * 60,
        ),
      ];
    fixture.scheduler.allowed = false;
    await fixture.container.read(habitsProvider.future);
    expect(
      fixture.service.lastHabitReminderResult.value,
      NotificationScheduleResult.permissionDenied,
    );
  });
}

GoalEntity _goal(String id, DateTime target) => GoalEntity(
  id: id,
  title: id,
  createdAt: DateTime(2026, 11, 1),
  targetDate: target,
);

class _Fixture {
  _Fixture() {
    preferences.values['legacy_habit_reminder_migrated'] = 'true';
    container = ProviderContainer(
      overrides: [
        accountStorageScopeProvider.overrideWithValue(
          AccountStorageScope.authenticated('rebuild-user'),
        ),
        domainGoalRepositoryProvider.overrideWithValue(goals),
        domainHabitRepositoryProvider.overrideWithValue(habits),
        habitOccurrenceCoordinatorProvider.overrideWithValue(null),
        notificationSchedulerProvider.overrideWithValue(scheduler),
        reminderOrchestratorServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(container.dispose);
  }

  DateTime now = DateTime(2026, 11, 23, 8);
  final preferences = _Preferences();
  final scheduler = _Scheduler();
  final goals = _Goals();
  final habits = _Habits();
  late final service = ReminderOrchestratorService(
    preferences: preferences,
    notifications: NotificationsService(_Notifications(scheduler)),
    scheduler: scheduler,
    accountScope: 'qa',
    now: () => now,
    timeZoneName: () => 'UTC',
    isSpanish: () => false,
    loadHabitOccurrences: () async => [],
  );
  late final ProviderContainer container;
}

class _Goals implements IGoalRepository {
  List<GoalEntity> values = [];
  @override
  List<GoalEntity> getGoals() => values;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Habits implements IHabitRepository {
  List<HabitEntity> values = [];
  @override
  Future<List<HabitEntity>> getHabits() async => values;
  @override
  Future<void> saveHabits(List<HabitEntity> habits) async => values = habits;
}

class _Preferences implements SharedPrefsStore {
  final values = <String, String>{};
  @override
  Future<void> init() async {}
  @override
  String? load(String key) => values[key];
  @override
  Future<void> save(String key, String value) async => values[key] = value;
  @override
  Future<void> delete(String key) async => values.remove(key);
  @override
  Future<void> clear() async => values.clear();
}

/// Stands in for the OS: [pending] is what would fire; [log] records every
/// registration and cancel.
class _Scheduler implements NotificationScheduler {
  final pending = <String>{};
  final log = <String>[];
  bool allowed = true;
  final _permission = ValueNotifier<bool?>(true);

  @override
  bool get isInitialized => true;
  @override
  ValueListenable<bool?> get permissionStatusListenable => _permission;
  @override
  Future<bool> init({bool requestPermissions = false}) async => allowed;
  @override
  Future<List<String>> pendingIdsForAccount(String accountScope) async =>
      allowed ? pending.toList() : const [];
  @override
  Future<bool> cancel(String id, {String? accountScope}) async {
    log.add('cancel:$id');
    pending.remove(id);
    return true;
  }

  NotificationScheduleResult _register(String entry, String id) {
    if (!allowed) return NotificationScheduleResult.permissionDenied;
    log.add(entry);
    pending.add(id);
    return NotificationScheduleResult.scheduled;
  }

  @override
  Future<NotificationScheduleResult> schedule(
    NotificationEntity notification, {
    String? accountScope,
  }) async => _register('once:${notification.id}', notification.id);

  @override
  Future<NotificationScheduleResult> scheduleDailyAt({
    required String id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    String? accountScope,
  }) async => _register('daily:$id', id);

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
    return _register('cadence:$id@$time', id);
  }

  @override
  void clearTappedPayload() {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The notification list registers and cancels through the same scheduler.
class _Notifications implements INotificationRepository {
  _Notifications(this.scheduler);
  final _Scheduler scheduler;
  @override
  Future<void> scheduleNotification(NotificationEntity notification) =>
      scheduler.schedule(notification, accountScope: 'qa');
  @override
  Future<void> cancelNotification(String id) => scheduler.cancel(id);
  @override
  Future<List<NotificationEntity>> getNotifications() async => [];
  @override
  Future<void> markRead(String id) async {}
  @override
  Future<void> delete(String id) async {}
}
