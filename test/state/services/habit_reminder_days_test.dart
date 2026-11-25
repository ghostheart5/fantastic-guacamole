import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_occurrence_entity.dart';
import 'package:fantastic_guacamole/domain/entities/notification_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_notification_repository.dart';
import 'package:fantastic_guacamole/domain/planning/rhythm_planning_context.dart';
import 'package:fantastic_guacamole/domain/ports/notification_scheduler_port.dart';
import 'package:fantastic_guacamole/state/services/notifications_service.dart';
import 'package:fantastic_guacamole/state/services/reminder_orchestrator_service.dart';
import 'package:flutter_test/flutter_test.dart';

const String _scope = 'days-scope';

void main() {
  // Monday 12 October 2026, before the 6 PM reminder time.
  final DateTime monday = DateTime(2026, 10, 12, 10);

  group('weekly habit with chosen weekdays', () {
    test('registers one repeating alarm per weekday, each on its next '
        'occurrence', () async {
      final fixture = _Fixture(monday);
      await fixture.service.syncHabitReminders([
        fixture.weekly(weekdays: [3, 5]),
      ]);
      expect(fixture.scheduler.cadences, {
        'habit_reminder_walk_wd3': (
          HabitCadence.weekly,
          DateTime(2026, 10, 14, 18),
        ),
        'habit_reminder_walk_wd5': (
          HabitCadence.weekly,
          DateTime(2026, 10, 16, 18),
        ),
      });
      expect(fixture.scheduler.pending, isNot(contains('habit_reminder_walk')));
    });

    test('a weekday already past this week starts next week', () async {
      // Thursday: Wednesday has passed, Friday is still ahead.
      final fixture = _Fixture(DateTime(2026, 10, 15, 10));
      await fixture.service.syncHabitReminders([
        fixture.weekly(weekdays: [3, 5]),
      ]);
      expect(
        fixture.scheduler.cadences['habit_reminder_walk_wd3']!.$2,
        DateTime(2026, 10, 21, 18),
      );
      expect(
        fixture.scheduler.cadences['habit_reminder_walk_wd5']!.$2,
        DateTime(2026, 10, 16, 18),
      );
    });

    test('a week already recorded waits for next week on every day', () async {
      final fixture = _Fixture(monday);
      final habit = fixture.weekly(weekdays: [3, 5]);
      fixture.outcomes.add(fixture.outcome(habit));
      await fixture.service.syncHabitReminders([habit]);
      expect(
        fixture.scheduler.cadences['habit_reminder_walk_wd3']!.$2,
        DateTime(2026, 10, 21, 18),
      );
      expect(
        fixture.scheduler.cadences['habit_reminder_walk_wd5']!.$2,
        DateTime(2026, 10, 23, 18),
      );
    });

    test('a weekday that is dropped is cancelled; the others stay', () async {
      final fixture = _Fixture(monday);
      await fixture.reconcile([
        fixture.weekly(weekdays: [3, 5]),
      ]);
      fixture.scheduler.clearLog();
      expect(
        await fixture.reconcile([
          fixture.weekly(weekdays: [5]),
        ]),
        isTrue,
      );
      expect(fixture.scheduler.cancelled, ['habit_reminder_walk_wd3']);
      expect(fixture.scheduler.registered, isEmpty);

      // The same through a habit save.
      await fixture.service.syncHabitReminders([
        fixture.weekly(weekdays: [2]),
      ]);
      expect(fixture.scheduler.pending, {
        'daily_planning_reminder',
        'habit_reminder_walk_wd2',
      });
    });

    test('choosing days replaces the Monday reminder, and back', () async {
      final fixture = _Fixture(monday);
      await fixture.reconcile([fixture.weekly()]);
      expect(fixture.scheduler.pending, contains('habit_reminder_walk'));
      fixture.scheduler.clearLog();
      await fixture.reconcile([
        fixture.weekly(weekdays: [4]),
      ]);
      expect(fixture.scheduler.registered, ['habit_reminder_walk_wd4']);
      expect(fixture.scheduler.cancelled, ['habit_reminder_walk']);
      fixture.scheduler.clearLog();
      await fixture.reconcile([fixture.weekly()]);
      expect(fixture.scheduler.registered, ['habit_reminder_walk']);
      expect(fixture.scheduler.cancelled, ['habit_reminder_walk_wd4']);
    });

    test('resume with nothing changed leaves every weekday alarm alone, even '
        'after one of them went off', () async {
      final fixture = _Fixture(monday);
      final habits = [
        fixture.weekly(weekdays: [1, 3]),
      ];
      await fixture.reconcile(habits);
      fixture.scheduler.clearLog();
      fixture.now = DateTime(2026, 10, 12, 19); // Monday's alarm went off.
      expect(await fixture.reconcile(habits), isTrue);
      expect(fixture.scheduler.registered, isEmpty);
      expect(fixture.scheduler.cancelled, isEmpty);
    });

    test('turning habit reminders off cancels every weekday alarm', () async {
      final fixture = _Fixture(monday);
      await fixture.service.syncHabitReminders([
        fixture.weekly(weekdays: [3, 5]),
      ]);
      await fixture.service.setHabitRemindersEnabled(false);
      expect(
        fixture.notifications.cancelled,
        containsAll(['habit_reminder_walk_wd3', 'habit_reminder_walk_wd5']),
      );
    });

    test('without permission the weekday alarms are cleared too', () async {
      final fixture = _Fixture(monday);
      final habits = [
        fixture.weekly(weekdays: [3, 5]),
      ];
      await fixture.reconcile(habits);
      fixture.scheduler.clearLog();
      expect(await fixture.reconcile(habits, permission: false), isFalse);
      expect(
        fixture.scheduler.cancelled,
        containsAll(['habit_reminder_walk_wd3', 'habit_reminder_walk_wd5']),
      );
      expect(fixture.scheduler.pending, isEmpty);
    });
  });

  group('monthly habit with a chosen day', () {
    test('fires on that day of this month while it is ahead', () async {
      final fixture = _Fixture(DateTime(2026, 11, 1, 10));
      await fixture.service.syncHabitReminders([fixture.monthly(day: 15)]);
      expect(fixture.scheduler.cadences, {
        'habit_reminder_walk': (
          HabitCadence.monthly,
          DateTime(2026, 11, 15, 18),
        ),
      });
    });

    test('once this month\'s day has passed it waits for next month, even '
        'when the month is not recorded yet', () async {
      final fixture = _Fixture(DateTime(2026, 11, 20, 10));
      await fixture.service.syncHabitReminders([fixture.monthly(day: 15)]);
      expect(
        fixture.scheduler.cadences['habit_reminder_walk']!.$2,
        DateTime(2026, 12, 15, 18),
      );
    });

    test('the last day lands on the 28th or 29th in February', () async {
      for (final (DateTime now, DateTime expected) in <(DateTime, DateTime)>[
        (DateTime(2027, 2, 10, 10), DateTime(2027, 2, 28, 18)),
        (DateTime(2028, 2, 10, 10), DateTime(2028, 2, 29, 18)),
        (DateTime(2027, 2, 28, 19), DateTime(2027, 3, 31, 18)),
        (DateTime(2026, 11, 2, 10), DateTime(2026, 11, 30, 18)),
      ]) {
        final fixture = _Fixture(now);
        await fixture.service.syncHabitReminders([
          fixture.monthly(day: HabitEntity.lastDayOfMonth),
        ]);
        expect(fixture.scheduler.cadences['habit_reminder_walk'], (
          HabitCadence.monthly,
          expected,
        ), reason: '$now');
      }
    });

    test('a changed day replaces the reminder on the next resume', () async {
      final fixture = _Fixture(DateTime(2026, 11, 2, 10));
      await fixture.reconcile([fixture.monthly()]);
      expect(
        fixture.scheduler.cadences['habit_reminder_walk']!.$2,
        DateTime(2026, 12, 1, 18),
      );
      fixture.scheduler.clearLog();
      expect(await fixture.reconcile([fixture.monthly(day: 15)]), isTrue);
      expect(fixture.scheduler.registered, ['habit_reminder_walk']);
      expect(
        fixture.scheduler.cadences['habit_reminder_walk']!.$2,
        DateTime(2026, 11, 15, 18),
      );
    });

    test(
      'the last day is set up again when the next month is longer',
      () async {
        final fixture = _Fixture(DateTime(2026, 11, 2, 10));
        final habits = [fixture.monthly(day: HabitEntity.lastDayOfMonth)];
        await fixture.reconcile(habits);
        fixture.scheduler.clearLog();
        // Same month: nothing changes.
        fixture.now = DateTime(2026, 11, 20, 10);
        await fixture.reconcile(habits);
        expect(fixture.scheduler.registered, isEmpty);
        // After November's last day the next one is 31 December.
        fixture.now = DateTime(2026, 12, 1, 10);
        await fixture.reconcile(habits);
        expect(fixture.scheduler.registered, ['habit_reminder_walk']);
        expect(
          fixture.scheduler.cadences['habit_reminder_walk']!.$2,
          DateTime(2026, 12, 31, 18),
        );
      },
    );
  });

  group('habits without chosen days', () {
    test('keep Monday and the 1st under their existing ids', () async {
      final fixture = _Fixture(DateTime(2026, 10, 13, 10)); // Tuesday
      // Shaped like a habit the 8 PM migration gave a time to.
      final weekly = HabitEntity.fromJson(<String, dynamic>{
        'id': 'old-weekly',
        'title': 'Old weekly',
        'createdAt': '2026-01-01T00:00:00.000',
        'cadence': 'weekly',
        'status': 'active',
        'reminderMinutes': 20 * 60,
      });
      final monthly = HabitEntity.fromJson(<String, dynamic>{
        'id': 'old-monthly',
        'title': 'Old monthly',
        'createdAt': '2026-01-01T00:00:00.000',
        'cadence': 'monthly',
        'status': 'active',
        'reminderMinutes': 20 * 60,
      });
      await fixture.service.syncHabitReminders([weekly, monthly]);
      expect(fixture.scheduler.cadences, {
        'habit_reminder_old-weekly': (
          HabitCadence.weekly,
          DateTime(2026, 10, 19, 20),
        ),
        'habit_reminder_old-monthly': (
          HabitCadence.monthly,
          DateTime(2026, 11, 1, 20),
        ),
      });
    });

    test('choosing only Monday or the 1st keeps the same alarm', () async {
      final fixture = _Fixture(DateTime(2026, 10, 13, 10)); // Tuesday
      await fixture.reconcile([fixture.weekly()]);
      fixture.scheduler.clearLog();
      expect(
        await fixture.reconcile([
          fixture.weekly(weekdays: [1]),
        ]),
        isTrue,
      );
      expect(fixture.scheduler.registered, isEmpty);
      expect(fixture.scheduler.cancelled, isEmpty);

      await fixture.reconcile([fixture.monthly()]);
      fixture.scheduler.clearLog();
      expect(await fixture.reconcile([fixture.monthly(day: 1)]), isTrue);
      expect(fixture.scheduler.registered, isEmpty);
      expect(fixture.scheduler.cancelled, isEmpty);
    });

    test('a daily habit ignores days left over from another cadence', () async {
      final fixture = _Fixture(monday);
      final habit = fixture
          .weekly(weekdays: [3])
          .copyWith(cadence: HabitCadence.daily, reminderDayOfMonth: 9);
      await fixture.service.syncHabitReminders([habit]);
      expect(fixture.scheduler.cadences, {
        'habit_reminder_walk': (HabitCadence.daily, DateTime(2026, 10, 12, 18)),
      });
    });
  });
}

