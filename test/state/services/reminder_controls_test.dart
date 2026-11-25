import 'package:fantastic_guacamole/core/data/account_data_registry.dart';
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

  test('a task reminder held by quiet hours survives a reconcile during '
      'quiet hours, and goes once the task is done', () async {
    final fixture = _Fixture()..now = utc(local(2026, 11, 2, 21));
    fixture.preferences.values
      ..['quiet_hours_enabled'] = 'true'
      ..['quiet_hours_start'] = '22:0'
      ..['quiet_hours_end'] = '7:0'
      ..['task_overdue_nudges_enabled'] = 'true';
    final night = _task('night', dueDate: local(2026, 11, 3, 2));
    fixture.tasks = [night];
    expect(await fixture.reconcile(const [], const []), isTrue);
    expect(
      fixture.scheduler.times['task_reminder_due_night'],
      utc(local(2026, 11, 3, 7)),
    );

    // 03:00, inside quiet hours: the app is opened or a task is saved.
    fixture.now = utc(local(2026, 11, 3, 3));
    fixture.scheduler.clearLog();
    expect(await fixture.reconcile(const [], const []), isTrue);
    await fixture.service.syncTaskReminders(
      permissionGranted: true,
      shouldContinue: () => true,
    );
    expect(fixture.scheduler.cancelled, isEmpty);
    expect(fixture.scheduler.registered, isEmpty);
    expect(fixture.scheduler.pending, contains('task_reminder_due_night'));
    expect(
      fixture.scheduler.times['task_reminder_due_night'],
      utc(local(2026, 11, 3, 7)),
    );

    // The overdue nudge (9 AM the next day) is held the same way when quiet
    // hours run past it.
    fixture.preferences.values['quiet_hours_end'] = '10:0';
    fixture.now = utc(local(2026, 11, 4, 9, 30));
    expect(await fixture.reconcile(const [], const []), isTrue);
    expect(
      fixture.scheduler.times['task_reminder_overdue_night'],
      utc(local(2026, 11, 4, 10)),
    );
    expect(fixture.scheduler.pending, contains('task_reminder_overdue_night'));

    // Finished while held back: the reminder goes at once.
    fixture.tasks = [night.copyWith(isCompleted: true)];
    fixture.scheduler.clearLog();
    await fixture.service.syncTaskReminders(
      permissionGranted: true,
      shouldContinue: () => true,
    );
    expect(
      fixture.scheduler.cancelled,
      contains('task_reminder_overdue_night'),
    );
    expect(
      fixture.scheduler.pending.where((id) => id.startsWith('task_')),
      isEmpty,
    );
  });

  test('a goal reminder held by quiet hours survives a reconcile while it '
      'waits', () async {
    final fixture = _Fixture();
    final DateTime goalMorning = DateTime(2026, 11, 3, 9);
    final tz.TZDateTime wall = tz.TZDateTime.from(goalMorning, tz.local);
    final int start = wall.hour * 60 + wall.minute;
    String time(int minutes) => '${minutes ~/ 60}:${minutes % 60}';
    fixture.preferences.values
      ..['quiet_hours_enabled'] = 'true'
      ..['quiet_hours_start'] = time(start)
      ..['quiet_hours_end'] = time((start + 60) % (24 * 60));
    final goals = [fixture.goal('trip')];
    expect(await fixture.reconcile(goals, const []), isTrue);
    final DateTime held = goalMorning.add(const Duration(hours: 1));
    expect(
      fixture.scheduler.times['goal_reminder_trip_3d']!.isAtSameMomentAs(held),
      isTrue,
    );

    // Half an hour after its own time, still before quiet hours end.
    fixture.now = goalMorning.add(const Duration(minutes: 30));
    fixture.scheduler.clearLog();
    expect(await fixture.reconcile(goals, const []), isTrue);
    await fixture.service.syncGoalReminders(goals);
    expect(
      fixture.scheduler.cancelled,
      isNot(contains('goal_reminder_trip_3d')),
    );
    expect(fixture.scheduler.pending, contains('goal_reminder_trip_3d'));
  });

  test('turning quiet hours on does not bring back a task reminder that '
      'was already delivered', () async {
    final fixture = _Fixture()..now = utc(local(2026, 11, 2, 23, 40));
    fixture.tasks = [
      _task('b', scheduledFor: local(2026, 11, 2, 23, 52)),
      _task('c', dueDate: local(2026, 11, 2, 23, 55)),
      _task('e', scheduledFor: local(2026, 11, 3, 1, 3)),
    ];
    expect(await fixture.reconcile(const [], const []), isTrue);

    // B and C went off on time and left the OS list; both stay open.
    fixture.now = utc(local(2026, 11, 3, 0, 16));
    fixture.scheduler.pending
      ..remove('task_reminder_start_b')
      ..remove('task_reminder_due_c');
    expect(await fixture.reconcile(const [], const []), isTrue);

    // 00:25: quiet hours on, 22:00 to 07:00. Only E, still ahead, is held.
    fixture.now = utc(local(2026, 11, 3, 0, 25));
    fixture.scheduler.clearLog();
    await fixture.service.setQuietHours(const QuietHours(enabled: true));
    expect(await fixture.reconcile(const [], const []), isTrue);
    expect(fixture.scheduler.registered, ['task_reminder_start_e']);
    expect(
      fixture.scheduler.times['task_reminder_start_e'],
      utc(local(2026, 11, 3, 7)),
    );

    // 00:26: quiet hours now end at 01:23. Still only E, held to then.
    fixture.now = utc(local(2026, 11, 3, 0, 26));
    fixture.scheduler.clearLog();
    await fixture.service.setQuietHours(
      const QuietHours(enabled: true, endMinutes: 60 + 23),
    );
    expect(await fixture.reconcile(const [], const []), isTrue);
    expect(fixture.scheduler.registered, ['task_reminder_start_e']);
    expect(
      fixture.scheduler.times['task_reminder_start_e'],
      utc(local(2026, 11, 3, 1, 23)),
    );
    expect(fixture.scheduler.pending.where((id) => id.startsWith('task_')), {
      'task_reminder_start_e',
    });
  });

  test('quiet hours set after an overdue nudge went off do not send it '
      'again', () async {
    final fixture = _Fixture()..now = utc(local(2026, 11, 3, 8));
    fixture.preferences.values['task_overdue_nudges_enabled'] = 'true';
    fixture.tasks = [_task('late', dueDate: local(2026, 11, 2, 17))];
    expect(await fixture.reconcile(const [], const []), isTrue);
    expect(
      fixture.scheduler.times['task_reminder_overdue_late'],
      utc(local(2026, 11, 3, 9)),
    );

    // 09:30: it went off at 09:00. Quiet hours 08:00 to 10:00 are set.
    fixture.now = utc(local(2026, 11, 3, 9, 30));
    fixture.scheduler.pending.remove('task_reminder_overdue_late');
    fixture.scheduler.clearLog();
    await fixture.service.setQuietHours(
      const QuietHours(enabled: true, startMinutes: 8 * 60, endMinutes: 600),
    );
    expect(await fixture.reconcile(const [], const []), isTrue);
    expect(fixture.scheduler.registered, isEmpty);
    expect(
      fixture.scheduler.pending,
      isNot(contains('task_reminder_overdue_late')),
    );
  });

  test('turning quiet hours on does not bring back a goal reminder that '
      'was already delivered', () async {
    final fixture = _Fixture();
    final DateTime goalMorning = DateTime(2026, 11, 3, 9);
    final tz.TZDateTime wall = tz.TZDateTime.from(goalMorning, tz.local);
    final int start = wall.hour * 60 + wall.minute;
    final goals = [fixture.goal('trip')];
    expect(await fixture.reconcile(goals, const []), isTrue);
    expect(fixture.scheduler.pending, contains('goal_reminder_trip_3d'));

    // Ten minutes after it went off, an hour of quiet hours starting at its
    // time is switched on.
    fixture.now = goalMorning.add(const Duration(minutes: 10));
    fixture.scheduler.pending.remove('goal_reminder_trip_3d');
    expect(await fixture.reconcile(goals, const []), isTrue);
    fixture.scheduler.clearLog();
    await fixture.service.setQuietHours(
      QuietHours(
        enabled: true,
        startMinutes: start,
        endMinutes: (start + 60) % (24 * 60),
      ),
    );
    expect(await fixture.reconcile(goals, const []), isTrue);
    await fixture.service.syncGoalReminders(goals);
    expect(
      fixture.scheduler.registered,
      isNot(contains('goal_reminder_trip_3d')),
    );
    expect(fixture.scheduler.pending, isNot(contains('goal_reminder_trip_3d')));
    // The later ones are untouched.
    expect(fixture.scheduler.pending, contains('goal_reminder_trip_due'));
  });

  test(
    'only a real quiet-hours change is recorded, for this account',
    () async {
      final fixture = _Fixture();
      await fixture.service.setQuietHours(const QuietHours());
      expect(
        fixture.preferences.values,
        isNot(contains('quiet_hours_changed_at')),
      );
      expect(
        fixture.preferences.values,
        isNot(contains('task_reminder_rules_changed_at')),
      );

      await fixture.service.setQuietHours(const QuietHours(enabled: true));
      final String stamp = fixture.now.toIso8601String();
      expect(fixture.preferences.values['quiet_hours_changed_at'], stamp);
      expect(
        fixture.preferences.values['task_reminder_rules_changed_at'],
        stamp,
      );

      // The same setting again is not a change.
      fixture.now = fixture.now.add(const Duration(hours: 1));
      await fixture.service.setQuietHours(const QuietHours(enabled: true));
      expect(fixture.preferences.values['quiet_hours_changed_at'], stamp);

      // Each of on/off, start and end is.
      for (final QuietHours next in const <QuietHours>[
        QuietHours(enabled: true, startMinutes: 23 * 60),
        QuietHours(enabled: true, startMinutes: 23 * 60, endMinutes: 6 * 60),
        QuietHours(startMinutes: 23 * 60, endMinutes: 6 * 60),
      ]) {
        fixture.now = fixture.now.add(const Duration(minutes: 1));
        await fixture.service.setQuietHours(next);
        expect(
          fixture.preferences.values['quiet_hours_changed_at'],
          fixture.now.toIso8601String(),
        );
      }
      expect(
        AccountDataRegistry.reminderPreferenceKeys,
        contains('quiet_hours_changed_at'),
      );
    },
  );

  test('turning quiet hours off while a lead-time reminder is held reminds '
      'at the time itself', () async {
    final fixture = _Fixture()..now = utc(local(2026, 11, 2, 21));
    fixture.preferences.values
      ..['quiet_hours_enabled'] = 'true'
      ..['quiet_hours_start'] = '22:0'
      ..['quiet_hours_end'] = '7:0'
      ..['task_reminder_lead_minutes'] = '60';
    final DateTime saved = fixture.now;
    fixture.tasks = [
      _task(
        'soon',
        scheduledFor: local(2026, 11, 3, 7, 30),
      ).copyWith(updatedAt: saved),
      // Its own time passes before quiet hours are turned off.
      _task(
        'early',
        scheduledFor: local(2026, 11, 3, 6, 40),
      ).copyWith(updatedAt: saved),
    ];
    expect(await fixture.reconcile(const [], const []), isTrue);
    expect(
      fixture.scheduler.times['task_reminder_start_soon'],
      utc(local(2026, 11, 3, 7)),
    );
    expect(
      fixture.scheduler.times['task_reminder_start_early'],
      utc(local(2026, 11, 3, 7)),
    );

    fixture.now = utc(local(2026, 11, 3, 6, 45));
    fixture.scheduler.clearLog();
    await fixture.service.setQuietHours(const QuietHours());
    expect(await fixture.reconcile(const [], const []), isTrue);
    expect(fixture.scheduler.registered, ['task_reminder_start_soon']);
    expect(
      fixture.scheduler.times['task_reminder_start_soon'],
      utc(local(2026, 11, 3, 7, 30)),
    );
    expect(fixture.scheduler.pending.where((id) => id.startsWith('task_')), {
      'task_reminder_start_soon',
    });
  });

  test('a lead-time reminder delivered at the end of quiet hours is not '
      'followed by one at the time itself', () async {
    final fixture = _Fixture()..now = utc(local(2026, 11, 2, 21));
    fixture.preferences.values
      ..['quiet_hours_enabled'] = 'true'
      ..['quiet_hours_start'] = '22:0'
      ..['quiet_hours_end'] = '7:0'
      ..['task_reminder_lead_minutes'] = '60';
    fixture.tasks = [
      _task(
        'soon',
        scheduledFor: local(2026, 11, 3, 7, 30),
      ).copyWith(updatedAt: fixture.now),
    ];
    expect(await fixture.reconcile(const [], const []), isTrue);

    // 06:45: task reminders are switched off and on again.
    fixture.now = utc(local(2026, 11, 3, 6, 45));
    await fixture.service.setTaskRemindersEnabled(false);
    expect(await fixture.reconcile(const [], const []), isTrue);
    await fixture.service.setTaskRemindersEnabled(true);
    expect(await fixture.reconcile(const [], const []), isTrue);
    expect(
      fixture.scheduler.times['task_reminder_start_soon'],
      utc(local(2026, 11, 3, 7)),
    );

    // 07:10: it went off at 07:00.
    fixture.now = utc(local(2026, 11, 3, 7, 10));
    fixture.scheduler.pending.remove('task_reminder_start_soon');
    fixture.scheduler.clearLog();
    expect(await fixture.reconcile(const [], const []), isTrue);
    await fixture.service.syncTaskReminders(
      permissionGranted: true,
      shouldContinue: () => true,
    );
    expect(fixture.scheduler.registered, isEmpty);
    expect(
      fixture.scheduler.pending.where((id) => id.startsWith('task_')),
      isEmpty,
    );
  });

  test('the streak nudge is not listed or registered while the main switch '
      'is off, and turning it off cancels one that is waiting', () async {
    final fixture = _Fixture();
    Future<bool> nudge(String day) => fixture.service.scheduleStreakBreakNudge(
      id: 'streak_break_recovery_$day',
      title: 'Rebuild your streak today',
      body: 'Your streak chain broke.',
      at: DateTime.utc(2026, 11, 1, 17),
    );
    expect(await nudge('2026-11-01'), isTrue);
    expect(
      fixture.listed.entries,
      contains('streak_break_recovery_2026-11-01'),
    );

    fixture.preferences.values['reminders_enabled'] = 'false';
    expect(await fixture.reconcile(const [], const []), isTrue);
    expect(fixture.listed.cancelled, ['streak_break_recovery_2026-11-01']);
    expect(fixture.listed.entries, isEmpty);

    expect(await nudge('2026-11-02'), isFalse);
    expect(fixture.listed.entries, isEmpty);
  });
}

