import 'package:fantastic_guacamole/data/services/local_user_data_cleanup_service.dart';
import 'package:fantastic_guacamole/data/storage/hive_service.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/system/notifications/notification_scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('real scheduler delegates account-removal cancellation to its injected platform client', () async {
    final calls = <String>[];
    final scheduler = NotificationScheduler.withAccountRemovalCancelAll(() async {
      calls.add('cancelAll');
    });

    await scheduler.cancelAllForAccountRemoval();

    expect(calls, <String>['cancelAll']);
  });

  test('real scheduler preserves an injected cancellation failure', () async {
    final scheduler = NotificationScheduler.withAccountRemovalCancelAll(() async {
      throw StateError('planned cancellation failure');
    });

    await expectLater(
      scheduler.cancelAllForAccountRemoval(),
      throwsA(isA<StateError>()),
    );
  });

  test('real sign-out cleanup reports a scheduler cancellation failure', () async {
    final scheduler = NotificationScheduler.withAccountRemovalCancelAll(() async {
      throw StateError('planned cancellation failure');
    });
    final cleanup = LocalUserDataCleanupService(
      preferences: const SharedPrefsStoreAdapter(),
      hive: const HiveStoreAdapter(),
      secureStore: SecureStore(backend: InMemorySecureStoreBackend()),
      cancelNotifications: scheduler.cancelAllForAccountRemoval,
      deleteFirebaseMessagingToken: () async {},
      disassociateFirebaseMessagingToken: () async {},
      clearNotificationRoutingState: () async {},
    );

    await expectLater(
      cleanup.prepareForSignOut(),
      throwsA(
        isA<LocalUserDataCleanupException>().having(
          (error) => error.failedSteps,
          'failed steps',
          <String>['scheduled notifications'],
        ),
      ),
    );
  });
}