class _Fixture {
  _Fixture(this.now) {
    // Past the one-time move off the old shared 8 PM rhythm reminder.
    preferences.values['legacy_habit_reminder_migrated'] = 'true';
  }

  DateTime now;
  final preferences = _Preferences();
  final scheduler = _Scheduler();
  final notifications = _Repository();
  final outcomes = <HabitOccurrenceEntity>[];
  late final service = ReminderOrchestratorService(
    preferences: preferences,
    notifications: NotificationsService(notifications),
    scheduler: scheduler,
    accountScope: _scope,
    loadHabitOccurrences: () async => outcomes,
    loadGoalTasks: () async => [],
    now: () => now,
    timeZoneName: () => 'America/Chicago',
  );

  Future<bool> reconcile(List<HabitEntity> habits, {bool permission = true}) =>
      service.reconcileAfterRestore(
        goals: const [],
        habits: habits,
        permissionGranted: permission,
        shouldContinue: () => true,
      );

  HabitEntity weekly({List<int>? weekdays}) => HabitEntity(
    id: 'walk',
    title: 'Evening walk',
    createdAt: DateTime(2026, 1, 1),
    cadence: HabitCadence.weekly,
    reminderMinutes: 18 * 60,
    reminderWeekdays: weekdays,
  );

  HabitEntity monthly({int? day}) => HabitEntity(
    id: 'walk',
    title: 'Evening walk',
    createdAt: DateTime(2026, 1, 1),
    cadence: HabitCadence.monthly,
    reminderMinutes: 18 * 60,
    reminderDayOfMonth: day,
  );

