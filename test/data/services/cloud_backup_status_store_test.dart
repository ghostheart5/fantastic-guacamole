import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/local/shared_prefs_storage.dart';
import 'package:fantastic_guacamole/data/services/cloud_backup_status_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<SharedPrefsStorage> prefs() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    return SharedPrefsStorage(await SharedPreferences.getInstance());
  }

  AccountScopedSharedPrefsStorage scoped(
    SharedPrefsStorage prefs,
    String account,
  ) => AccountScopedSharedPrefsStorage(
    delegate: prefs,
    scope: AccountStorageScope.authenticated(account),
  );

  test('stores the revision and time per account', () async {
    final SharedPrefsStorage storage = await prefs();
    final CloudBackupStatusStore a = CloudBackupStatusStore(
      scoped(storage, 'account-a'),
    );
    final DateTime at = DateTime.utc(2026, 11, 20, 9, 30);

    await a.write(CloudBackupStatus(revision: 4, backedUpAt: at));

    expect(a.read()!.revision, 4);
    expect(a.read()!.backedUpAt, at);
    expect(CloudBackupStatusStore(scoped(storage, 'account-b')).read(), isNull);
  });

  test('a missing or unreadable record reads as no record', () async {
    final SharedPrefsStorage storage = await prefs();
    final AccountScopedSharedPrefsStorage accountPrefs = scoped(
      storage,
      'account-a',
    );
    final CloudBackupStatusStore store = CloudBackupStatusStore(accountPrefs);
    expect(store.read(), isNull);

    for (final String raw in <String>[
      'not json',
      '[]',
      '{"revision":"3"}',
      '{"revision":0}',
    ]) {
      await accountPrefs.setString(CloudBackupStatusStore.storageKey, raw);
      expect(store.read(), isNull, reason: raw);
    }

    await accountPrefs.setString(
      CloudBackupStatusStore.storageKey,
      '{"revision":2,"backedUpAt":"garbage"}',
    );
    expect(store.read()!.revision, 2);
    expect(store.read()!.backedUpAt, isNull);
  });

  test('clearing forgets only this account record', () async {
    final SharedPrefsStorage storage = await prefs();
    final CloudBackupStatusStore a = CloudBackupStatusStore(
      scoped(storage, 'account-a'),
    );
    final CloudBackupStatusStore b = CloudBackupStatusStore(
      scoped(storage, 'account-b'),
    );
    await a.write(const CloudBackupStatus(revision: 3));
    await b.write(const CloudBackupStatus(revision: 5));

    await a.clear();

    expect(a.read(), isNull);
    expect(b.read()!.revision, 5);
  });

  test('the recovery key confirmation is remembered per account', () async {
    final SharedPrefsStorage storage = await prefs();
    final AccountScopedSharedPrefsStorage accountPrefs = scoped(
      storage,
      'account-a',
    );
    final RecoveryKeySavedStore a = RecoveryKeySavedStore(accountPrefs);
    expect(a.read(), isFalse);

    await accountPrefs.setString(RecoveryKeySavedStore.storageKey, 'yes');
    expect(a.read(), isFalse, reason: 'a non-boolean value is not a "yes"');

    await a.markSaved();
    expect(a.read(), isTrue);
    expect(RecoveryKeySavedStore(scoped(storage, 'account-b')).read(), isFalse);
  });
}
