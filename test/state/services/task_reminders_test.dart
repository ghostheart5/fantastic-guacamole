import 'package:fantastic_guacamole/core/data/account_data_registry.dart';
import 'package:fantastic_guacamole/data/repositories/notifications_repository.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/entities/notification_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_notification_repository.dart';
import 'package:fantastic_guacamole/domain/ports/notification_scheduler_port.dart';
import 'package:fantastic_guacamole/state/services/notifications_service.dart';
import 'package:fantastic_guacamole/state/services/reminder_orchestrator_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

const String _scope = 'task-reminder-scope';

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

  group('task reminder planner', () {
    final DateTime now = DateTime.utc(2026, 11, 2, 15); // 10:00 in New York.

    test('a future start time gets one start reminder at that time', () {
      final slots = TaskReminderPlanner.plan(<TaskEntity>[
        _task(
          'a',
          scheduledFor: local(2026, 11, 2, 14, 30),
          dueDate: local(2026, 11, 3, 17),
        ),
      ], now: now);

      expect(slots.map((slot) => slot.id), <String>['task_reminder_start_a']);
      expect(
        slots.single.at.isAtSameMomentAs(local(2026, 11, 2, 14, 30)),
        true,
      );
      expect(slots.single.title, 'Time to start');
      expect(slots.single.body, '"Task a" starts now.');
    });

    test('a past start time gets nothing, not even a deadline reminder', () {
      final slots = TaskReminderPlanner.plan(<TaskEntity>[
        _task(
          'a',
          scheduledFor: local(2026, 11, 2, 8),
          dueDate: local(2026, 11, 3, 17),
        ),
      ], now: now);

      expect(slots, isEmpty);
    });

    test('a timed deadline without a start time reminds at the deadline', () {
      final slots = TaskReminderPlanner.plan(<TaskEntity>[
        _task('a', dueDate: local(2026, 11, 3, 17, 15)),
      ], now: now);

      expect(slots.map((slot) => slot.id), <String>['task_reminder_due_a']);
      expect(
        slots.single.at.isAtSameMomentAs(local(2026, 11, 3, 17, 15)),
        true,
      );
      expect(slots.single.body, '"Task a" is due now.');
    });

    test('a date-only deadline reminds at 9 AM local that day', () {
      final slots = TaskReminderPlanner.plan(<TaskEntity>[
        _task('a', dueDate: DateTime(2026, 11, 4)),
      ], now: now);

      expect(slots.single.id, 'task_reminder_due_a');
      expect(slots.single.at.isAtSameMomentAs(local(2026, 11, 4, 9)), true);
      expect(slots.single.title, 'Task due today');
      expect(slots.single.body, '"Task a" is due today.');
    });

    test(
      'a date-only deadline keeps 9 AM local across a daylight-saving change',
      () {
        // Clocks in New York move forward at 2 AM on Sunday 8 March 2026.
        final slots = TaskReminderPlanner.plan(
          <TaskEntity>[
            _task('due', dueDate: DateTime(2026, 3, 8)),
            _task('late', dueDate: DateTime(2026, 3, 7)),
          ],
          now: DateTime.utc(2026, 3, 7, 6),
          overdueNudges: true,
        );
        final byId = {for (final slot in slots) slot.id: slot.at};

        // 9 AM daylight time is 13:00 UTC; the standard-time offset would
        // have given 14:00 UTC.
        expect(byId['task_reminder_due_due'], DateTime.utc(2026, 3, 8, 13));
        expect(
          byId['task_reminder_overdue_late'],
          DateTime.utc(2026, 3, 8, 13),
        );
        expect(byId['task_reminder_due_late'], DateTime.utc(2026, 3, 7, 14));
      },
    );

    test('the overdue nudge comes only when it is turned on', () {
      final task = _task('a', dueDate: DateTime(2026, 11, 4));

      expect(
        TaskReminderPlanner.plan(<TaskEntity>[task], now: now).map((s) => s.id),
        <String>['task_reminder_due_a'],
      );
      final slots = TaskReminderPlanner.plan(
        <TaskEntity>[task],
        now: now,
        overdueNudges: true,
      );
      expect(slots.map((slot) => slot.id), <String>[
        'task_reminder_due_a',
        'task_reminder_overdue_a',
      ]);
      expect(slots.last.at.isAtSameMomentAs(local(2026, 11, 5, 9)), true);
      expect(slots.last.title, 'Task overdue');
    });

    test('a task never gets more than a start or due plus one overdue', () {
      final slots = TaskReminderPlanner.plan(
        <TaskEntity>[
          _task(
            'a',
            scheduledFor: local(2026, 11, 3, 8),
            dueDate: local(2026, 11, 4, 18),
          ),
        ],
        now: now,
        overdueNudges: true,
      );

      expect(slots.map((slot) => slot.id), <String>[
        'task_reminder_start_a',
        'task_reminder_overdue_a',
      ]);
    });

    test('a lead time moves start and due reminders earlier', () {
      final slots = TaskReminderPlanner.plan(
        <TaskEntity>[
          _task('start', scheduledFor: local(2026, 11, 2, 14)),
          _task('due', dueDate: local(2026, 11, 2, 16)),
        ],
        now: now,
        leadTime: const Duration(minutes: 15),
      );
      final byId = {for (final slot in slots) slot.id: slot};

      expect(
        byId['task_reminder_start_start']!.at.isAtSameMomentAs(
          local(2026, 11, 2, 13, 45),
        ),
        true,
      );
      expect(
        byId['task_reminder_start_start']!.body,
        '"Task start" starts in 15 minutes.',
      );
      expect(
        byId['task_reminder_due_due']!.at.isAtSameMomentAs(
          local(2026, 11, 2, 15, 45),
        ),
        true,
      );
      expect(
        byId['task_reminder_due_due']!.body,
        '"Task due" is due in 15 minutes.',
      );
    });

    test('a task saved inside its lead time is reminded at its time', () {
      // Starts and is due in 10 minutes, with a 15-minute lead time.
      final slots = TaskReminderPlanner.plan(
        <TaskEntity>[
          _task(
            'start',
            scheduledFor: now.add(const Duration(minutes: 10)),
          ).copyWith(updatedAt: now),
          _task(
            'due',
            dueDate: now.add(const Duration(minutes: 10)),
          ).copyWith(updatedAt: now),
        ],
        now: now,
        leadTime: const Duration(minutes: 15),
      );
      final byId = {for (final slot in slots) slot.id: slot};

      expect(
        byId['task_reminder_start_start']!.at,
        now.add(const Duration(minutes: 10)),
      );
      expect(
        byId['task_reminder_start_start']!.body,
        '"Task start" starts now.',
      );
      expect(
        byId['task_reminder_due_due']!.at,
        now.add(const Duration(minutes: 10)),
      );
      expect(byId['task_reminder_due_due']!.body, '"Task due" is due now.');
    });

    test('after its lead-time reminder no second one follows', () {
      // Saved an hour ago; the 15-minute reminder was due 5 minutes ago.
      final slots = TaskReminderPlanner.plan(
        <TaskEntity>[
          _task(
            'a',
            scheduledFor: now.add(const Duration(minutes: 10)),
          ).copyWith(updatedAt: now.subtract(const Duration(hours: 1))),
        ],
        now: now,
        leadTime: const Duration(minutes: 15),
      );

      expect(slots, isEmpty);
    });

    test('completed, skipped and removed tasks get no reminders', () {
      final DateTime at = local(2026, 11, 3, 9);
      final slots = TaskReminderPlanner.plan(<TaskEntity>[
        _task('done', scheduledFor: at).complete(at: now),
        _task(
          'skipped',
          scheduledFor: at,
        ).copyWith(isSkipped: true, skippedAt: now),
        _task('removed', scheduledFor: at).cancel(at: now),
      ], now: now);

      expect(slots, isEmpty);
    });

    test('only the 20 nearest reminders are kept', () {
      final tasks = <TaskEntity>[
        for (var i = 24; i >= 0; i--)
          _task(
            't$i',
            scheduledFor: local(2026, 11, 3, 0, 0).add(Duration(hours: i)),
          ),
      ];
      final slots = TaskReminderPlanner.plan(tasks, now: now);

      expect(slots, hasLength(20));
      expect(slots.first.id, 'task_reminder_start_t0');
      expect(slots.last.id, 'task_reminder_start_t19');
    });

    test('reminder text follows Spanish', () {
      final slots = TaskReminderPlanner.plan(
        <TaskEntity>[
          _task('start', scheduledFor: local(2026, 11, 2, 14)),
          _task('day', dueDate: DateTime(2026, 11, 4)),
        ],
        now: now,
        overdueNudges: true,
        spanish: true,
      );
      final byId = {for (final slot in slots) slot.id: slot};

      expect(byId['task_reminder_start_start']!.title, 'Hora de empezar');
      expect(
        byId['task_reminder_start_start']!.body,
        '«Task start» empieza ahora.',
      );
      expect(byId['task_reminder_due_day']!.title, 'Tarea para hoy');
      expect(byId['task_reminder_due_day']!.body, '«Task day» vence hoy.');
      expect(byId['task_reminder_overdue_day']!.title, 'Tarea vencida');
      expect(
        byId['task_reminder_overdue_day']!.body,
        '«Task day» venció ayer y sigue pendiente.',
      );
    });
  });

  group('task reminder group', () {
    test('a reconcile registers the task reminders with the OS', () async {
      final fixture = _Fixture();
      fixture.tasks = [fixture.dated('a', hours: 2)];

      expect(await fixture.reconcile(), isTrue);
      expect(fixture.scheduler.pending, contains('task_reminder_start_a'));
      expect(
        fixture.scheduler.titles['task_reminder_start_a'],
        'Time to start',
      );
    });

    test('completing a task cancels its pending reminder', () async {
      final fixture = _Fixture();
      final task = fixture.dated('a', hours: 2);
      fixture.tasks = [task];
      expect(await fixture.sync(), isTrue);
      expect(fixture.scheduler.pending, {'task_reminder_start_a'});

      fixture.scheduler.clearLog();
      fixture.tasks = [task.complete(at: fixture.now)];
      expect(await fixture.sync(), isTrue);
      expect(fixture.scheduler.cancelled, ['task_reminder_start_a']);
      expect(fixture.scheduler.pending, isEmpty);
    });

    for (final String change in <String>[
      'completing',
      'skipping',
      'removing',
    ]) {
      test('$change a task also clears its delivered reminder from the tray, '
          'even after later updates', () async {
        final fixture = _Fixture();
        final task = fixture.dated('a', hours: 2);
        fixture.tasks = [task];
        expect(await fixture.sync(), isTrue);

        // It went off and is shown in the tray; the app is opened and other
        // updates run while the task stays open.
        fixture.now = fixture.now.add(const Duration(hours: 2, minutes: 5));
        fixture.scheduler.pending.remove('task_reminder_start_a');
        fixture.scheduler.clearLog();
        expect(await fixture.reconcile(), isTrue);
        expect(await fixture.sync(), isTrue);
        await fixture.service.setRemindersEnabled(false);
        expect(await fixture.reconcile(), isTrue);
        await fixture.service.setRemindersEnabled(true);
        expect(await fixture.reconcile(), isTrue);
        await fixture.service.setTaskRemindersEnabled(false);
        await fixture.service.setTaskRemindersEnabled(true);
        expect(await fixture.reconcile(), isTrue);
        // An open task keeps its shown reminder.
        expect(fixture.scheduler.cancelled, isEmpty);

        fixture.tasks = switch (change) {
          'completing' => [task.complete(at: fixture.now)],
          'skipping' => [
            task.copyWith(isSkipped: true, skippedAt: fixture.now),
          ],
          _ => <TaskEntity>[],
        };
        expect(await fixture.sync(), isTrue);
        expect(fixture.scheduler.cancelled, ['task_reminder_start_a']);

        // Only once.
        fixture.scheduler.clearLog();
        expect(await fixture.reconcile(), isTrue);
        expect(fixture.scheduler.cancelled, isEmpty);
      });
    }

    test('moving a task moves its reminder', () async {
      final fixture = _Fixture();
      final task = fixture.dated('a', hours: 2);
      fixture.tasks = [task];
      await fixture.sync();

      fixture.scheduler.clearLog();
      final DateTime later = fixture.now.add(const Duration(hours: 5));
      fixture.tasks = [task.copyWith(scheduledFor: later)];
      expect(await fixture.sync(), isTrue);
      expect(fixture.scheduler.registered, ['task_reminder_start_a']);
      expect(fixture.scheduler.times['task_reminder_start_a'], later);
    });

    test('nothing changes when the tasks did not change', () async {
      final fixture = _Fixture();
      fixture.tasks = [fixture.dated('a', hours: 2)];
      await fixture.sync();

      fixture.scheduler.clearLog();
      expect(await fixture.sync(), isTrue);
      expect(fixture.scheduler.registered, isEmpty);
      expect(fixture.scheduler.cancelled, isEmpty);
    });

    test('the next reminders are registered as earlier ones pass', () async {
      final fixture = _Fixture();
      fixture.tasks = [
        for (var i = 1; i <= 21; i++) fixture.dated('t$i', hours: i),
      ];
      await fixture.sync();
      expect(fixture.scheduler.pending, hasLength(20));
      expect(
        fixture.scheduler.pending,
        isNot(contains('task_reminder_start_t21')),
      );

      // The first reminder fired and left the OS list.
      fixture.now = fixture.now.add(const Duration(hours: 1, minutes: 5));
      fixture.scheduler.pending.remove('task_reminder_start_t1');
      fixture.scheduler.clearLog();
      await fixture.sync();
      expect(fixture.scheduler.registered, ['task_reminder_start_t21']);
      expect(fixture.scheduler.pending, hasLength(20));
    });

    test('turning task reminders off cancels every task reminder', () async {
      final fixture = _Fixture();
      fixture.tasks = [
        fixture.dated('a', hours: 2),
        fixture.dated('b', hours: 3),
      ];
      await fixture.sync();
      fixture.scheduler.clearLog();

      await fixture.service.setTaskRemindersEnabled(false);
      expect(fixture.scheduler.cancelled.toSet(), {
        'task_reminder_start_a',
        'task_reminder_start_b',
      });
      expect(fixture.scheduler.pending, isEmpty);
      expect(fixture.service.loadPrefs().taskRemindersEnabled, isFalse);

      fixture.scheduler.clearLog();
      expect(await fixture.reconcile(), isTrue);
      expect(fixture.scheduler.registered, isEmpty);
    });

    test('task reminders are on and overdue nudges off by default', () {
      final prefs = _Fixture().service.loadPrefs();
      expect(prefs.taskRemindersEnabled, isTrue);
      expect(prefs.taskOverdueNudgesEnabled, isFalse);
      expect(prefs.taskReminderLeadMinutes, 0);
    });

    test('stored lead time and overdue choice reach the planner', () async {
      final fixture = _Fixture();
      fixture.preferences.values['task_reminder_lead_minutes'] = '10';
      fixture.preferences.values['task_overdue_nudges_enabled'] = 'true';
      final DateTime due = fixture.now.add(const Duration(hours: 2));
      fixture.tasks = [_task('a', dueDate: due)];

      await fixture.sync();
      expect(
        fixture.scheduler.times['task_reminder_due_a'],
        due.subtract(const Duration(minutes: 10)),
      );
      expect(fixture.scheduler.pending, contains('task_reminder_overdue_a'));
    });

    test('without permission each reminder is cleared once', () async {
      final fixture = _Fixture();
      fixture.tasks = [fixture.dated('a', hours: 2)];
      await fixture.sync();
      fixture.scheduler.clearLog();

      expect(await fixture.sync(permission: false), isFalse);
      expect(fixture.scheduler.cancelled, ['task_reminder_start_a']);
      expect(fixture.scheduler.registered, isEmpty);

      fixture.scheduler.clearLog();
      await fixture.sync(permission: false);
      expect(fixture.scheduler.cancelled, isEmpty);

      expect(await fixture.sync(), isTrue);
      expect(fixture.scheduler.registered, ['task_reminder_start_a']);
    });

    test('the text follows the app language', () async {
      final fixture = _Fixture()..spanish = true;
      fixture.tasks = [fixture.dated('a', hours: 2)];
      await fixture.sync();
      expect(
        fixture.scheduler.titles['task_reminder_start_a'],
        'Hora de empezar',
      );

      // A language change re-registers with the new text.
      fixture.spanish = false;
      fixture.scheduler.clearLog();
      await fixture.reconcile();
      expect(fixture.scheduler.registered, ['task_reminder_start_a']);
      expect(
        fixture.scheduler.titles['task_reminder_start_a'],
        'Time to start',
      );
    });

    test('a new lead time inside the window still reminds at the time '
        'itself', () async {
      // Starts at 10:10; registered for 10:10 with no lead time.
      final fixture = _Fixture();
      final DateTime start = fixture.now.add(const Duration(minutes: 10));
      fixture.tasks = [_task('a', scheduledFor: start)];
      await fixture.sync();
      expect(fixture.scheduler.times['task_reminder_start_a'], start);

      // At 10:00 the person picks "15 minutes before": that moment has
      // passed, but no reminder came yet.
      await fixture.service.setTaskReminderLeadMinutes(15);
      fixture.scheduler.clearLog();
      expect(await fixture.reconcile(), isTrue);
      expect(fixture.scheduler.cancelled, isEmpty);
      expect(fixture.scheduler.pending, contains('task_reminder_start_a'));
      expect(fixture.scheduler.times['task_reminder_start_a'], start);
    });

    test('a task whose lead-time reminder was delivered gets no second '
        'one', () async {
      final fixture = _Fixture();
      await fixture.service.setTaskReminderLeadMinutes(15);
      fixture.now = fixture.now.add(const Duration(minutes: 1));
      final DateTime start = fixture.now.add(const Duration(minutes: 30));
      fixture.tasks = [_task('a', scheduledFor: start)];
      await fixture.sync();
      expect(
        fixture.scheduler.times['task_reminder_start_a'],
        start.subtract(const Duration(minutes: 15)),
      );

      // It fired and left the OS list; nothing else changed.
      fixture.now = fixture.now.add(const Duration(minutes: 20));
      fixture.scheduler.pending.remove('task_reminder_start_a');
      fixture.scheduler.clearLog();
      expect(await fixture.sync(), isTrue);
      expect(await fixture.reconcile(), isTrue);
      expect(fixture.scheduler.registered, isEmpty);
      expect(fixture.scheduler.pending, isEmpty);
    });

    for (final String name in <String>['main switch', 'task reminders']) {
      test('turned back on with the $name after the lead moment, the task '
          'is reminded at its time', () async {
        final fixture = _Fixture();
        await fixture.service.setTaskReminderLeadMinutes(15);
        fixture.now = fixture.now.add(const Duration(minutes: 1));
        final DateTime start = fixture.now.add(const Duration(minutes: 30));
        fixture.tasks = [_task('a', scheduledFor: start)];
        await fixture.sync();

        Future<void> set(bool on) => name == 'main switch'
            ? fixture.service.setRemindersEnabled(on)
            : fixture.service.setTaskRemindersEnabled(on);
        await set(false);
        await fixture.reconcile();
        expect(fixture.scheduler.pending, isEmpty);

        // The lead moment passes while reminders are off.
        fixture.now = fixture.now.add(const Duration(minutes: 20));
        await set(true);
        fixture.scheduler.clearLog();
        expect(await fixture.reconcile(), isTrue);
        expect(fixture.scheduler.registered, ['task_reminder_start_a']);
        expect(fixture.scheduler.times['task_reminder_start_a'], start);
      });
    }

    test('when permission returns after the lead moment, the task is '
        'reminded at its time', () async {
      final fixture = _Fixture();
      await fixture.service.setTaskReminderLeadMinutes(15);
      fixture.now = fixture.now.add(const Duration(minutes: 1));
      final DateTime start = fixture.now.add(const Duration(minutes: 30));
      fixture.tasks = [_task('a', scheduledFor: start)];
      await fixture.sync();

      fixture.now = fixture.now.add(const Duration(minutes: 5));
      await fixture.sync(permission: false);
      expect(fixture.scheduler.pending, isEmpty);

      fixture.now = fixture.now.add(const Duration(minutes: 15));
      fixture.scheduler.clearLog();
      expect(await fixture.sync(), isTrue);
      expect(fixture.scheduler.registered, ['task_reminder_start_a']);
      expect(fixture.scheduler.times['task_reminder_start_a'], start);

      // Only once: a later update does not register it again.
      fixture.scheduler.clearLog();
      await fixture.reconcile();
      expect(fixture.scheduler.registered, isEmpty);
    });

    test('new task preferences are cleared with the account', () {
      for (final key in <String>[
        'task_reminders_enabled',
        'task_overdue_nudges_enabled',
        'task_reminder_lead_minutes',
        'scheduled_task_reminder_ids',
        'task_reminder_rules_changed_at',
      ]) {
        expect(AccountDataRegistry.reminderPreferenceKeys, contains(key));
      }
    });

    test('sign-out cancels the task reminders the OS holds', () async {
      final scheduler = _Scheduler(
        scope: AccountDataRegistry.accountDigest('account-a'),
      )..pending.addAll(<String>['task_reminder_due_a', 'other_reminder']);
      final repository = NotificationsRepository(
        scheduler,
        SecureStore(backend: InMemorySecureStoreBackend()),
        accountId: 'account-a',
      );

      await repository.cancelAccountSchedules();
      expect(scheduler.cancelled, contains('task_reminder_due_a'));
      expect(scheduler.cancelled, isNot(contains('other_reminder')));
    });

    test(
      'sign-out also cancels the weekday habit alarms the OS holds',
      () async {
        final scheduler = _Scheduler(
          scope: AccountDataRegistry.accountDigest('account-a'),
        )..pending.addAll(<String>['habit_reminder_walk_wd3']);
        final repository = NotificationsRepository(
          scheduler,
          SecureStore(backend: InMemorySecureStoreBackend()),
          accountId: 'account-a',
        );

        await repository.cancelAccountSchedules();
        expect(scheduler.cancelled, contains('habit_reminder_walk_wd3'));
      },
    );
  });
}

