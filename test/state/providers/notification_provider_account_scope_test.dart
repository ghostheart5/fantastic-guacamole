import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/di/storage_providers.dart';
import 'package:fantastic_guacamole/data/di/repositories_providers.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/domain/entities/notification_entity.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/notification_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'notificationProvider recreates its scoped projection from A to B to A',
    () async {
      AccountStorageScope scope = AccountStorageScope.authenticated('A');
      final ProviderContainer container = ProviderContainer(
        overrides: [
          accountStorageScopeProvider.overrideWith((Ref ref) => scope),
          secureStoreProvider.overrideWithValue(
            SecureStore(backend: InMemorySecureStoreBackend()),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.listen(notificationProvider, (_, _) {});
      await _settle();

      await container
          .read(notificationProvider.notifier)
          .push(_entry('A_SECRET_GOAL_NOTIFICATION'), playSound: false);
      await container
          .read(notificationProvider.notifier)
          .pushDecision(
            'A_PRIVATE_TASK_SOURCE_ID A_ACTION_PAYLOAD A_DECISION_METADATA',
            refreshCoach: false,
            refreshPlan: false,
          );
      expect(_titles(container), contains('A_SECRET_GOAL_NOTIFICATION'));
      expect(_titles(container), contains('Decision Alert'));

      scope = AccountStorageScope.authenticated('B');
      container.invalidate(accountStorageScopeProvider);
      container.invalidate(notificationProvider);
      await _settle();
      expect(_titles(container), isNot(contains('A_SECRET_GOAL_NOTIFICATION')));
      expect(
        container
            .read(notificationProvider)
            .any(
              (NotificationEntity entry) =>
                  entry.message.contains('A_PRIVATE_TASK_SOURCE_ID') ||
                  entry.message.contains('A_ACTION_PAYLOAD') ||
                  entry.message.contains('A_DECISION_METADATA'),
            ),
        isFalse,
      );
      await container
          .read(notificationProvider.notifier)
          .push(_entry('B_SECRET_ACTION_NOTIFICATION'), playSound: false);
      expect(_titles(container), contains('B_SECRET_ACTION_NOTIFICATION'));

      scope = AccountStorageScope.authenticated('A');
      container.invalidate(accountStorageScopeProvider);
      container.invalidate(notificationProvider);
      await _settle();
      expect(
        (await container
                .read(notificationsRepositoryProvider)
                .getNotifications())
            .map((NotificationEntity entry) => entry.title),
        contains('A_SECRET_GOAL_NOTIFICATION'),
      );
      expect(
        (await container
                .read(notificationsRepositoryProvider)
                .getNotifications())
            .map((NotificationEntity entry) => entry.title),
        isNot(contains('B_SECRET_ACTION_NOTIFICATION')),
      );
      expect(
        (await container
                .read(domainNotificationRepositoryProvider)
                .getNotifications())
            .map((NotificationEntity entry) => entry.title),
        contains('A_SECRET_GOAL_NOTIFICATION'),
      );
      expect(_titles(container), contains('A_SECRET_GOAL_NOTIFICATION'));
      expect(
        _titles(container),
        isNot(contains('B_SECRET_ACTION_NOTIFICATION')),
      );
    },
  );

  test(
    'signed-out projection is empty and B does not hydrate A entries',
    () async {
      AccountStorageScope scope = AccountStorageScope.authenticated('A');
      final ProviderContainer container = ProviderContainer(
        overrides: [
          accountStorageScopeProvider.overrideWith((Ref ref) => scope),
          secureStoreProvider.overrideWithValue(
            SecureStore(backend: InMemorySecureStoreBackend()),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.listen(notificationProvider, (_, _) {});
      await _settle();
      await container
          .read(notificationProvider.notifier)
          .push(_entry('A_SECRET_NOTIFICATION'), playSound: false);
      scope = const AccountStorageScope.signedOut();
      container.invalidate(accountStorageScopeProvider);
      container.invalidate(notificationProvider);
      await _settle();
      expect(_titles(container), isEmpty);
      scope = AccountStorageScope.authenticated('B');
      container.invalidate(accountStorageScopeProvider);
      container.invalidate(notificationProvider);
      await _settle();
      expect(_titles(container), isNot(contains('A_SECRET_NOTIFICATION')));
      await container
          .read(notificationProvider.notifier)
          .push(_entry('B_SECRET_NOTIFICATION'), playSound: false);
      expect(_titles(container), contains('B_SECRET_NOTIFICATION'));
    },
  );
}

Future<void> _settle() async {
  // NotificationNotifier uses an intentionally deferred repository load.
  // Four event-loop turns cover provider dependency invalidation plus the
  // repository read without using wall-clock sleep.
  for (int turn = 0; turn < 4; turn++) {
    await Future<void>.delayed(Duration.zero);
  }
}

List<String> _titles(ProviderContainer c) => c
    .read(notificationProvider)
    .map((NotificationEntity e) => e.title)
    .toList();
NotificationEntity _entry(String title) => NotificationEntity(
  id: title,
  title: title,
  message: '$title source=private action=private',
  scheduledAt: DateTime.utc(2027),
);
