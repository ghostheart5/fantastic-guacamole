import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/entities/notification_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_notification_repository.dart';
import 'package:fantastic_guacamole/domain/ports/notification_scheduler_port.dart';
import 'package:fantastic_guacamole/state/services/notifications_service.dart';
import 'package:fantastic_guacamole/state/services/reflection_reminder_service.dart';
import 'package:fantastic_guacamole/state/services/reminder_orchestrator_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

const String _scope = 'reminder-controls-scope';

/// The main reminder switch, task lead time and quiet hours, read from the
/// stored account preferences the Settings controls write.
void main() {
  late tz.Location previousZone;

  setUpAll(tzdata.initializeTimeZones);

  setUp(() {
    previousZone = tz.local;
    tz.setLocalLocation(tz.getLocation('America/New_York'));
  });

  tearDown(() => tz.setLocalLocation(previousZone));

  tz.TZDateTime local(int y, int m, int d, [int h = 0, int min = 0]) =>
      tz.TZDateTime(tz.local, y, m, d, h, min);

  DateTime utc(DateTime at) => DateTime.fromMillisecondsSinceEpoch(
    at.millisecondsSinceEpoch,
    isUtc: true,
  );

  test('the main switch off cancels every OS reminder and on brings the '
      'same ones back', () async {
    final fixture = _Fixture();
    fixture.tasks = [_task('a', dueDate: local(2026, 11, 3, 17))];
    final goals = [fixture.goal('trip')];
    final habits = [fixture.habit('walk', minutes: 18 * 60)];
    expect(await fixture.reconcile(goals, habits), isTrue);
    final Set<String> everything = Set<String>.of(fixture.scheduler.pending);
    expect(everything, <String>{
      'daily_planning_reminder',
      'habit_reminder_walk',
      'goal_reminder_trip_3d',
      'goal_reminder_trip',
      'goal_reminder_trip_due',
      'task_reminder_due_a',
    });

    fixture.preferences.values['reminders_enabled'] = 'false';
    fixture.scheduler.clearLog();
    expect(await fixture.reconcile(goals, habits), isTrue);
    expect(fixture.scheduler.pending, isEmpty);
    expect(fixture.scheduler.cancelled, containsAll(everything));
    expect(fixture.scheduler.registered, isEmpty);
    // Each feature keeps its own choice.
    final prefs = fixture.service.loadPrefs();
    expect(prefs.goalRemindersEnabled, isTrue);
    expect(prefs.taskRemindersEnabled, isTrue);

    // Later updates while it is off register nothing either.
    await fixture.service.syncHabitReminders(habits);
    await fixture.service.syncGoalReminders(goals);
    await fixture.service.ensureDailyPlanningReminder();
    expect(fixture.scheduler.pending, isEmpty);

    fixture.preferences.values['reminders_enabled'] = 'true';
    fixture.scheduler.clearLog();
    expect(await fixture.reconcile(goals, habits), isTrue);
    expect(fixture.scheduler.pending, everything);
  });

  test(
    'the main switch off also stops the daily reflection reminder',
    () async {
      final fixture = _Fixture();
      final reflection = ReflectionReminderService(
        preferences: fixture.preferences,
        scheduler: fixture.scheduler,
        permissionListenable: ValueNotifier<bool?>(true),
        accountScope: _scope,
      );
      expect(
        await reflection.setEnabled(
          enabled: true,
          time: const TimeOfDay(hour: 20, minute: 0),
        ),
        isTrue,
      );
      expect(fixture.scheduler.pending, contains('reflection_reminder'));

      fixture.preferences.values['reminders_enabled'] = 'false';
      expect(
        await reflection.reconcileAfterRestore(
          permissionGranted: true,
          shouldContinue: () => true,
        ),
        isTrue,
      );
      expect(fixture.scheduler.pending, isNot(contains('reflection_reminder')));
      // The choice itself is kept.
      expect(reflection.loadPrefs().enabled, isTrue);

      fixture.preferences.values['reminders_enabled'] = 'true';
      expect(
        await reflection.reconcileAfterRestore(
          permissionGranted: true,
          shouldContinue: () => true,
        ),
        isTrue,
      );
      expect(fixture.scheduler.pending, contains('reflection_reminder'));
    },
  );

  test('a chosen lead time moves the task reminder earlier', () async {
    final fixture = _Fixture();
    fixture.tasks = [_task('a', dueDate: local(2026, 11, 3, 17))];
    expect(await fixture.reconcile(const [], const []), isTrue);
    expect(
      fixture.scheduler.times['task_reminder_due_a'],
      utc(local(2026, 11, 3, 17)),
    );

    fixture.preferences.values['task_reminder_lead_minutes'] = '15';
    fixture.scheduler.clearLog();
    expect(await fixture.reconcile(const [], const []), isTrue);
    expect(fixture.scheduler.registered, ['task_reminder_due_a']);
    expect(
      fixture.scheduler.times['task_reminder_due_a'],
      utc(local(2026, 11, 3, 16, 45)),
    );
    expect(fixture.scheduler.titles['task_reminder_due_a'], 'Task due soon');
  });

  test('a 02:00 task reminder with quiet hours 22:00 to 07:00 lands at '
      '07:00, and one at 23:30 at 07:00 the next day', () async {
    final fixture = _Fixture();
    fixture.tasks = [
      _task('night', dueDate: local(2026, 11, 3, 2)),
      _task('late', dueDate: local(2026, 11, 3, 23, 30)),
      _task('day', dueDate: local(2026, 11, 3, 12)),
    ];
    fixture.preferences.values
      ..['quiet_hours_enabled'] = 'true'
      ..['quiet_hours_start'] = '22:0'
      ..['quiet_hours_end'] = '7:0';
    expect(await fixture.reconcile(const [], const []), isTrue);
    expect(
      fixture.scheduler.times['task_reminder_due_night'],
      utc(local(2026, 11, 3, 7)),
    );
    expect(
      fixture.scheduler.times['task_reminder_due_late'],
      utc(local(2026, 11, 4, 7)),
    );
    expect(
      fixture.scheduler.times['task_reminder_due_day'],
      utc(local(2026, 11, 3, 12)),
    );

    // Turned off, the reminders go back to their own times.
    fixture.preferences.values['quiet_hours_enabled'] = 'false';
    expect(await fixture.reconcile(const [], const []), isTrue);
    expect(
      fixture.scheduler.times['task_reminder_due_night'],
      utc(local(2026, 11, 3, 2)),
    );
  });

  test(
    'quiet hours move goal reminders but never a time the person chose',
    () async {
      final fixture = _Fixture();
      // The goal's 9 AM reminder three days before, wherever this machine is.
      final DateTime goalMorning = DateTime(2026, 11, 3, 9);
      final tz.TZDateTime wall = tz.TZDateTime.from(goalMorning, tz.local);
      final int start = wall.hour * 60 + wall.minute;
      String time(int minutes) => '${minutes ~/ 60}:${minutes % 60}';
      // A one-hour quiet stretch starting exactly then. The rhythm's time is
      // half an hour later.
      final int habitMinutes = (start + 30) % (24 * 60);
      fixture.preferences.values
        ..['quiet_hours_enabled'] = 'true'
        ..['quiet_hours_start'] = time(start)
        ..['quiet_hours_end'] = time((start + 60) % (24 * 60));
      expect(
        await fixture.reconcile(
          [fixture.goal('trip')],
          [fixture.habit('walk', minutes: habitMinutes)],
        ),
        isTrue,
      );
      expect(
        fixture.scheduler.times['goal_reminder_trip_3d']!.isAtSameMomentAs(
          goalMorning.add(const Duration(hours: 1)),
        ),
        isTrue,
      );
      // The rhythm keeps the time that was picked for it.
      expect(fixture.scheduler.cadenceTimes['habit_reminder_walk'], (
        habitMinutes ~/ 60,
        habitMinutes % 60,
      ));
    },
  );

  test('without any of the new choices stored, nothing changes', () async {
    final fixture = _Fixture();
    final prefs = fixture.service.loadPrefs();
    expect(prefs.taskReminderLeadMinutes, 0);
    expect(prefs.taskOverdueNudgesEnabled, isFalse);
    fixture.tasks = [_task('night', dueDate: local(2026, 11, 3, 2))];
    expect(await fixture.reconcile(const [], const []), isTrue);
    expect(
      fixture.scheduler.times['task_reminder_due_night'],
      utc(local(2026, 11, 3, 2)),
    );
    expect(fixture.scheduler.pending, contains('daily_planning_reminder'));
  });
}

