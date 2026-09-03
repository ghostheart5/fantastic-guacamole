import 'package:fantastic_guacamole/core/storage/account_storage_namespace.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/local/shared_prefs_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'typed preferences isolate accounts and preserve legacy on delete',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'cloud_sync_enabled_v1': true,
      });
      final SharedPreferences raw = await SharedPreferences.getInstance();
      final SharedPrefsStorage root = SharedPrefsStorage(raw);
      final AccountScopedSharedPrefsStorage accountA =
          AccountScopedSharedPrefsStorage(
            delegate: root,
            scope: AccountStorageScope.authenticated('account-a'),
            legacyOwnership: LegacyScopeOwnership.provenOwned,
          );
      final AccountScopedSharedPrefsStorage accountB =
          AccountScopedSharedPrefsStorage(
            delegate: root,
            scope: AccountStorageScope.authenticated('account-b'),
          );

      expect(accountA.getBool('cloud_sync_enabled_v1'), isTrue);
      expect(accountB.getBool('cloud_sync_enabled_v1'), isNull);
      await accountA.setBool('cloud_sync_enabled_v1', false);
      await accountB.setBool('cloud_sync_enabled_v1', true);
      expect(accountA.getBool('cloud_sync_enabled_v1'), isFalse);
      expect(accountB.getBool('cloud_sync_enabled_v1'), isTrue);

      await accountA.remove('cloud_sync_enabled_v1');
      expect(accountA.getBool('cloud_sync_enabled_v1'), isNull);
      expect(accountB.getBool('cloud_sync_enabled_v1'), isTrue);
      expect(root.getBool('cloud_sync_enabled_v1'), isTrue);
    },
  );

  test('typed clear suppresses legacy and preserves another account', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'reflection_reminder_time': '20:00',
    });
    final SharedPrefsStorage root = SharedPrefsStorage(
      await SharedPreferences.getInstance(),
    );
    final AccountScopedSharedPrefsStorage accountA =
        AccountScopedSharedPrefsStorage(
          delegate: root,
          scope: AccountStorageScope.authenticated('account-a'),
          legacyOwnership: LegacyScopeOwnership.provenOwned,
        );
    final AccountScopedSharedPrefsStorage accountB =
        AccountScopedSharedPrefsStorage(
          delegate: root,
          scope: AccountStorageScope.authenticated('account-b'),
        );
    await accountA.setString('local_test_cloud_backup', 'private-a');
    await accountB.setString('local_test_cloud_backup', 'private-b');

    await accountA.clear();

    expect(accountA.getString('reflection_reminder_time'), isNull);
    expect(accountA.getString('local_test_cloud_backup'), isNull);
    expect(accountB.getString('local_test_cloud_backup'), 'private-b');
    expect(root.getString('reflection_reminder_time'), '20:00');
  });

  test('typed preferences fail closed when signed out', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final AccountScopedSharedPrefsStorage signedOut =
        AccountScopedSharedPrefsStorage(
          delegate: SharedPrefsStorage(await SharedPreferences.getInstance()),
          scope: const AccountStorageScope.signedOut(),
        );

    expect(
      () => signedOut.getString('local_test_cloud_backup'),
      throwsStateError,
    );
    await expectLater(
      signedOut.setString('local_test_cloud_backup', 'blocked'),
      throwsStateError,
    );
  });
}
