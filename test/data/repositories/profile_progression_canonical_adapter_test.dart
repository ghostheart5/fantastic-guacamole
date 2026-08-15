import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/di/storage_providers.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/data/storage/hive_service.dart';
import 'package:fantastic_guacamole/domain/entities/profile_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_profile_repository.dart';
import 'package:fantastic_guacamole/domain/usecases/get_profile.dart';
import 'package:fantastic_guacamole/domain/usecases/get_progression.dart';
import 'package:fantastic_guacamole/state/controllers/profile_controller.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/progression_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

final NotifierProvider<_ScopeController, AccountStorageScope> _scopeProvider =
    NotifierProvider<_ScopeController, AccountStorageScope>(
      _ScopeController.new,
    );

void main() {
  test('domain Profile and Progression APIs use V3 and preserve V1 sentinels', () async {
    final _MemoryBackend backend = _MemoryBackend()
      ..values['profile_entity_v1'] = 'LEGACY_PRIVATE_PROFILE';
    final SecureStore store = SecureStore(backend: backend);
    final ProviderContainer container = _container(store);
    addTearDown(container.dispose);
    final AccountStorageScope scope = AccountStorageScope.authenticated('A');
    container.read(_scopeProvider.notifier).set(scope);
    await _seed(container, 'A_NAME', 100);

    final GetProfile getProfile = container.read(getProfileUseCaseProvider);
    final GetProgression getProgression = container.read(
      getProgressionUseCaseProvider,
    );
    final ProfileEntity initial = (await getProfile())!;
    expect(initial.name, 'A_NAME');
    expect(initial.xp, 100);
    expect(initial.longestStreak, 4);
    expect((await getProgression())!.xp, 100);

    await container.read(domainProfileRepositoryProvider).saveProfile(
      ProfileEntity(
        xp: 150,
        level: 4,
        legacyLevelFloor: 4,
        streak: 3,
        longestStreak: 8,
        name: 'A_DOMAIN_WRITE',
        lastActiveDate: DateTime.utc(2026, 8, 18),
        profileReady: true,
      ),
    );
    await container.read(updateXpUseCaseProvider).call(200);
    await container.read(updateLevelUseCaseProvider).call(5);
    await container.read(updateStreakUseCaseProvider).call(6);

    final ProfileEntity result = (await getProfile())!;
    expect(result.name, 'A_DOMAIN_WRITE');
    expect(result.xp, 200);
    expect(result.level, 5);
    expect(result.streak, 6);
    expect(result.longestStreak, 8);
    expect(container.read(profileProvider).name, 'A_DOMAIN_WRITE');
    expect(container.read(progressionProvider).progress.xp, 200);
    expect(backend.values['profile_entity_v1'], 'LEGACY_PRIVATE_PROFILE');
    expect(
      backend.values[ProfileController.canonicalStorageKeyForScope(scope)],
      contains('A_DOMAIN_WRITE'),
    );
  });

  test('A to B to A recreates APIs and retained A adapter fails closed', () async {
    final SecureStore store = SecureStore(backend: _MemoryBackend());
    final ProviderContainer container = _container(store);
    addTearDown(container.dispose);
    final AccountStorageScope a = AccountStorageScope.authenticated('A');
    final AccountStorageScope b = AccountStorageScope.authenticated('B');
    container.read(_scopeProvider.notifier).set(a);
    await _seed(container, 'SHARED_NAME', 10);
    final IProfileRepository retainedA = container.read(
      domainProfileRepositoryProvider,
    );

    container.read(_scopeProvider.notifier).set(b);
    await _seed(container, 'B_ONLY', 10);
    expect(await retainedA.getProfile(), isNull);
    await expectLater(
      retainedA.saveProfile(const ProfileEntity(name: 'MUST_NOT_WRITE')),
      throwsStateError,
    );
    expect((await container.read(getProfileUseCaseProvider)())!.name, 'B_ONLY');

    container.read(_scopeProvider.notifier).set(a);
    await _activateAndSettle(container);
    expect(
      (await container.read(getProfileUseCaseProvider)())!.name,
      'SHARED_NAME',
    );
  });

  test('signed-out fails closed and same-owner reauth and restart restore V3', () async {
    final SecureStore store = SecureStore(backend: _MemoryBackend());
    final ProviderContainer first = _container(store);
    final AccountStorageScope a = AccountStorageScope.authenticated('A');
    first.read(_scopeProvider.notifier).set(a);
    await _seed(first, 'A_REAUTH', 77);
    first.read(_scopeProvider.notifier).set(const AccountStorageScope.signedOut());
    await _activateAndSettle(first);
    expect(await first.read(getProfileUseCaseProvider)(), isNull);
    expect(await first.read(getProgressionUseCaseProvider)(), isNull);
    first.read(_scopeProvider.notifier).set(a);
    await _activateAndSettle(first);
    expect((await first.read(getProfileUseCaseProvider)())!.name, 'A_REAUTH');
    first.dispose();

    final ProviderContainer restarted = _container(store);
    addTearDown(restarted.dispose);
    restarted.read(_scopeProvider.notifier).set(a);
    await _activateAndSettle(restarted);
    expect((await restarted.read(getProfileUseCaseProvider)())!.name, 'A_REAUTH');
    expect((await restarted.read(getProgressionUseCaseProvider)())!.xp, 77);
  });

  test('domain Profile write failure preserves V1 and retry persists only V3', () async {
    final _MemoryBackend backend = _MemoryBackend()
      ..values['profile_entity_v1'] = 'LEGACY_PRIVATE_PROFILE';
    final ProviderContainer container = _container(SecureStore(backend: backend));
    addTearDown(container.dispose);
    final AccountStorageScope scope = AccountStorageScope.authenticated('A');
    container.read(_scopeProvider.notifier).set(scope);
    container.read(profileProvider);
    await _flush();
    backend.failWrites = true;
    const ProfileEntity profile = ProfileEntity(
      xp: 44,
      level: 1,
      legacyLevelFloor: 1,
      streak: 2,
      longestStreak: 2,
      name: 'RETRY',
      lastActiveDate: null,
      profileReady: true,
    );
    await expectLater(
      container.read(domainProfileRepositoryProvider).saveProfile(profile),
      throwsStateError,
    );
    expect(backend.values['profile_entity_v1'], 'LEGACY_PRIVATE_PROFILE');
    backend.failWrites = false;
    await container.read(domainProfileRepositoryProvider).saveProfile(profile);
    expect(
      backend.values[ProfileController.canonicalStorageKeyForScope(scope)],
      contains('RETRY'),
    );
  });

  test('Progression V1 and Hive remain inert across reauth and restart', () async {
    final _MemoryBackend backend = _MemoryBackend()
      ..values['profile_entity_v1'] = 'LEGACY_PRIVATE_PROFILE'
      ..values['progression_entity_v1'] = 'LEGACY_PRIVATE_PROGRESSION';
    final _ThrowingHiveStore hive = _ThrowingHiveStore();
    final SecureStore store = SecureStore(backend: backend);
    final AccountStorageScope a = AccountStorageScope.authenticated('A');
    final ProviderContainer first = _container(store, hive: hive);
    first.read(_scopeProvider.notifier).set(a);
    await _seed(first, 'A_V3_ONLY', 11);
    await first.read(updateXpUseCaseProvider)(222);
    await first.read(updateLevelUseCaseProvider)(7);
    await first.read(updateStreakUseCaseProvider)(9);
    expect((await first.read(getProgressionUseCaseProvider)())!.xp, 222);
    expect(backend.values['progression_entity_v1'], 'LEGACY_PRIVATE_PROGRESSION');
    expect(backend.values['profile_entity_v1'], 'LEGACY_PRIVATE_PROFILE');
    expect(hive.calls.where((String call) => call.contains('progression_box')), isEmpty);

    first.read(_scopeProvider.notifier).set(const AccountStorageScope.signedOut());
    await _activateAndSettle(first);
    first.read(_scopeProvider.notifier).set(a);
    await _activateAndSettle(first);
    expect((await first.read(getProgressionUseCaseProvider)())!.xp, 222);
    first.dispose();

    final ProviderContainer restarted = _container(store, hive: hive);
    addTearDown(restarted.dispose);
    restarted.read(_scopeProvider.notifier).set(a);
    await _activateAndSettle(restarted);
    expect((await restarted.read(getProgressionUseCaseProvider)())!.xp, 222);
    expect(backend.values['progression_entity_v1'], 'LEGACY_PRIVATE_PROGRESSION');
    expect(backend.values['profile_entity_v1'], 'LEGACY_PRIVATE_PROFILE');
    expect(hive.calls.where((String call) => call.contains('progression_box')), isEmpty);
  });
}

