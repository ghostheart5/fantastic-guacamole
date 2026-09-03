import 'package:fantastic_guacamole/core/storage/account_storage_namespace.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/storage/account_scoped_shared_prefs_store.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('account-scoped secure storage', () {
    test('isolates accounts and fails closed while signed out', () async {
      final SecureStore root = SecureStore(
        backend: InMemorySecureStoreBackend(),
      );
      final SecureStore accountA = root.forAccount(
        AccountStorageScope.authenticated('account-a'),
      );
      final SecureStore accountB = root.forAccount(
        AccountStorageScope.authenticated('account-b'),
      );

      await accountA.writeString('profile_state_v2', 'private-a');
      expect(await accountA.readString('profile_state_v2'), 'private-a');
      expect(await accountB.readString('profile_state_v2'), isNull);
      await accountB.writeString('profile_state_v2', 'private-b');
      expect(await accountA.readString('profile_state_v2'), 'private-a');
      expect(await accountB.readString('profile_state_v2'), 'private-b');

      final SecureStore signedOut = root.forAccount(
        const AccountStorageScope.signedOut(),
      );
      await expectLater(
        signedOut.readString('profile_state_v2'),
        throwsStateError,
      );
      expect(
        () => signedOut.writeString('profile_state_v2', 'blocked'),
        throwsStateError,
      );
    });

    test('legacy fallback is proven-owner read-only', () async {
      final SecureStore root = SecureStore(
        backend: InMemorySecureStoreBackend(),
      );
      await root.writeString('milestones_v1', 'legacy');
      final AccountStorageScope scope = AccountStorageScope.authenticated(
        'account-a',
      );
      final SecureStore ambiguous = root.forAccount(scope);
      final SecureStore proven = root.forAccount(
        scope,
        legacyOwnership: LegacyScopeOwnership.provenOwned,
      );

      expect(await ambiguous.readString('milestones_v1'), isNull);
      expect(await proven.readString('milestones_v1'), 'legacy');
      await proven.writeString('milestones_v1', 'scoped');
      expect(await root.readString('milestones_v1'), 'legacy');
      expect(await proven.readString('milestones_v1'), 'scoped');
      await proven.delete('milestones_v1');
      expect(await root.readString('milestones_v1'), 'legacy');
      expect(await proven.readString('milestones_v1'), isNull);
      expect(await proven.readAll(), isEmpty);
    });

    test(
      'deleteAll suppresses legacy without touching another account',
      () async {
        final SecureStore root = SecureStore(
          backend: InMemorySecureStoreBackend(),
        );
        await root.writeString('workspace_state_v1', 'legacy-workspace');
        final SecureStore accountA = root.forAccount(
          AccountStorageScope.authenticated('account-a'),
          legacyOwnership: LegacyScopeOwnership.provenOwned,
        );
        final SecureStore accountB = root.forAccount(
          AccountStorageScope.authenticated('account-b'),
        );
        await accountA.writeString('profile_state_v2', 'private-a');
        await accountB.writeString('profile_state_v2', 'private-b');

        await accountA.deleteAll();

        expect(await accountA.readString('workspace_state_v1'), isNull);
        expect(await accountA.readString('profile_state_v2'), isNull);
        expect(await accountA.readAll(), isEmpty);
        expect(await root.readString('workspace_state_v1'), 'legacy-workspace');
        expect(await accountB.readString('profile_state_v2'), 'private-b');
      },
    );
  });

  group('account-scoped preference storage', () {
    test('isolates accounts and fails closed while signed out', () async {
      final _MemoryPreferences root = _MemoryPreferences();
      final AccountScopedSharedPrefsStore accountA =
          AccountScopedSharedPrefsStore(
            delegate: root,
            scope: AccountStorageScope.authenticated('account-a'),
          );
      final AccountScopedSharedPrefsStore accountB =
          AccountScopedSharedPrefsStore(
            delegate: root,
            scope: AccountStorageScope.authenticated('account-b'),
          );

      await accountA.save('signals_v1', 'private-a');
      expect(accountA.load('signals_v1'), 'private-a');
      expect(accountB.load('signals_v1'), isNull);
      await accountB.save('signals_v1', 'private-b');
      expect(accountA.load('signals_v1'), 'private-a');
      expect(accountB.load('signals_v1'), 'private-b');

      final AccountScopedSharedPrefsStore signedOut =
          AccountScopedSharedPrefsStore(
            delegate: root,
            scope: const AccountStorageScope.signedOut(),
          );
      expect(() => signedOut.load('signals_v1'), throwsStateError);
      expect(() => signedOut.save('signals_v1', 'blocked'), throwsStateError);
    });

    test(
      'legacy fallback and clear preserve legacy and other accounts',
      () async {
        final _MemoryPreferences root = _MemoryPreferences();
        await root.save('signals_v1', 'legacy');
        final AccountScopedSharedPrefsStore accountA =
            AccountScopedSharedPrefsStore(
              delegate: root,
              scope: AccountStorageScope.authenticated('account-a'),
              legacyOwnership: LegacyScopeOwnership.provenOwned,
            );
        final AccountScopedSharedPrefsStore accountB =
            AccountScopedSharedPrefsStore(
              delegate: root,
              scope: AccountStorageScope.authenticated('account-b'),
            );

        expect(accountA.load('signals_v1'), 'legacy');
        expect(accountB.load('signals_v1'), isNull);
        await accountA.save('signals_v1', 'private-a');
        await accountB.save('signals_v1', 'private-b');
        await accountA.clear();

        expect(root.load('signals_v1'), 'legacy');
        expect(accountA.load('signals_v1'), isNull);
        expect(await accountA.keys(), isEmpty);
        expect(accountB.load('signals_v1'), 'private-b');
      },
    );

    test('delete suppresses legacy only for the deleting account', () async {
      final _MemoryPreferences root = _MemoryPreferences();
      await root.save('timeline_v1', 'legacy');
      final AccountScopedSharedPrefsStore accountA =
          AccountScopedSharedPrefsStore(
            delegate: root,
            scope: AccountStorageScope.authenticated('account-a'),
            legacyOwnership: LegacyScopeOwnership.provenOwned,
          );
      final AccountScopedSharedPrefsStore accountB =
          AccountScopedSharedPrefsStore(
            delegate: root,
            scope: AccountStorageScope.authenticated('account-b'),
            legacyOwnership: LegacyScopeOwnership.provenOwned,
          );

      expect(accountA.load('timeline_v1'), 'legacy');
      expect(accountB.load('timeline_v1'), 'legacy');
      await accountA.delete('timeline_v1');

      expect(accountA.load('timeline_v1'), isNull);
      expect(accountB.load('timeline_v1'), 'legacy');
      expect(root.load('timeline_v1'), 'legacy');
      expect(await accountA.keys(), isEmpty);
    });
  });
}

final class _MemoryPreferences
    implements SharedPrefsStore, EnumerableSharedPrefsStore {
  final Map<String, String> values = <String, String>{};

  @override
  Future<void> init() async {}

  @override
  Future<void> save(String key, String value) async => values[key] = value;

  @override
  String? load(String key) => values[key];

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<void> clear() async => values.clear();

  @override
  Future<Set<String>> keys() async => values.keys.toSet();
}