TaskEntity _task(String id, {DateTime? dueDate, DateTime? scheduledFor}) =>
    TaskEntity(
      id: id,
      title: 'Task $id',
      createdAt: DateTime.utc(2026, 10, 1),
      dueDate: dueDate,
      scheduledFor: scheduledFor,
    );

class _Fixture {
  _Fixture() {
    preferences.values['legacy_habit_reminder_migrated'] = 'true';
  }

  DateTime now = DateTime.utc(2026, 11, 1, 15);
  List<TaskEntity> tasks = <TaskEntity>[];
  final preferences = _Preferences();
  final scheduler = _Scheduler();
  final listed = _Repository();
  late final service = ReminderOrchestratorService(
    preferences: preferences,
    notifications: NotificationsService(listed),
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

/// The in-app notification list; its entries reach the OS in the app.
class _Repository implements INotificationRepository {
  final Map<String, NotificationEntity> entries =
      <String, NotificationEntity>{};
  final List<String> cancelled = <String>[];
  @override
  Future<void> cancelNotification(String id) async {
    cancelled.add(id);
    entries.remove(id);
  }

  @override
  Future<void> delete(String id) async {}
  @override
  Future<List<NotificationEntity>> getNotifications() async =>
      entries.values.toList();
  @override
  Future<void> markRead(String id) async {}
  @override
  Future<void> scheduleNotification(NotificationEntity notification) async {
    entries[notification.id] = notification;
  }
}
