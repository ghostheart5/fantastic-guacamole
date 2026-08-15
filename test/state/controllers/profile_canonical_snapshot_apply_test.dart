import 'dart:async';
import 'dart:convert';

import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/di/storage_providers.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/state/controllers/profile_controller.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final NotifierProvider<_ScopeController, AccountStorageScope> _scopeProvider =
    NotifierProvider<_ScopeController, AccountStorageScope>(
      _ScopeController.new,
    );

void main() {
  test('applies one complete canonical Profile snapshot to A V3 storage', () async {
    final InMemorySecureStoreBackend backend = InMemorySecureStoreBackend();
    final SecureStore store = SecureStore(backend: backend);
    final ProviderContainer container = _container(store);
    addTearDown(container.dispose);
    final AccountStorageScope scope = AccountStorageScope.authenticated('A');
    container.read(_scopeProvider.notifier).set(scope);
    container.read(profileProvider);
    await _flush();

    await container.read(profileProvider.notifier).applyCanonicalSnapshot(
      ProfileCanonicalSnapshot(
        xp: 125,
        legacyLevelFloor: 4,
        streak: 3,
        longestStreak: 7,
        name: 'A_NAME',
        lastActiveDate: DateTime.utc(2026, 8, 16),
        profileReady: true,
      ),
    );

    final ProfileState state = container.read(profileProvider);
    expect(state.name, 'A_NAME');
    expect(state.xp, 125);
    expect(state.level, 4);
    expect(state.legacyLevelFloor, 4);
    expect(state.streak, 3);
    expect(state.longestStreak, 7);
    expect(state.lastActiveDate, DateTime.utc(2026, 8, 16));
    expect(state.profileReady, isTrue);
    expect(state.soundEnabled, isTrue);
    expect(state.leveledUp, isFalse);

    final Map<String, dynamic> stored = jsonDecode(
      (await store.readString(ProfileController.canonicalStorageKeyForScope(scope)))!,
    ) as Map<String, dynamic>;
    expect(stored['name'], 'A_NAME');
    expect(stored['xp'], 125);
    expect(stored['legacyLevelFloor'], 4);
    expect(stored['streak'], 3);
    expect(stored['longestStreak'], 7);
    expect(stored['lastActiveDate'], '2026-08-16T00:00:00.000Z');
    expect(stored['profileReady'], isTrue);
    expect(stored.containsKey('soundEnabled'), isTrue);
    expect(stored.containsKey('leveledUp'), isFalse);
  });

  test('serializes overlapping canonical and existing mutations', () async {
    final InMemorySecureStoreBackend backend = InMemorySecureStoreBackend();
    final SecureStore store = SecureStore(backend: backend);
    final ProviderContainer container = _container(store);
    addTearDown(container.dispose);
    container
        .read(_scopeProvider.notifier)
        .set(AccountStorageScope.authenticated('A'));
    container.read(profileProvider);
    await _flush();

    final DateTime now = DateTime.now();
    final Future<void> apply = container
        .read(profileProvider.notifier)
        .applyCanonicalSnapshot(
          ProfileCanonicalSnapshot(
            xp: 50,
            legacyLevelFloor: 1,
            streak: 2,
            longestStreak: 2,
            name: 'FIRST',
            lastActiveDate: now,
            profileReady: true,
          ),
        );
    container.read(profileProvider.notifier).updateName('NEWEST');
    container.read(profileProvider.notifier).incrementStreak();
    container.read(profileProvider.notifier).addXP(50);
    await apply;
    await _flush();

    final ProfileState state = container.read(profileProvider);
    expect(state.name, 'NEWEST');
    expect(state.streak, 2);
    expect(state.longestStreak, 2);
    expect(state.xp, 100);
  });

  test('fails closed signed out and restores a complete snapshot after restart', () async {
    final InMemorySecureStoreBackend backend = InMemorySecureStoreBackend();
    final SecureStore store = SecureStore(backend: backend);
    final ProviderContainer signedOut = _container(store);
    signedOut.read(profileProvider);
    await signedOut.read(profileProvider.notifier).applyCanonicalSnapshot(
      const ProfileCanonicalSnapshot(
        xp: 99,
        legacyLevelFloor: 2,
        streak: 1,
        longestStreak: 1,
        name: 'MUST_NOT_WRITE',
        lastActiveDate: null,
        profileReady: true,
      ),
    );
    expect((await store.readAll()).keys, isNot(contains('profile_state_v3.v2.')));
    signedOut.dispose();

    final ProviderContainer first = _container(store);
    first
        .read(_scopeProvider.notifier)
        .set(AccountStorageScope.authenticated('A'));
    first.read(profileProvider);
    await _flush();
    await first.read(profileProvider.notifier).applyCanonicalSnapshot(
      ProfileCanonicalSnapshot(
        xp: 200,
        legacyLevelFloor: 3,
        streak: 5,
        longestStreak: 8,
        name: 'RESTORED_A',
        lastActiveDate: DateTime.utc(2026, 8, 17),
        profileReady: true,
      ),
    );
    first.dispose();

    final ProviderContainer restarted = _container(store);
    addTearDown(restarted.dispose);
    restarted
        .read(_scopeProvider.notifier)
        .set(AccountStorageScope.authenticated('A'));
    restarted.read(profileProvider);
    await _flush();
    final ProfileState state = restarted.read(profileProvider);
    expect(state.name, 'RESTORED_A');
    expect(state.xp, 200);
    expect(state.longestStreak, 8);
    expect(state.profileReady, isTrue);
  });

  test('write failure preserves V1 and succeeds on scoped retry', () async {
    final _FailingBackend backend = _FailingBackend()
      ..values['profile_entity_v1'] = '{"name":"LEGACY"}'
      ..failWrites = true;
    final SecureStore store = SecureStore(backend: backend);
    final ProviderContainer container = _container(store);
    addTearDown(container.dispose);
    container
        .read(_scopeProvider.notifier)
        .set(AccountStorageScope.authenticated('A'));
    container.read(profileProvider);
    await _flush();
    const ProfileCanonicalSnapshot snapshot = ProfileCanonicalSnapshot(
      xp: 20,
      legacyLevelFloor: 1,
      streak: 1,
      longestStreak: 1,
      name: 'RETRY_A',
      lastActiveDate: null,
      profileReady: true,
    );

    await expectLater(
      container.read(profileProvider.notifier).applyCanonicalSnapshot(snapshot),
      throwsStateError,
    );
    expect(backend.values['profile_entity_v1'], '{"name":"LEGACY"}');
    expect(backend.values.containsKey('profile_state_v3.v2.QQ=='), isFalse);

    backend.failWrites = false;
    await container.read(profileProvider.notifier).applyCanonicalSnapshot(snapshot);
    expect(backend.values['profile_entity_v1'], '{"name":"LEGACY"}');
    expect(
      backend.values[ProfileController.canonicalStorageKeyForUser('A')],
      contains('RETRY_A'),
    );
  });

  test('an in-flight A snapshot write cannot target B after a scope change', () async {
    final _HoldingBackend backend = _HoldingBackend();
    final SecureStore store = SecureStore(backend: backend);
    final ProviderContainer container = _container(store);
    addTearDown(container.dispose);
    final AccountStorageScope scopeA = AccountStorageScope.authenticated('A');
    final AccountStorageScope scopeB = AccountStorageScope.authenticated('B');
    container.read(_scopeProvider.notifier).set(scopeA);
    container.read(profileProvider);
    await _flush();
    final String keyA = ProfileController.canonicalStorageKeyForScope(scopeA);
    final String keyB = ProfileController.canonicalStorageKeyForScope(scopeB);
    backend.holdKey = keyA;

    final Future<void> apply = container
        .read(profileProvider.notifier)
        .applyCanonicalSnapshot(
          const ProfileCanonicalSnapshot(
            xp: 11,
            legacyLevelFloor: 1,
            streak: 1,
            longestStreak: 1,
            name: 'A_IN_FLIGHT',
            lastActiveDate: null,
            profileReady: true,
          ),
        );
    await backend.writeStarted.future.timeout(const Duration(seconds: 2));

    container.read(_scopeProvider.notifier).set(scopeB);
    container.read(profileProvider);
    await _flush();
    backend.releaseWrite();
    await apply;

    expect(backend.values[keyA], contains('A_IN_FLIGHT'));
    expect(backend.values.containsKey(keyB), isFalse);
    expect(container.read(profileProvider).name, 'Operative');
  });
}