ProviderContainer _container(SecureStore store, {HiveStore? hive}) => ProviderContainer(
  overrides: [
    secureStoreProvider.overrideWithValue(store),
    if (hive != null) hiveStoreProvider.overrideWithValue(hive),
    accountStorageScopeProvider.overrideWith(
      (Ref ref) => ref.watch(_scopeProvider),
    ),
  ],
);

Future<void> _seed(ProviderContainer container, String name, int xp) async {
  await _activateAndSettle(container);
  await container.read(profileProvider.notifier).applyCanonicalSnapshot(
    ProfileCanonicalSnapshot(
      xp: xp,
      legacyLevelFloor: 2,
      streak: 2,
      longestStreak: 4,
      name: name,
      lastActiveDate: DateTime.utc(2026, 8, 17),
      profileReady: true,
    ),
  );
}

Future<void> _activateAndSettle(ProviderContainer container) async {
  container.read(profileProvider);
  await _flush();
}

class _ScopeController extends Notifier<AccountStorageScope> {
  @override
  AccountStorageScope build() => const AccountStorageScope.signedOut();

  void set(AccountStorageScope value) => state = value;
}

class _MemoryBackend implements SecureStoreBackend {
  final Map<String, String> values = <String, String>{};
  bool failWrites = false;

  @override
  Future<String?> read({required String key}) async => values[key];

  @override
  Future<void> write({required String key, required String value}) async {
    if (failWrites) throw StateError('write failed');
    values[key] = value;
  }

  @override
  Future<void> delete({required String key}) async {
    values.remove(key);
  }

  @override
  Future<void> deleteAll() async {
    values.clear();
  }
}

class _ThrowingHiveStore implements HiveStore {
  final List<String> calls = <String>[];

  Never _called(String method) {
    calls.add(method);
    throw StateError('Progression must not access Hive: $method');
  }

  @override
  Box<T> box<T>(String key) => _called('box:$key');
  @override
  Future<void> clearBox(String key) async => _called('clear:$key');
  @override
  Future<void> closeBox(String key) async => _called('close:$key');
  @override
  Future<void> init() async => _called('init');
  @override
  bool isBoxOpen(String key) => _called('isBoxOpen:$key');
  @override
  Future<Box<T>> openBox<T>(String key) async => _called('open:$key');
}

Future<void> _flush() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}
