import 'dart:async';

import 'package:fantastic_guacamole/core/async/keyed_mutation_coordinator.dart';
import 'package:fantastic_guacamole/core/data/account_data_registry.dart';
import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/core/debug/runtime_diagnostics.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/entities/notification_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_notification_repository.dart';
import 'package:fantastic_guacamole/domain/ports/notification_scheduler_port.dart';
import 'package:fantastic_guacamole/state/services/notifications_service.dart';
import 'package:fantastic_guacamole/state/services/reminder_orchestrator_service.dart';
import 'package:flutter_test/flutter_test.dart';

const String _scope = 'reconcile-scope';

void main() {
  setUp(() {
    RuntimeDiagnostics.events.value = const <RuntimeDiagnosticEvent>[];
  });

  test('resume with nothing changed cancels and registers nothing', () async {
    final fixture = _Fixture();
    final goals = [fixture.goal('trip')];
    final habits = [fixture.habit('walk', minutes: 18 * 60)];
    expect(await fixture.reconcile(goals, habits), isTrue);
    expect(fixture.scheduler.pending, {
      'daily_planning_reminder',
      'habit_reminder_walk',
      'goal_reminder_trip_3d',
      'goal_reminder_trip',
      'goal_reminder_trip_due',
    });

    fixture.scheduler.clearLog();
    expect(await fixture.reconcile(goals, habits), isTrue);
    expect(fixture.scheduler.cancelled, isEmpty);
    expect(fixture.scheduler.registered, isEmpty);
  });

  test('a matching pending daily planning reminder is preserved', () async {
    final fixture = _Fixture();
    expect(await fixture.reconcile([], []), isTrue);
    // The nominal minute has passed but the inexact alarm has not fired yet.
    fixture.now = DateTime(2026, 11, 2, 7, 31);
    fixture.scheduler.clearLog();
    expect(await fixture.reconcile([], []), isTrue);
    expect(fixture.scheduler.cancelled, isEmpty);
    expect(fixture.scheduler.registered, isEmpty);
  });

  test('a changed habit time replaces exactly that reminder', () async {
    final fixture = _Fixture();
    final goals = [fixture.goal('trip')];
    final walk = fixture.habit('walk', minutes: 18 * 60);
    final read = fixture.habit('read', minutes: 21 * 60);
    expect(await fixture.reconcile(goals, [walk, read]), isTrue);

    fixture.scheduler.clearLog();
    final moved = walk.copyWith(reminderMinutes: 19 * 60);
    expect(await fixture.reconcile(goals, [moved, read]), isTrue);
    expect(fixture.scheduler.registered, ['habit_reminder_walk']);
    expect(fixture.scheduler.cancelled, isEmpty);
    expect(fixture.scheduler.cadenceTimes['habit_reminder_walk'], (19, 0));
  });

  test(
    'a throwing goal registration still registers habits and planning',
    () async {
      final fixture = _Fixture();
      fixture.scheduler.throwOn = 'goal_reminder_trip_3d';
      final result = await Logger.withMutedErrors(
        () => fixture.reconcile(
          [fixture.goal('trip')],
          [fixture.habit('walk', minutes: 18 * 60)],
        ),
      );
      expect(result, isFalse);
      expect(
        fixture.scheduler.pending,
        containsAll(<String>[
          'daily_planning_reminder',
          'habit_reminder_walk',
          // The goal's other reminders are not lost either.
          'goal_reminder_trip',
          'goal_reminder_trip_due',
        ]),
      );
      final coded = RuntimeDiagnostics.events.value
          .where((event) => event.category == 'reminders.reconcile_incomplete')
          .toList();
      expect(coded, hasLength(1));
      expect(coded.single.data['groups'], 'goals');

      // The next run retries only what failed.
      fixture.scheduler
        ..throwOn = null
        ..clearLog();
      expect(
        await fixture.reconcile(
          [fixture.goal('trip')],
          [fixture.habit('walk', minutes: 18 * 60)],
        ),
        isTrue,
      );
      expect(fixture.scheduler.registered, ['goal_reminder_trip_3d']);
      expect(fixture.scheduler.cancelled, isEmpty);
    },
  );

  test('a removed goal cancels only its own reminders', () async {
    final fixture = _Fixture();
    final habits = [fixture.habit('walk', minutes: 18 * 60)];
    expect(
      await fixture.reconcile([
        fixture.goal('trip'),
        fixture.goal('move'),
      ], habits),
      isTrue,
    );

    fixture.scheduler.clearLog();
    expect(await fixture.reconcile([fixture.goal('move')], habits), isTrue);
    expect(fixture.scheduler.registered, isEmpty);
    expect(
      fixture.scheduler.cancelled,
      everyElement(startsWith('goal_reminder_trip')),
    );
    expect(
      fixture.scheduler.cancelled,
      containsAll(<String>[
        'goal_reminder_trip_3d',
        'goal_reminder_trip',
        'goal_reminder_trip_due',
      ]),
    );
    expect(
      fixture.scheduler.pending.where((id) => id.startsWith('goal_reminder_')),
      unorderedEquals(<String>[
        'goal_reminder_move_3d',
        'goal_reminder_move',
        'goal_reminder_move_due',
      ]),
    );
  });

  test('a goal reminder whose time just passed is left to fire', () async {
    final fixture = _Fixture();
    final goals = [fixture.goal('trip')];
    expect(await fixture.reconcile(goals, []), isTrue);
    // Three days before the target, just after 9 AM; the OS has not
    // delivered the inexact alarm yet.
    fixture.now = DateTime(2026, 11, 3, 9, 1);
    fixture.scheduler.clearLog();
    expect(await fixture.reconcile(goals, []), isTrue);
    expect(fixture.scheduler.cancelled, isEmpty);
    expect(fixture.scheduler.registered, isEmpty);
    expect(fixture.scheduler.pending, contains('goal_reminder_trip_3d'));
  });

  test('a time zone change re-registers every reminder once', () async {
    final fixture = _Fixture();
    final goals = [fixture.goal('trip')];
    final habits = [fixture.habit('walk', minutes: 18 * 60)];
    expect(await fixture.reconcile(goals, habits), isTrue);
    fixture.zone = 'Europe/Paris';
    fixture.scheduler.clearLog();
    expect(await fixture.reconcile(goals, habits), isTrue);
    expect(fixture.scheduler.cancelled, isEmpty);
    expect(
      fixture.scheduler.registered,
      unorderedEquals(<String>[
        'daily_planning_reminder',
        'habit_reminder_walk',
        'goal_reminder_trip_3d',
        'goal_reminder_trip',
        'goal_reminder_trip_due',
      ]),
    );
  });

  test('a reminder missing from the OS is registered again', () async {
    final fixture = _Fixture();
    final habits = [fixture.habit('walk', minutes: 18 * 60)];
    expect(await fixture.reconcile([], habits), isTrue);
    fixture.scheduler.pending.remove('habit_reminder_walk');
    fixture.scheduler.clearLog();
    expect(await fixture.reconcile([], habits), isTrue);
    expect(fixture.scheduler.registered, ['habit_reminder_walk']);
    expect(fixture.scheduler.cancelled, isEmpty);
  });

  test('a reminder set up by a later sync is not registered again', () async {
    final fixture = _Fixture();
    final habits = [fixture.habit('walk', minutes: 18 * 60)];
    expect(await fixture.reconcile([], habits), isTrue);
    final moved = [habits.single.copyWith(reminderMinutes: 6 * 60)];
    await fixture.service.syncHabitReminders(moved);
    fixture.scheduler.clearLog();
    expect(await fixture.reconcile([], moved), isTrue);
    expect(fixture.scheduler.registered, isEmpty);
    expect(fixture.scheduler.cancelled, isEmpty);
  });

  test('goal sync waits for the reminder lock', () async {
    final fixture = _Fixture();
    final entered = Completer<void>();
    final release = Completer<void>();
    final held = KeyedMutationCoordinator.shared.runExclusive<void>(
      AccountDataRegistry.notificationMutationKeyForScope(_scope),
      () async {
        entered.complete();
        await release.future;
      },
    );
    await entered.future;
    final sync = fixture.service.syncGoalReminders([fixture.goal('trip')]);
    await pumpEventQueue();
    expect(fixture.scheduler.registered, isEmpty);
    release.complete();
    await Future.wait(<Future<void>>[held, sync]);
    expect(fixture.scheduler.registered, contains('goal_reminder_trip_3d'));
  });
}