ProviderContainer _container(SecureStore store) => ProviderContainer(
  overrides: [
    secureStoreProvider.overrideWithValue(store),
    accountStorageScopeProvider.overrideWith(
      (Ref ref) => ref.watch(_scopeProvider),
    ),
  ],
);

class _ScopeController extends Notifier<AccountStorageScope> {
  @override
  AccountStorageScope build() => const AccountStorageScope.signedOut();

  void set(AccountStorageScope value) => state = value;
}

Future<void> _flush() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

class _FailingBackend implements SecureStoreBackend {
  final Map<String, String> values = <String, String>{};
  bool failWrites = false;

  @override
  Future<void> delete({required String key}) async => values.remove(key);

  @override
  Future<void> deleteAll() async => values.clear();

  @override
  Future<String?> read({required String key}) async => values[key];

  @override
  Future<void> write({required String key, required String value}) async {
    if (failWrites) throw StateError('write failed');
    values[key] = value;
  }
}

class _HoldingBackend extends _FailingBackend {
  String? holdKey;
  final Completer<void> writeStarted = Completer<void>();
  final Completer<void> _release = Completer<void>();

  @override
  Future<void> write({required String key, required String value}) async {
    if (key == holdKey) {
      if (!writeStarted.isCompleted) writeStarted.complete();
      await _release.future;
    }
    await super.write(key: key, value: value);
  }

  void releaseWrite() {
    if (!_release.isCompleted) _release.complete();
  }
}
