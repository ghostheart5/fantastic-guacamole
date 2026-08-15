import 'dart:async';
import 'dart:convert';

import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/notification_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_notification_repository.dart';
import 'package:fantastic_guacamole/state/services/notifications_service.dart';
import 'package:fantastic_guacamole/state/services/reflection_reminder_service.dart';
import 'package:fantastic_guacamole/state/services/reminder_orchestrator_service.dart';
import 'package:fantastic_guacamole/system/notifications/notification_scheduler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Reflection preferences are isolated between account A and account B', () async {
    final prefs = _Prefs();
    final a = AccountStorageScope.authenticated('A');
    final b = AccountStorageScope.authenticated('B');
    final aService = _reflection(prefs, a);
    await aService.setTime(time: const TimeOfDay(hour: 9, minute: 17));
    expect(prefs.values['reflection_reminder_time_v2.${a.v2Namespace}'], '9:17');

    final bService = _reflection(prefs, b);
    expect(bService.loadPrefs().time, const TimeOfDay(hour: 20, minute: 0));
    await bService.setTime(time: const TimeOfDay(hour: 21, minute: 43));
    expect(prefs.values['reflection_reminder_time_v2.${b.v2Namespace}'], '21:43');

    final restoredA = _reflection(prefs, a).loadPrefs();
    expect(restoredA.time, const TimeOfDay(hour: 9, minute: 17));
    expect(restoredA.time, isNot(const TimeOfDay(hour: 21, minute: 43)));
  });

  test('Reflection ignores legacy global preferences', () async {
    final prefs = _Prefs()
      ..values[ReflectionReminderService.enabledKey] = 'true'
      ..values[ReflectionReminderService.timeKey] = '6:41';
    final a = AccountStorageScope.authenticated('A');
    final b = AccountStorageScope.authenticated('B');

    for (final scope in <AccountStorageScope>[a, b, a]) {
      final prefsForScope = _reflection(prefs, scope).loadPrefs();
      expect(prefsForScope.enabled, isFalse);
      expect(prefsForScope.time, const TimeOfDay(hour: 20, minute: 0));
    }

    expect(prefs.values[ReflectionReminderService.enabledKey], 'true');
    expect(prefs.values[ReflectionReminderService.timeKey], '6:41');
    expect(prefs.values.containsKey('reflection_reminder_enabled_v2.${a.v2Namespace}'), isFalse);
    expect(prefs.values.containsKey('reflection_reminder_time_v2.${a.v2Namespace}'), isFalse);
    expect(prefs.values.containsKey('reflection_reminder_enabled_v2.${b.v2Namespace}'), isFalse);
    expect(prefs.values.containsKey('reflection_reminder_time_v2.${b.v2Namespace}'), isFalse);
  });

  test('Reflection platform ID is deterministic and account scoped', () async {
    final prefs = _Prefs();
    final a = AccountStorageScope.authenticated('A');
    final b = AccountStorageScope.authenticated('B');

    await _reflection(prefs, a).setTime(time: const TimeOfDay(hour: 8, minute: 0));
    await _reflection(prefs, b).setTime(time: const TimeOfDay(hour: 8, minute: 0));

    final aId = _registeredIds(prefs, a).single;
    final bId = _registeredIds(prefs, b).single;
    expect(aId, isNot(bId));
    expect(aId, isNot(ReflectionReminderService.notificationId));
    expect(bId, isNot(ReflectionReminderService.notificationId));

    await _reflection(prefs, a).setTime(time: const TimeOfDay(hour: 9, minute: 0));
    expect(_registeredIds(prefs, a), <String>[aId]);
  });

  test('Reflection scheduling registers only the owning account ID', () async {
    final prefs = _Prefs();
    final a = AccountStorageScope.authenticated('A');
    final b = AccountStorageScope.authenticated('B');
    final scheduler = _ScheduleSpy();

    await _reflection(prefs, a, scheduler: scheduler)
        .setTime(time: const TimeOfDay(hour: 7, minute: 30));

    final aIds = _registeredIds(prefs, a);
    expect(aIds, hasLength(1));
    expect(aIds.single, 'reminder.reflection.${a.v2Namespace}.default');
    expect(_registeredIds(prefs, b), isEmpty);
    expect(aIds, isNot(contains(ReflectionReminderService.notificationId)));
    expect(scheduler.ids, <String>[aIds.single]);
  });

  test('A outgoing cancellation removes only A Reflection schedule', () async {
    final prefs = _Prefs();
    final repo = _Repo();
    final a = AccountStorageScope.authenticated('A');
    final b = AccountStorageScope.authenticated('B');
    final service = _reflection(prefs, a, repo: repo, scheduler: _ScheduleSpy());
    await service.setTime(time: const TimeOfDay(hour: 8, minute: 0));
    final id = _registeredIds(prefs, a).single;

    await service.registry.cancelAndDrain();
    await service.registry.cancelScheduledRemindersForAccount(a);

    expect(repo.cancelled, <String>[id]);
    expect(_registeredIds(prefs, a), isEmpty);
    expect(_registeredIds(prefs, b), isEmpty);
  });

  test('Reflection cancellation failure retains A registry evidence', () async {
    final prefs = _Prefs();
    final repo = _Repo()..fail = true;
    final a = AccountStorageScope.authenticated('A');
    final b = AccountStorageScope.authenticated('B');
    final service = _reflection(prefs, a, repo: repo, scheduler: _ScheduleSpy());
    await service.setTime(time: const TimeOfDay(hour: 8, minute: 0));
    final id = _registeredIds(prefs, a).single;

    await expectLater(service.registry.cancelScheduledRemindersForAccount(a), throwsStateError);

    expect(_registeredIds(prefs, a), <String>[id]);
    expect(_registeredIds(prefs, b), isEmpty);
  });

  test('Reflection cancellation retry clears the original A registry entry', () async {
    final prefs = _Prefs();
    final repo = _Repo()..fail = true;
    final a = AccountStorageScope.authenticated('A');
    final service = _reflection(prefs, a, repo: repo, scheduler: _ScheduleSpy());
    await service.setTime(time: const TimeOfDay(hour: 8, minute: 0));
    final id = _registeredIds(prefs, a).single;
    await expectLater(service.registry.cancelScheduledRemindersForAccount(a), throwsStateError);

    repo.fail = false;
    await service.registry.cancelScheduledRemindersForAccount(a);

    expect(repo.cancelled, <String>[id, id]);
    expect(_registeredIds(prefs, a), isEmpty);
  });

  test('Reflection schedule failure does not register an active schedule', () async {
    final prefs = _Prefs();
    final a = AccountStorageScope.authenticated('A');
    final b = AccountStorageScope.authenticated('B');
    final scheduler = _ScheduleSpy(result: NotificationScheduleResult.skippedPermissionDenied);

    await _reflection(prefs, a, scheduler: scheduler)
        .setTime(time: const TimeOfDay(hour: 8, minute: 0));

    expect(_registeredIds(prefs, a), isEmpty);
    expect(_registeredIds(prefs, b), isEmpty);
    expect(prefs.values['reflection_reminder_time_v2.${a.v2Namespace}'], '8:0');
  });

  test('Reflection schedule survives recreation and can be cancelled', () async {
    final prefs = _Prefs();
    final repo = _Repo();
    final a = AccountStorageScope.authenticated('A');
    await _reflection(prefs, a, repo: repo, scheduler: _ScheduleSpy())
        .setTime(time: const TimeOfDay(hour: 9, minute: 5));
    final id = _registeredIds(prefs, a).single;

    final recreated = _reflection(prefs, a, repo: repo, scheduler: _ScheduleSpy());
    expect(recreated.loadPrefs().time, const TimeOfDay(hour: 9, minute: 5));
    expect(_registeredIds(prefs, a), <String>[id]);
    await recreated.registry.cancelRegisteredReminder(scope: a, id: id);
    expect(_registeredIds(prefs, a), isEmpty);
  });

  test('rapid A to B to C cannot register a stale A Reflection schedule', () async {
    final prefs = _Prefs();
    final repo = _Repo();
    final a = AccountStorageScope.authenticated('A');
    final c = AccountStorageScope.authenticated('C');
    final delayed = _ScheduleSpy(holdNext: true);
    final aService = _reflection(prefs, a, repo: repo, scheduler: delayed);
    final aSchedule = aService.setTime(time: const TimeOfDay(hour: 8, minute: 0));
    await delayed.started.future;

    await aService.registry.cancelAndDrain();
    await aService.registry.cancelScheduledRemindersForAccount(a);
    await _reflection(prefs, c, repo: repo, scheduler: _ScheduleSpy())
        .setTime(time: const TimeOfDay(hour: 10, minute: 0));
    delayed.release(NotificationScheduleResult.scheduled);
    await aSchedule;

    expect(_registeredIds(prefs, a), isEmpty);
    expect(_registeredIds(prefs, c), <String>['reminder.reflection.${c.v2Namespace}.default']);
  });

  test('same-user Reflection refresh retains one schedule and preferences', () async {
    final prefs = _Prefs();
    final repo = _Repo();
    final a = AccountStorageScope.authenticated('A');
    final service = _reflection(prefs, a, repo: repo, scheduler: _ScheduleSpy());
    await service.setTime(time: const TimeOfDay(hour: 11, minute: 0));
    await _reflection(prefs, a, repo: repo, scheduler: _ScheduleSpy())
        .setTime(time: const TimeOfDay(hour: 11, minute: 0));

    expect(_registeredIds(prefs, a), hasLength(1));
    expect(repo.cancelled, isEmpty);
    expect(_reflection(prefs, a).loadPrefs().time, const TimeOfDay(hour: 11, minute: 0));
  });

  test('Reflection platform cleanup preserves A preference truth', () async {
    final prefs = _Prefs();
    final repo = _Repo();
    final a = AccountStorageScope.authenticated('A');
    final service = _reflection(prefs, a, repo: repo, scheduler: _ScheduleSpy());
    await service.setTime(time: const TimeOfDay(hour: 12, minute: 34));
    await service.registry.cancelAndDrain();
    await service.registry.cancelScheduledRemindersForAccount(a);

    expect(_reflection(prefs, a).loadPrefs().time, const TimeOfDay(hour: 12, minute: 34));
    expect(prefs.values['reflection_reminder_time_v2.${a.v2Namespace}'], '12:34');
  });
}