class _Fixture {
  _Fixture() {
    // Past the one-time move off the old shared 8 PM rhythm reminder.
    preferences.values['legacy_habit_reminder_migrated'] = 'true';
  }

  DateTime now = DateTime(2026, 11, 1, 10);
  String zone = 'America/Chicago';
  final preferences = _Preferences();
  final scheduler = _Scheduler();
  late final service = ReminderOrchestratorService(
    preferences: preferences,
    notifications: NotificationsService(_Repository()),
    scheduler: scheduler,
    accountScope: _scope,
    loadHabitOccurrences: () async => [],
    loadGoalTasks: () async => [],
    now: () => now,
    timeZoneName: () => zone,
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
  final Map<String, (int, int)> cadenceTimes = <String, (int, int)>{};
  String? throwOn;

  void clearLog() {
    registered.clear();
    cancelled.clear();
  }

  bool _register(String id, String? accountScope) {
    expect(accountScope, _scope);
    if (id == throwOn) throw StateError('Fixture OS registration failed');
    registered.add(id);
    pending.add(id);
    return true;
  }

  @override
  Future<bool> schedule(
    NotificationEntity notification, {
    String? accountScope,
  }) async => _register(notification.id, accountScope);

  @override
  Future<bool> scheduleDailyAt({
    required String id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    String? accountScope,
  }) async => _register(id, accountScope);

  @override
  Future<bool> scheduleCadenceAt({
    required String id,
    required String title,
    required String body,
    required HabitCadence cadence,
    required DateTime firstAt,
    String? accountScope,
  }) async {
    final ok = _register(id, accountScope);
    cadenceTimes[id] = (firstAt.hour, firstAt.minute);
    return ok;
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
      throw StateError('Reconcile must not prompt for permission');

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
