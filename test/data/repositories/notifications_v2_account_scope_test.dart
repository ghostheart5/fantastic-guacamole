import 'dart:convert';

import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/repositories/notifications_repository.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/domain/entities/notification_entity.dart';
import 'package:fantastic_guacamole/system/notifications/notification_scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'notification entries are isolated by scope and never hydrate V1',
    () async {
      final InMemorySecureStoreBackend backend = InMemorySecureStoreBackend();
      final SecureStore store = SecureStore(backend: backend);
      const String legacyKey = NotificationsRepository.legacyStorageKey;
      await store.writeString(
        legacyKey,
        jsonEncode(<Map<String, Object>>[
          <String, Object>{
            'id': 'shared',
            'title': 'LEGACY_SECRET_GOAL',
            'message': 'LEGACY_SECRET_ACTION',
            'scheduledAt': DateTime.utc(2026).toIso8601String(),
            'isEnabled': true,
            'isRead': false,
          },
        ]),
      );

      final NotificationsRepository a = _repository(store, 'account-a');
      final NotificationsRepository b = _repository(store, 'account-b');
      final NotificationEntity aEntry = _entry('A_SECRET_GOAL_NOTIFICATION');
      final NotificationEntity bEntry = _entry('B_SECRET_GOAL_NOTIFICATION');

      await a.scheduleNotification(aEntry);
      expect((await a.getNotifications()).single.title, aEntry.title);
      expect(await b.getNotifications(), isEmpty);

      await b.scheduleNotification(bEntry);
      expect((await b.getNotifications()).single.title, bEntry.title);
      expect((await a.getNotifications()).single.title, aEntry.title);
      expect(await store.readString(legacyKey), contains('LEGACY_SECRET_GOAL'));
    },
  );

  test('signed-out notification persistence fails closed', () async {
    final NotificationsRepository repository = NotificationsRepository(
      NotificationScheduler(),
      SecureStore(backend: InMemorySecureStoreBackend()),
      storageScope: const AccountStorageScope.signedOut(),
    );
    expect(repository.getNotifications(), throwsStateError);
  });
}

NotificationsRepository _repository(SecureStore store, String userId) {
  return NotificationsRepository(
    NotificationScheduler(),
    store,
    storageScope: AccountStorageScope.authenticated(userId),
  );
}

NotificationEntity _entry(String title) => NotificationEntity(
  id: 'shared-notification-id',
  title: title,
  message: '$title action/source=private',
  scheduledAt: DateTime.utc(2026, 1, 1),
);
