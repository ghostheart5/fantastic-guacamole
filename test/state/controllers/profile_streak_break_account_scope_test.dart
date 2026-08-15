import 'dart:async';
import 'dart:convert';

import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/di/storage_providers.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/notification_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_notification_repository.dart';
import 'package:fantastic_guacamole/state/controllers/profile_controller.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/service_providers.dart';
import 'package:fantastic_guacamole/state/services/notifications_service.dart';
import 'package:fantastic_guacamole/state/services/reminder_orchestrator_service.dart';
import 'package:fantastic_guacamole/system/notifications/notification_scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _scopeProvider = NotifierProvider<_Scope, AccountStorageScope>(_Scope.new);

void main() {
  final day = DateTime.utc(2026, 8, 14);

  test('same-date Profile streak-break IDs are scoped and stable', () {
    final a = AccountStorageScope.authenticated('A');
    final b = AccountStorageScope.authenticated('B');
    expect(ProfileController.streakBreakNotificationIdForScope(a, day),
        isNot(ProfileController.streakBreakNotificationIdForScope(b, day)));
    expect(ProfileController.streakBreakNotificationIdForScope(a, day),
        ProfileController.streakBreakNotificationIdForScope(a, day));
  });

  test('successful Profile schedule registers only the current account', () async {
    final harness = _Harness();
    addTearDown(harness.dispose);
    final a = AccountStorageScope.authenticated('A');
    final b = AccountStorageScope.authenticated('B');
    await harness.setScope(a);
    final result = await harness.controller.scheduleStreakBreakNotification(now: day);
    final id = ProfileController.streakBreakNotificationIdForScope(a, day);
    expect(result, NotificationScheduleResult.scheduled);
    expect(harness.repository.scheduled, <String>[id]);
    expect(harness.ids(a), <String>[id]);
    expect(harness.ids(b), isEmpty);
  });

  test('Profile schedule failure is observable and creates no ownership', () async {
    final harness = _Harness()..repository.failSchedule = true;
    addTearDown(harness.dispose);
    final a = AccountStorageScope.authenticated('A');
    await harness.setScope(a);
    final before = harness.container.read(profileProvider);
    expect(await harness.controller.scheduleStreakBreakNotification(now: day), isNull);
    expect(harness.ids(a), isEmpty);
    expect(harness.container.read(profileProvider).name, before.name);
  });

  test('outgoing cancellation removes A only and retries after failure', () async {
    final harness = _Harness();
    addTearDown(harness.dispose);
    final a = AccountStorageScope.authenticated('A');
    final b = AccountStorageScope.authenticated('B');
    await harness.setScope(a);
    await harness.controller.scheduleStreakBreakNotification(now: day);
    final id = ProfileController.streakBreakNotificationIdForScope(a, day);
    final registry = harness.container.read(reminderOrchestratorServiceProvider);
    harness.repository.failCancel = true;
    await expectLater(registry.cancelScheduledRemindersForAccount(a), throwsStateError);
    expect(harness.ids(a), <String>[id]);
    await harness.setScope(b);
    expect(harness.ids(b), isEmpty);
    harness.repository.failCancel = false;
    await registry.cancelScheduledRemindersForAccount(a);
    expect(harness.repository.cancelled, <String>[id, id]);
    expect(harness.ids(a), isEmpty);
  });

  test('Profile schedule survives recreation without changing domain state', () async {
    final harness = _Harness();
    addTearDown(harness.dispose);
    final a = AccountStorageScope.authenticated('A');
    await harness.setScope(a);
    final before = harness.container.read(profileProvider);
    await harness.controller.scheduleStreakBreakNotification(now: day);
    final id = ProfileController.streakBreakNotificationIdForScope(a, day);
    harness.container.invalidate(profileProvider);
    harness.container.read(profileProvider);
    await _flush();
    expect(harness.ids(a), <String>[id]);
    expect(ProfileController.streakBreakNotificationIdForScope(a, day), id);
    expect(harness.container.read(profileProvider).name, before.name);
  });

  test('rapid A to B to C ignores a stale A schedule completion', () async {
    final harness = _Harness()..repository.holdNextSchedule = true;
    addTearDown(harness.dispose);
    final a = AccountStorageScope.authenticated('A');
    final c = AccountStorageScope.authenticated('C');
    await harness.setScope(a);
    final pending = harness.controller.scheduleStreakBreakNotification(now: day);
    await harness.repository.scheduleStarted.future;
    await harness.setScope(c);
    harness.repository.releaseSchedule();
    expect(await pending, NotificationScheduleResult.scheduled);
    expect(harness.ids(a), isEmpty);
    expect(harness.ids(c), isEmpty);
  });

  test('same-user refresh keeps one Profile streak-break schedule', () async {
    final harness = _Harness();
    addTearDown(harness.dispose);
    final a = AccountStorageScope.authenticated('A');
    await harness.setScope(a);
    await harness.controller.scheduleStreakBreakNotification(now: day);
    await harness.setScope(a);
    await harness.controller.scheduleStreakBreakNotification(now: day);
    expect(harness.ids(a), hasLength(1));
    expect(harness.repository.cancelled, isEmpty);
  });

  test('signed-out Profile cannot create streak-break ownership', () async {
    final harness = _Harness();
    addTearDown(harness.dispose);
    expect(await harness.controller.scheduleStreakBreakNotification(now: day), isNull);
    expect(harness.repository.scheduled, isEmpty);
  });
}

