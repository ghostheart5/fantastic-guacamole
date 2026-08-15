import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/state/models/soul_map_models.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/soul_map_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AccountStorageScope scope;
  late ProviderContainer container;

  setUp(() async {
    await SharedPrefsService.init();
    await SharedPrefsService.clear();
    scope = AccountStorageScope.authenticated('soul-a');
    container = _containerFor(() => scope);
  });

  tearDown(() => container.dispose());

  test('SoulMap profile is isolated A to B to A under V2 keys', () async {
    await _setProfile(container, 'A_SECRET_SOULMAP');
    final String aKey = _storageKey(container);
    expect(SharedPrefsService.load(aKey), contains('A_SECRET_SOULMAP'));

    scope = AccountStorageScope.authenticated('soul-b');
    container.invalidate(accountStorageScopeProvider);
    expect(_profile(container).purposeStatement, isEmpty);
    await _setProfile(container, 'B_SECRET_SOULMAP');
    final String bKey = _storageKey(container);
    expect(aKey, isNot(bKey));
    expect(SharedPrefsService.load(bKey), contains('B_SECRET_SOULMAP'));

    scope = AccountStorageScope.authenticated('soul-a');
    container.invalidate(accountStorageScopeProvider);
    expect(_profile(container).purposeStatement, 'A_SECRET_SOULMAP');
    expect(_profile(container).purposeStatement, isNot('B_SECRET_SOULMAP'));
  });

  test('signed-out SoulMap is empty and leaves legacy V1 unclaimed', () async {
    await _setProfile(container, 'A_SECRET_SOULMAP');
    await SharedPrefsService.save(
      SoulMapProfileStore.legacyStorageKey,
      '{"purposeStatement":"LEGACY_SECRET"}',
    );
    final Map<String, String> before = SharedPrefsService.getAll();

    scope = const AccountStorageScope.signedOut();
    container.invalidate(accountStorageScopeProvider);
    expect(_profile(container).purposeStatement, isEmpty);
    expect(container.read(soulMapProfileStoreProvider).isAvailable, isFalse);
    await _setProfile(container, 'SHOULD_NOT_PERSIST');
    expect(SharedPrefsService.getAll(), before);

    scope = AccountStorageScope.authenticated('soul-b');
    container.invalidate(accountStorageScopeProvider);
    expect(_profile(container).purposeStatement, isEmpty);
    expect(
      SharedPrefsService.load(SoulMapProfileStore.legacyStorageKey),
      '{"purposeStatement":"LEGACY_SECRET"}',
    );
  });

  test(
    'fresh authenticated containers restore only their own SoulMap V2 state',
    () async {
      await _setProfile(container, 'A_RESTART_SOULMAP');
      container.dispose();
      container = _containerFor(() => scope);
      expect(_profile(container).purposeStatement, 'A_RESTART_SOULMAP');

      scope = const AccountStorageScope.signedOut();
      container.invalidate(accountStorageScopeProvider);
      expect(_profile(container).purposeStatement, isEmpty);

      scope = AccountStorageScope.authenticated('soul-b');
      container.invalidate(accountStorageScopeProvider);
      expect(_profile(container).purposeStatement, isEmpty);
    },
  );
}

ProviderContainer _containerFor(AccountStorageScope Function() scope) {
  return ProviderContainer(
    overrides: [accountStorageScopeProvider.overrideWith((Ref ref) => scope())],
  );
}

SoulMapProfile _profile(ProviderContainer container) =>
    container.read(soulMapProfileProvider);

String _storageKey(ProviderContainer container) =>
    container.read(soulMapProfileStoreProvider).storageKey!;

Future<void> _setProfile(ProviderContainer container, String purpose) {
  return container
      .read(soulMapProfileProvider.notifier)
      .setProfile(SoulMapProfile.empty().copyWith(purposeStatement: purpose));
}