TaskEntity _task(String id, {DateTime? scheduledFor, DateTime? dueDate}) =>
    TaskEntity(
      id: id,
      title: 'Task $id',
      createdAt: DateTime.utc(2026, 10, 1),
      scheduledFor: scheduledFor,
      dueDate: dueDate,
    );

class _Fixture {
  _Fixture() {
    preferences.values['legacy_habit_reminder_migrated'] = 'true';
    preferences.values['daily_planning_reminder_enabled'] = 'false';
  }

  DateTime now = DateTime.utc(2026, 11, 2, 15);
  bool spanish = false;
  List<TaskEntity> tasks = <TaskEntity>[];
  final preferences = _Preferences();
  final scheduler = _Scheduler(scope: _scope);
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
    isSpanish: () => spanish,
  );

  TaskEntity dated(String id, {required int hours}) =>
      _task(id, scheduledFor: now.add(Duration(hours: hours)));

  Future<bool> reconcile({bool permission = true}) =>
      service.reconcileAfterRestore(
        goals: const [],
        habits: const [],
        permissionGranted: permission,
        shouldContinue: () => true,
      );

  Future<bool> sync({bool permission = true}) => service.syncTaskReminders(
    permissionGranted: permission,
    shouldContinue: () => true,
  );
}

class _Scheduler implements NotificationSchedulerPort {
  _Scheduler({required this.scope});

