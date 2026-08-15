import '../../helpers/controllable_secure_store_backend.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/repositories/notifications_repository.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/domain/entities/notification_entity.dart';
import 'package:fantastic_guacamole/system/notifications/notification_scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'scoped read/write failure, retry, and cancellation preserve other scopes and V1',
    () async {
      final ControllableSecureStoreBackend backend =
          ControllableSecureStoreBackend();
      final SecureStore store = SecureStore(backend: backend);
      final AccountStorageScope aScope = AccountStorageScope.authenticated('A');
      final AccountStorageScope bScope = AccountStorageScope.authenticated('B');
      final NotificationsRepository a = _repo(store, aScope);
      final NotificationsRepository b = _repo(store, bScope);
      const String legacy = NotificationsRepository.legacyStorageKey;
      await store.writeString(legacy, '["LEGACY_PRIVATE_NOTIFICATION"]');
      await a.scheduleNotification(_entry('shared', 'A_EXISTING'));
      await b.scheduleNotification(_entry('shared', 'B_EXISTING'));
      final String bKey = NotificationsRepository.canonicalStorageKeyForScope(
        bScope,
      );
      backend.failingReads.add(bKey);
      await expectLater(b.getNotifications(), throwsStateError);
      backend.failingReads.remove(bKey);
      backend.failingWrites.add(bKey);
      await expectLater(
        b.scheduleNotification(_entry('failed', 'B_FAILED_NOTIFICATION')),
        throwsStateError,
      );
      expect(
        (await b.getNotifications()).map((e) => e.title),
        contains('B_EXISTING'),
      );
      expect((await a.getNotifications()).single.title, 'A_EXISTING');
      expect(await store.readString(legacy), '["LEGACY_PRIVATE_NOTIFICATION"]');
      backend.failingWrites.remove(bKey);
      await b.scheduleNotification(_entry('failed', 'B_FAILED_NOTIFICATION'));
      await b.cancelNotification('shared');
      expect(
        (await b.getNotifications())
            .firstWhere((e) => e.id == 'shared')
            .isEnabled,
        isFalse,
      );
      expect((await a.getNotifications()).single.isEnabled, isTrue);
      expect(await store.readString(legacy), '["LEGACY_PRIVATE_NOTIFICATION"]');
    },
  );
}

NotificationsRepository _repo(SecureStore store, AccountStorageScope scope) =>
    NotificationsRepository(
      NotificationScheduler(),
      store,
      storageScope: scope,
    );
NotificationEntity _entry(String id, String title) => NotificationEntity(
  id: id,
  title: title,
  message: title,
  scheduledAt: DateTime.utc(2027),
);
