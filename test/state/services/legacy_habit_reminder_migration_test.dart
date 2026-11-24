import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/entities/notification_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_notification_repository.dart';
import 'package:fantastic_guacamole/domain/ports/notification_scheduler_port.dart';
import 'package:fantastic_guacamole/state/services/notifications_service.dart';
import 'package:fantastic_guacamole/state/services/reminder_orchestrator_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('gives active timeless habits 8 PM and cancels the old id', () async {
    final fixture = _Fixture(legacyPending: true);
    final habits = [
      fixture.habit('a'),
      fixture.habit('b', reminderMinutes: 9 * 60),
      fixture.habit('c', status: HabitStatus.paused),
    ];
    final result = await fixture.migrate(habits);
    expect(result.map((h) => h.reminderMinutes), [20 * 60, 9 * 60, null]);
    expect(fixture.saved, hasLength(1));
    expect(fixture.saved.single.map((h) => h.reminderMinutes), [
      20 * 60,
      9 * 60,
      null,
    ]);
    expect(fixture.scheduler.cancelled, ['habit_reminder_daily']);
  });

  test('is safe to run twice', () async {
    final fixture = _Fixture(legacyPending: true);
    final first = await fixture.migrate([fixture.habit('a')]);
    // A new, timeless habit added afterwards must stay untouched.
    final second = await fixture.migrate([...first, fixture.habit('new')]);
    expect(second.map((h) => h.reminderMinutes), [20 * 60, null]);
    expect(fixture.saved, hasLength(1));
    expect(fixture.scheduler.cancelled, ['habit_reminder_daily']);
  });

  test('does nothing for accounts that never had the old reminder', () async {
    final fixture = _Fixture(legacyPending: false);
    final habits = [fixture.habit('a')];
    final result = await fixture.migrate(habits);
    expect(result.single.reminderMinutes, isNull);
    expect(fixture.saved, isEmpty);
    expect(fixture.scheduler.cancelled, isEmpty);
    // It is recorded as done, so a later stray registration is not adopted.
    fixture.scheduler.pending = ['habit_reminder_daily'];
    final again = await fixture.migrate(habits);
    expect(again.single.reminderMinutes, isNull);
  });

  test('a tracked old id also counts as having the old reminder', () async {
    final fixture = _Fixture(legacyPending: false);
    await fixture.preferences.save(
      'scheduled_habit_reminder_ids',
      '["habit_reminder_daily"]',
    );
    final result = await fixture.migrate([fixture.habit('a')]);
    expect(result.single.reminderMinutes, 20 * 60);
  });

  test('does nothing while habit reminders are turned off', () async {
    final fixture = _Fixture(legacyPending: true);
    await fixture.preferences.save('habit_reminders_enabled', 'false');
    final result = await fixture.migrate([fixture.habit('a')]);
    expect(result.single.reminderMinutes, isNull);
    expect(fixture.saved, isEmpty);
    expect(fixture.scheduler.cancelled, isEmpty);
  });

  test('a failed save leaves the old reminder for the next run', () async {
    final fixture = _Fixture(legacyPending: true)..saveFails = true;
    final habits = [fixture.habit('a')];
    await expectLater(fixture.migrate(habits), throwsStateError);
    expect(fixture.scheduler.cancelled, isEmpty);
    fixture.saveFails = false;
    final result = await fixture.migrate(habits);
    expect(result.single.reminderMinutes, 20 * 60);
    expect(fixture.scheduler.cancelled, ['habit_reminder_daily']);
  });

  test('stops without saving when the account changes', () async {
    final fixture = _Fixture(legacyPending: true);
    final result = await fixture.service.migrateLegacyHabitReminder(
      [fixture.habit('a')],
      save: fixture.save,
      shouldContinue: () => false,
    );
    expect(result.single.reminderMinutes, isNull);
    expect(fixture.saved, isEmpty);
    expect(fixture.scheduler.cancelled, isEmpty);
  });
}

class _Fixture {
  _Fixture({required bool legacyPending}) {
    scheduler.pending = legacyPending ? ['habit_reminder_daily'] : [];
  }
  final preferences = _Preferences();
  final scheduler = _Scheduler();
  final saved = <List<HabitEntity>>[];
  bool saveFails = false;
  late final service = ReminderOrchestratorService(
    preferences: preferences,
    notifications: NotificationsService(_Repository()),
    scheduler: scheduler,
    accountScope: 'qa',
    now: () => DateTime(2026, 11, 23, 10),
  );

  Future<void> save(List<HabitEntity> habits) async {
    if (saveFails) throw StateError('disk full');
    saved.add(habits);
  }

  Future<List<HabitEntity>> migrate(List<HabitEntity> habits) =>
      service.migrateLegacyHabitReminder(habits, save: save);

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

class _Scheduler implements NotificationSchedulerPort {
  final cancelled = <String>[];
  List<String> pending = [];
  @override
  Future<bool> cancel(String id, {String? accountScope}) async {
    cancelled.add(id);
    return true;
  }

  @override
  Future<List<String>> pendingIdsForAccount(String accountScope) async =>
      pending;
  @override
  Future<bool> scheduleCadenceAt({
    required String id,
    required String title,
    required String body,
    required HabitCadence cadence,
    required DateTime firstAt,
    String? accountScope,
  }) async => true;
  @override
  Future<bool> scheduleDailyAt({
    required String id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    String? accountScope,
  }) async => true;
  @override
  Future<bool> requestPermissions() async => true;
  @override
  Future<bool> schedule(
    NotificationEntity notification, {
    String? accountScope,
  }) async => true;
  @override
  Future<bool> cancelAll() async => true;
  @override
  void clearTappedPayload() {}
}

class _Repository implements INotificationRepository {
  @override
  Future<void> cancelNotification(String id) async {}
  @override
  Future<List<NotificationEntity>> getNotifications() async => [];
  @override
  Future<void> scheduleNotification(NotificationEntity notification) async {}
  @override
  Future<void> markRead(String id) async {}
  @override
  Future<void> delete(String id) async {}
}