  HabitOccurrenceEntity outcome(HabitEntity habit) => HabitOccurrenceEntity(
    habitId: habit.id,
    occurrenceKey: RhythmPlanningContext.occurrenceKey(habit, now),
    operationId: 'op',
    outcome: HabitOccurrenceOutcome.completed,
    recordedAt: now,
  );
}

class _Scheduler implements NotificationSchedulerPort {
  final Set<String> pending = <String>{};
  final List<String> registered = <String>[];
  final List<String> cancelled = <String>[];
  final Map<String, (HabitCadence, DateTime)> cadences =
      <String, (HabitCadence, DateTime)>{};

  void clearLog() {
    registered.clear();
    cancelled.clear();
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
    expect(accountScope, _scope);
    registered.add(id);
    pending.add(id);
    cadences[id] = (cadence, firstAt);
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
    registered.add(id);
    pending.add(id);
    return NotificationScheduleResult.scheduled;
  }

  @override
  Future<NotificationScheduleResult> schedule(
    NotificationEntity notification, {
    String? accountScope,
  }) async {
    registered.add(notification.id);
    pending.add(notification.id);
    return NotificationScheduleResult.scheduled;
  }

  @override
  Future<bool> cancel(String id, {String? accountScope}) async {
    expect(accountScope, _scope);
    cancelled.add(id);
    pending.remove(id);
    cadences.remove(id);
    return true;
  }

  @override
  Future<List<String>> pendingIdsForAccount(String accountScope) async =>
      pending.toList();

  @override
  Future<bool> requestPermissions() async =>
      throw StateError('Must not ask for permission');

  @override
  Future<bool> cancelAll() async => throw StateError('Global cancel');

  @override
  void clearTappedPayload() {}
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

class _Repository implements INotificationRepository {
  final cancelled = <String>[];
  @override
  Future<void> cancelNotification(String id) async {
    cancelled.add(id);
  }

  @override
  Future<List<NotificationEntity>> getNotifications() async => [];
  @override
  Future<void> scheduleNotification(NotificationEntity notification) async {}
  @override
  Future<void> markRead(String id) async {}
  @override
  Future<void> delete(String id) async {}
}
