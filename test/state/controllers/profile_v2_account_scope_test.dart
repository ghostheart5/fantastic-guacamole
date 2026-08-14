import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/di/storage_providers.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/state/controllers/profile_controller.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final NotifierProvider<_TestScopeController, AccountStorageScope>
_scopeProvider = NotifierProvider<_TestScopeController, AccountStorageScope>(
  _TestScopeController.new,
);

void main() {
  test(
    'Profile V2 storage isolates A and B and preserves global legacy keys',
    () async {
      final InMemorySecureStoreBackend backend = InMemorySecureStoreBackend();
      final SecureStore store = SecureStore(backend: backend);
      await store.writeString('profile_state_v2', '{"name":"LEGACY_GLOBAL"}');
      await store.writeString('profile_state_v2.a_b', '{"name":"LEGACY_V1"}');

      final ProviderContainer container = _container(store);
      addTearDown(container.dispose);

      container
          .read(_scopeProvider.notifier)
          .set(AccountStorageScope.authenticated('a/b'));
      container.read(profileProvider);
      await _flush();
      container.read(profileProvider.notifier).updateName('A_PROFILE_ONLY');
      await _flush();

      container
          .read(_scopeProvider.notifier)
          .set(AccountStorageScope.authenticated('a?b'));
      container.invalidate(profileProvider);
      container.read(profileProvider);
      await _flush();
      expect(container.read(profileProvider).name, 'Operative');
      container.read(profileProvider.notifier).updateName('B_PROFILE_ONLY');
      await _flush();

      container
          .read(_scopeProvider.notifier)
          .set(AccountStorageScope.authenticated('a/b'));
      container.invalidate(profileProvider);
      container.read(profileProvider);
      await _flush();
      expect(container.read(profileProvider).name, 'A_PROFILE_ONLY');

      expect(
        await store.readString('profile_state_v2'),
        '{"name":"LEGACY_GLOBAL"}',
      );
      expect(
        await store.readString('profile_state_v2.a_b'),
        '{"name":"LEGACY_V1"}',
      );
      expect(
        await store.readString(
          ProfileController.canonicalStorageKeyForUser('a/b'),
        ),
        contains('A_PROFILE_ONLY'),
      );
      expect(
        await store.readString(
          ProfileController.canonicalStorageKeyForUser('a?b'),
        ),
        contains('B_PROFILE_ONLY'),
      );
    },
  );

  test(
    'unsafe scope fails closed without legacy hydration or writes',
    () async {
      final InMemorySecureStoreBackend backend = InMemorySecureStoreBackend();
      final SecureStore store = SecureStore(backend: backend);
      await store.writeString('profile_state_v2', '{"name":"LEGACY_GLOBAL"}');
      final ProviderContainer container = _container(store);
      addTearDown(container.dispose);

      await _flush();
      expect(container.read(profileProvider).name, 'Operative');
      container.read(profileProvider.notifier).updateName('must-not-persist');
      await _flush();

      expect(
        await store.readString('profile_state_v2'),
        '{"name":"LEGACY_GLOBAL"}',
      );
      expect(
        (await store.readAll()).keys,
        isNot(contains('profile_state_v3.v2.')),
      );
    },
  );

  test(
    'scoped read failure does not fall back to global Profile storage',
    () async {
      final _FailingProfileBackend backend = _FailingProfileBackend()
        ..values['profile_state_v2'] = '{"name":"LEGACY_GLOBAL"}';
      final ProviderContainer container = _container(
        SecureStore(backend: backend),
      );
      addTearDown(container.dispose);

      container
          .read(_scopeProvider.notifier)
          .set(AccountStorageScope.authenticated('reader'));
      backend.failReads = true;
      container.read(profileProvider);
      await _flush();

      expect(container.read(profileProvider).name, 'Operative');
      expect(
        backend.readKeys,
        contains(ProfileController.canonicalStorageKeyForUser('reader')),
      );
      expect(backend.readKeys, isNot(contains('profile_state_v2')));
    },
  );

  test(
    'restart and signed-out transition retain only the owning V2 Profile',
    () async {
      final InMemorySecureStoreBackend backend = InMemorySecureStoreBackend();
      final SecureStore store = SecureStore(backend: backend);
      final ProviderContainer a = _container(store);
      a
          .read(_scopeProvider.notifier)
          .set(AccountStorageScope.authenticated('A'));
      a.read(profileProvider);
      await _flush();
      a.read(profileProvider.notifier).updateName('A_PROFILE_ONLY');
      await _flush();
      a
          .read(_scopeProvider.notifier)
          .set(const AccountStorageScope.signedOut());
      await _flush();
      a.dispose();

      final ProviderContainer b = _container(store);
      addTearDown(b.dispose);
      b
          .read(_scopeProvider.notifier)
          .set(AccountStorageScope.authenticated('B'));
      b.read(profileProvider);
      await _flush();
      expect(b.read(profileProvider).name, 'Operative');

      final ProviderContainer restoredA = _container(store);
      addTearDown(restoredA.dispose);
      restoredA
          .read(_scopeProvider.notifier)
          .set(AccountStorageScope.authenticated('A'));
      restoredA.read(profileProvider);
      await _flush();
      expect(restoredA.read(profileProvider).name, 'A_PROFILE_ONLY');
    },
  );

  test(
    'scoped write failure never writes a global or V1 Profile key',
    () async {
      final _FailingProfileBackend backend = _FailingProfileBackend()
        ..values['profile_state_v2'] = '{"name":"LEGACY_GLOBAL"}'
        ..failWrites = true;
      final SecureStore store = SecureStore(backend: backend);
      final ProviderContainer container = _container(store);
      addTearDown(container.dispose);
      container
          .read(_scopeProvider.notifier)
          .set(AccountStorageScope.authenticated('writer'));
      container.read(profileProvider);
      await _flush();

      await expectLater(
        container
            .read(profileProvider.notifier)
            .setProgressionSnapshot(xp: 10, level: 1, streak: 1),
        throwsStateError,
      );
      expect(backend.values['profile_state_v2'], '{"name":"LEGACY_GLOBAL"}');
      expect(backend.values.containsKey('profile_state_v2.writer'), isFalse);
    },
  );

  test(
    'same-user refresh keeps the same V2 Profile without legacy migration',
    () async {
      final InMemorySecureStoreBackend backend = InMemorySecureStoreBackend();
      final SecureStore store = SecureStore(backend: backend);
      final ProviderContainer container = _container(store);
      addTearDown(container.dispose);
      final AccountStorageScope scope = AccountStorageScope.authenticated(
        'same',
      );
      container.read(_scopeProvider.notifier).set(scope);
      container.read(profileProvider);
      await _flush();
      container.read(profileProvider.notifier).updateName('SAME_USER');
      await _flush();

      container.read(_scopeProvider.notifier).set(scope);
      await _flush();
      expect(container.read(profileProvider).name, 'SAME_USER');
      expect(
        await store.readString(
          ProfileController.canonicalStorageKeyForScope(scope),
        ),
        contains('SAME_USER'),
      );
      expect(await store.readString('profile_state_v2.same'), isNull);
    },
  );

  test('A-to-B scoped hydration failure cannot expose A Profile', () async {
    final _FailingProfileBackend backend = _FailingProfileBackend();
    final SecureStore store = SecureStore(backend: backend);
    final ProviderContainer container = _container(store);
    addTearDown(container.dispose);
    container
        .read(_scopeProvider.notifier)
        .set(AccountStorageScope.authenticated('A'));
    container.read(profileProvider);
    await _flush();
    container.read(profileProvider.notifier).updateName('A_PROFILE_ONLY');
    await _flush();

    backend.failReads = true;
    container
        .read(_scopeProvider.notifier)
        .set(AccountStorageScope.authenticated('B'));
    container.invalidate(profileProvider);
    container.read(profileProvider);
    await _flush();

    expect(container.read(profileProvider).name, 'Operative');
    expect(
      backend.readKeys,
      contains(ProfileController.canonicalStorageKeyForUser('B')),
    );
    expect(backend.readKeys, isNot(contains('profile_state_v2')));
  });
}

ProviderContainer _container(SecureStore store) {
  return ProviderContainer(
    overrides: [
      secureStoreProvider.overrideWithValue(store),
      accountStorageScopeProvider.overrideWith(
        (Ref ref) => ref.watch(_scopeProvider),
      ),
    ],
  );
}

class _TestScopeController extends Notifier<AccountStorageScope> {
  @override
  AccountStorageScope build() => const AccountStorageScope.unsafe();

  void set(AccountStorageScope value) => state = value;
}

Future<void> _flush() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

class _FailingProfileBackend implements SecureStoreBackend {
  final Map<String, String> values = <String, String>{};
  final List<String> readKeys = <String>[];
  bool failReads = false;
  bool failWrites = false;

  @override
  Future<void> delete({required String key}) async => values.remove(key);

  @override
  Future<void> deleteAll() async => values.clear();

  @override
  Future<String?> read({required String key}) async {
    readKeys.add(key);
    if (failReads) throw StateError('read failed');
    return values[key];
  }

  @override
  Future<void> write({required String key, required String value}) async {
    if (failWrites) throw StateError('write failed');
    values[key] = value;
  }
}