TaskEntity _task(String id, {DateTime? dueDate}) => TaskEntity(
  id: id,
  title: 'Task $id',
  createdAt: DateTime.utc(2026, 10, 1),
  dueDate: dueDate,
);

class _Fixture {
  _Fixture() {
    preferences.values['legacy_habit_reminder_migrated'] = 'true';
  }

  DateTime now = DateTime.utc(2026, 11, 1, 15);
  List<TaskEntity> tasks = <TaskEntity>[];
  final preferences = _Preferences();
  final scheduler = _Scheduler();
  late final service = ReminderOrchestratorService(
    preferences: preferences,
    notifications: NotificationsService(_Repository()),
    scheduler: scheduler,
    accountScope: _scope,
    loadHabitOccurrences: () async => [],
    loadGoalTasks: () async => [],
    loadTasks: () async => tasks,
    now: () => now,
    timeZoneName: () => 'America/New_York',
    isSpanish: () => false,
  );

  Future<bool> reconcile(List<GoalEntity> goals, List<HabitEntity> habits) =>
      service.reconcileAfterRestore(
        goals: goals,
        habits: habits,
        permissionGranted: true,
        shouldContinue: () => true,
      );

  GoalEntity goal(String id) => GoalEntity(
    id: id,
    title: 'Goal $id',
    createdAt: DateTime(2026, 10, 1),
    targetDate: DateTime(2026, 11, 6),
  );

