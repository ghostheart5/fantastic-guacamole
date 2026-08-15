import 'dart:convert';

import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/repositories/notifications_repository.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/notification_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_notification_repository.dart';
import 'package:fantastic_guacamole/state/services/notifications_service.dart';
import 'package:fantastic_guacamole/state/services/reminder_orchestrator_service.dart';
import 'package:fantastic_guacamole/system/notifications/notification_scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('scheduling result success preserves ledger and permits registry ownership',
      () async {
    final scope = AccountStorageScope.authenticated('A');
    final prefs = _Prefs();
    final repository = NotificationsRepository(
      NotificationScheduler(),
      SecureStore(backend: InMemorySecureStoreBackend()),
      storageScope: scope,
      platformScheduleNotification: (_) async {},
    );
    final service = NotificationsService(repository);
    final registry = _registry(prefs, scope);

    final result = await service.scheduleWithResult(
      id: 'reminder.profile.${scope.v2Namespace}.2026-08-14',
      title: 'A',
      body: 'A',
      at: DateTime.utc(2026, 8, 14),
    );
    if (result == NotificationScheduleResult.scheduled) {
      await registry.registerScheduledReminder(
        scope: scope,
        id: 'reminder.profile.${scope.v2Namespace}.2026-08-14',
      );
    }

    expect(result, NotificationScheduleResult.scheduled);
    expect((await repository.getNotifications()).single.title, 'A');
    expect(_registered(prefs, scope), <String>[
      'reminder.profile.${scope.v2Namespace}.2026-08-14',
    ]);
  });

  test('scheduling failure remains observable and cannot register ownership',
      () async {
    final scope = AccountStorageScope.authenticated('A');
    final prefs = _Prefs();
    final repository = NotificationsRepository(
      NotificationScheduler(),
      SecureStore(backend: InMemorySecureStoreBackend()),
      storageScope: scope,
      platformScheduleNotification: (_) async => throw StateError('platform failure'),
    );
    final service = NotificationsService(repository);

    await expectLater(
      service.scheduleWithResult(
        id: 'reminder.profile.${scope.v2Namespace}.failed',
        title: 'failed',
        body: 'failed',
        at: DateTime.utc(2026, 8, 14),
      ),
      throwsStateError,
    );

    expect((await repository.getNotifications()).single.title, 'failed');
    expect(_registered(prefs, scope), isEmpty);
  });
}

ReminderOrchestratorService _registry(_Prefs prefs, AccountStorageScope scope) {
  return ReminderOrchestratorService(
    preferences: prefs,
    notifications: NotificationsService(_NoopRepository()),
    scheduler: NotificationScheduler(),
    storageScope: scope,
  );
}

List<String> _registered(_Prefs prefs, AccountStorageScope scope) {
  return (jsonDecode(
    prefs.values['reminder_schedule_registry_v2.${scope.v2Namespace}'] ?? '[]',
  ) as List<dynamic>).cast<String>();
}

class _Prefs implements SharedPrefsStore {
  final Map<String, String> values = <String, String>{};
  @override Future<void> clear() async => values.clear();
  @override Future<void> delete(String key) async => values.remove(key);
  @override Future<void> init() async {}
  @override String? load(String key) => values[key];
  @override Future<void> save(String key, String value) async => values[key] = value;
}

class _NoopRepository implements INotificationRepository {
  @override Future<void> cancelNotification(String id) async {}
  @override Future<void> delete(String id) async {}
  @override Future<List<NotificationEntity>> getNotifications() async => <NotificationEntity>[];
  @override Future<void> markRead(String id) async {}
  @override Future<void> scheduleNotification(NotificationEntity notification) async {}
}