List<String> _registeredIds(_Prefs prefs, AccountStorageScope scope) {
  final raw = prefs.values['reminder_schedule_registry_v2.${scope.v2Namespace}'];
  if (raw == null) return <String>[];
  return (jsonDecode(raw) as List<dynamic>).cast<String>();
}

ReflectionReminderService _reflection(
  _Prefs prefs,
  AccountStorageScope scope, {
  _Repo? repo,
  _ScheduleSpy? scheduler,
}) {
  final notificationRepository = repo ?? _Repo();
  final scheduleSpy = scheduler ?? _ScheduleSpy();
  final registry = ReminderOrchestratorService(
    preferences: prefs,
    notifications: NotificationsService(notificationRepository),
    scheduler: NotificationScheduler(),
    storageScope: scope,
  );
  return ReflectionReminderService(
    preferences: prefs,
    scheduler: NotificationScheduler(),
    storageScope: scope,
    registry: registry,
    scheduleDailyAt: scheduleSpy.schedule,
  );
}

class _Prefs implements SharedPrefsStore {
  final Map<String, String> values = <String, String>{};
  @override Future<void> clear() async => values.clear();
  @override Future<void> delete(String key) async => values.remove(key);
  @override Future<void> init() async {}
  @override String? load(String key) => values[key];
  @override Future<void> save(String key, String value) async => values[key] = value;
}

class _Repo implements INotificationRepository {
  bool fail = false;
  final List<String> cancelled = <String>[];
  @override
  Future<void> cancelNotification(String id) async {
    cancelled.add(id);
    if (fail) throw StateError('cancel $id');
  }
  @override Future<void> delete(String id) async {}
  @override Future<List<NotificationEntity>> getNotifications() async => <NotificationEntity>[];
  @override Future<void> markRead(String id) async {}
  @override Future<void> scheduleNotification(NotificationEntity notification) async {}
}

class _ScheduleSpy {
  _ScheduleSpy({
    this.result = NotificationScheduleResult.scheduled,
    this.holdNext = false,
  });

  final NotificationScheduleResult result;
  final bool holdNext;
  final List<String> ids = <String>[];
  final Completer<void> started = Completer<void>();
  Completer<NotificationScheduleResult>? _pending;

  Future<NotificationScheduleResult> schedule(
    String id,
    String title,
    String body,
    int hour,
    int minute,
  ) {
    ids.add(id);
    if (!holdNext) return Future<NotificationScheduleResult>.value(result);
    started.complete();
    return (_pending ??= Completer<NotificationScheduleResult>()).future;
  }

  void release(NotificationScheduleResult value) {
    _pending!.complete(value);
  }
}