  HabitEntity habit(String id, {required int minutes}) => HabitEntity(
    id: id,
    title: 'Rhythm $id',
    createdAt: DateTime(2026, 10, 1),
    reminderMinutes: minutes,
  );
}

class _Scheduler implements NotificationSchedulerPort {
  final Set<String> pending = <String>{};
  final List<String> registered = <String>[];
  final List<String> cancelled = <String>[];
  final Map<String, DateTime> times = <String, DateTime>{};
  final Map<String, String> titles = <String, String>{};
  final Map<String, (int, int)> cadenceTimes = <String, (int, int)>{};

  void clearLog() {
    registered.clear();
    cancelled.clear();
  }

  NotificationScheduleResult _register(String id, String? accountScope) {
    expect(accountScope, _scope);
    registered.add(id);
    pending.add(id);
    return NotificationScheduleResult.scheduled;
  }

  @override
  Future<NotificationScheduleResult> schedule(
    NotificationEntity notification, {
    String? accountScope,
  }) async {
    times[notification.id] = notification.scheduledAt.toUtc();
    titles[notification.id] = notification.title;
    return _register(notification.id, accountScope);
  }

  @override
  Future<NotificationScheduleResult> scheduleDailyAt({
    required String id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    String? accountScope,
  }) async => _register(id, accountScope);

  @override
  Future<NotificationScheduleResult> scheduleCadenceAt({
    required String id,
    required String title,
    required String body,
    required HabitCadence cadence,
    required DateTime firstAt,
    String? accountScope,
  }) async {
    cadenceTimes[id] = (firstAt.hour, firstAt.minute);
    return _register(id, accountScope);
  }

  @override
  Future<bool> cancel(String id, {String? accountScope}) async {
    expect(accountScope, _scope);
    cancelled.add(id);
    pending.remove(id);
    return true;
  }

  @override
  Future<List<String>> pendingIdsForAccount(String accountScope) async {
    expect(accountScope, _scope);
    return pending.toList();
  }

  @override
  Future<bool> requestPermissions() async =>
      throw StateError('Must not prompt for permission');

  @override
  Future<bool> cancelAll() async =>
      throw StateError('Global cancellation forbidden');

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
  @override
  Future<void> cancelNotification(String id) async {}
  @override
  Future<void> delete(String id) async {}
  @override
  Future<List<NotificationEntity>> getNotifications() async => const [];
  @override
  Future<void> markRead(String id) async {}
  @override
  Future<void> scheduleNotification(NotificationEntity notification) async {}
}
