import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/di/storage_providers.dart';
import 'package:fantastic_guacamole/data/repositories/notifications_repository.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/notification_provider.dart';
import 'package:fantastic_guacamole/state/services/notifications_service.dart';
import 'package:fantastic_guacamole/state/services/reminder_orchestrator_service.dart';
import 'package:fantastic_guacamole/system/notifications/notification_scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'real Goal reminder persists only in the current account notification ledger',
    () async {
      final SecureStore store = SecureStore(
        backend: InMemorySecureStoreBackend(),
      );
      final AccountStorageScope a = AccountStorageScope.authenticated('A');
      final AccountStorageScope b = AccountStorageScope.authenticated('B');
      const String legacy = NotificationsRepository.legacyStorageKey;
      await store.writeString(legacy, 'LEGACY_PRIVATE_NOTIFICATION');
      final NotificationsRepository aRepository = _repository(store, a);
      final ReminderOrchestratorService service = ReminderOrchestratorService(
        preferences: _Prefs(),
        notifications: NotificationsService(aRepository),
        scheduler: NotificationScheduler(),
        storageScope: a,
      );
      await service.syncGoalReminders(<GoalEntity>[
        GoalEntity(
          id: 'goal-a',
          title: 'A_SECRET_GOAL',
          createdAt: DateTime.utc(2026),
          targetDate: DateTime.now().add(const Duration(days: 2)),
        ),
      ]);
      expect(
        (await aRepository.getNotifications()).single.message,
        contains('A_SECRET_GOAL'),
      );
      AccountStorageScope scope = a;
      final ProviderContainer c = ProviderContainer(
        overrides: [
          accountStorageScopeProvider.overrideWith((Ref ref) => scope),
          secureStoreProvider.overrideWithValue(store),
        ],
      );
      addTearDown(c.dispose);
      c.listen(notificationProvider, (_, _) {});
      await _settle();
      expect(
        c.read(notificationProvider).single.message,
        contains('A_SECRET_GOAL'),
      );
      scope = b;
      c.invalidate(accountStorageScopeProvider);
      await _settle();
      expect(c.read(notificationProvider), isEmpty);
      expect(await _repository(store, b).getNotifications(), isEmpty);
      expect(await store.readString(legacy), 'LEGACY_PRIVATE_NOTIFICATION');
    },
  );
}

NotificationsRepository _repository(
  SecureStore store,
  AccountStorageScope scope,
) => NotificationsRepository(
  NotificationScheduler(),
  store,
  storageScope: scope,
);
Future<void> _settle() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

class _Prefs implements SharedPrefsStore {
  final Map<String, String> _v = <String, String>{};
  @override
  Future<void> clear() async => _v.clear();
  @override
  Future<void> delete(String k) async => _v.remove(k);
  @override
  Future<void> init() async {}
  @override
  String? load(String k) => _v[k];
  @override
  Future<void> save(String k, String v) async => _v[k] = v;
}