class _Harness {
  _Harness()
      : repository = _Repository(),
        prefs = _Prefs();

  final _Repository repository;
  final _Prefs prefs;
  late final ProviderContainer container = ProviderContainer(overrides: [
    secureStoreProvider.overrideWithValue(SecureStore(backend: InMemorySecureStoreBackend())),
    accountStorageScopeProvider.overrideWith((ref) => ref.watch(_scopeProvider)),
    notificationsServiceProvider.overrideWithValue(NotificationsService(repository)),
    reminderOrchestratorServiceProvider.overrideWith((ref) => ReminderOrchestratorService(
          preferences: prefs,
          notifications: ref.read(notificationsServiceProvider),
          scheduler: NotificationScheduler(),
          storageScope: ref.watch(accountStorageScopeProvider),
        )),
  ]);

  ProfileController get controller => container.read(profileProvider.notifier);
  Future<void> setScope(AccountStorageScope scope) async {
    container.read(_scopeProvider.notifier).set(scope);
    container.invalidate(profileProvider);
    container.read(profileProvider);
    await _flush();
  }
  List<String> ids(AccountStorageScope scope) =>
      (jsonDecode(prefs.values['reminder_schedule_registry_v2.${scope.v2Namespace}'] ?? '[]') as List).cast<String>();
  void dispose() => container.dispose();
}

class _Scope extends Notifier<AccountStorageScope> {
  @override AccountStorageScope build() => const AccountStorageScope.signedOut();
  void set(AccountStorageScope scope) => state = scope;
}

class _Prefs implements SharedPrefsStore {
  final Map<String, String> values = <String, String>{};
  @override Future<void> clear() async => values.clear();
  @override Future<void> delete(String key) async => values.remove(key);
  @override Future<void> init() async {}
  @override String? load(String key) => values[key];
  @override Future<void> save(String key, String value) async => values[key] = value;
}

class _Repository implements SchedulingResultNotificationRepository {
  bool failSchedule = false;
  bool failCancel = false;
  bool holdNextSchedule = false;
  final List<String> scheduled = <String>[];
  final List<String> cancelled = <String>[];
  final Completer<void> scheduleStarted = Completer<void>();
  Completer<void>? _gate;
  @override Future<void> cancelNotification(String id) async { cancelled.add(id); if (failCancel) throw StateError('cancel'); }
  @override Future<void> delete(String id) async {}
  @override Future<List<NotificationEntity>> getNotifications() async => <NotificationEntity>[];
  @override Future<void> markRead(String id) async {}
  @override Future<void> scheduleNotification(NotificationEntity notification) async {}
  @override Future<NotificationScheduleResult> scheduleNotificationWithResult(NotificationEntity notification) async {
    scheduled.add(notification.id);
    if (holdNextSchedule) { scheduleStarted.complete(); await (_gate ??= Completer<void>()).future; }
    if (failSchedule) throw StateError('schedule');
    return NotificationScheduleResult.scheduled;
  }
  void releaseSchedule() => _gate!.complete();
}

Future<void> _flush() async { await Future<void>.delayed(Duration.zero); await Future<void>.delayed(Duration.zero); }
