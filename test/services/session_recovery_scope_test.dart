import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/state/services/session_recovery_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() async {
    await SharedPrefsService.init();
    await SharedPrefsService.clear();
  });

  test(
    'recovery state is isolated by authenticated V2 account scope',
    () async {
      final SessionRecoveryService userA = SessionRecoveryService(
        storageScope: AccountStorageScope.authenticated('user_a'),
      );
      final SessionRecoveryService userB = SessionRecoveryService(
        storageScope: AccountStorageScope.authenticated('user_b'),
      );

      await userA.saveState(lastRoute: '/a', activeTaskId: 'task-a');

      expect((await userA.loadState())?.lastRoute, '/a');
      expect(await userB.loadState(), isNull);

      await userB.saveState(lastRoute: '/b');
      expect((await userA.loadState())?.lastRoute, '/a');
      expect((await userB.loadState())?.lastRoute, '/b');
    },
  );

  test(
    'signed-out scope is fail-closed and preserves legacy artifacts',
    () async {
      await SharedPrefsService.save(
        'rec_draft_title.signed_out',
        'legacy-draft',
      );
      final SessionRecoveryService signedOut = SessionRecoveryService(
        storageScope: const AccountStorageScope.signedOut(),
      );
      await signedOut.saveState(draftTaskTitle: 'draft');

      final SessionRecoveryService recreated = SessionRecoveryService(
        storageScope: const AccountStorageScope.signedOut(),
      );
      final SessionRecoveryService userA = SessionRecoveryService(
        storageScope: AccountStorageScope.authenticated('user_a'),
      );

      expect(await recreated.loadState(), isNull);
      expect(await userA.loadState(), isNull);
      expect(
        SharedPrefsService.load('rec_draft_title.signed_out'),
        'legacy-draft',
      );
    },
  );
}