  final String scope;
  final Set<String> pending = <String>{};
  final List<String> registered = <String>[];
  final List<String> cancelled = <String>[];
  final Map<String, DateTime> times = <String, DateTime>{};
  final Map<String, String> titles = <String, String>{};

  void clearLog() {
    registered.clear();
    cancelled.clear();
  }

  @override
  Future<NotificationScheduleResult> schedule(
    NotificationEntity notification, {
    String? accountScope,
  }) async {
    expect(accountScope, scope);
    expect(notification.isEnabled, isTrue);
    registered.add(notification.id);
    pending.add(notification.id);
    times[notification.id] = notification.scheduledAt;
    titles[notification.id] = notification.title;
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
  }) async => throw StateError('No daily reminder expected');

  @override
  Future<NotificationScheduleResult> scheduleCadenceAt({
    required String id,
    required String title,
    required String body,
    required HabitCadence cadence,
    required DateTime firstAt,
    String? accountScope,
  }) async => throw StateError('No rhythm reminder expected');

  @override
  Future<bool> cancel(String id, {String? accountScope}) async {
    expect(accountScope, scope);
    cancelled.add(id);
    pending.remove(id);
    return true;
  }

  @override
  Future<List<String>> pendingIdsForAccount(String accountScope) async {
    expect(accountScope, scope);
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
