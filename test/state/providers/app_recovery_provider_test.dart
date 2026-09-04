import 'package:fantastic_guacamole/core/storage/account_storage_namespace.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/app_recovery_provider.dart';
import 'package:fantastic_guacamole/state/providers/storage_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('recovery state remains isolated by exact account scope', () async {
    final _MemoryStore delegate = _MemoryStore();
    final ProviderContainer alpha = _container('alpha', delegate);
    final ProviderContainer beta = _container('beta', delegate);
    addTearDown(alpha.dispose);
    addTearDown(beta.dispose);

    await alpha
        .read(appRecoveryProvider)
        .saveState(lastPrimaryViewName: 'timeline');
    expect(
      (await alpha.read(appRecoveryProvider).loadState())?.lastPrimaryViewName,
      'timeline',
    );
    expect(await beta.read(appRecoveryProvider).loadState(), isNull);

    await beta
        .read(appRecoveryProvider)
        .saveState(lastPrimaryViewName: 'profile');
    expect(
      (await beta.read(appRecoveryProvider).loadState())?.lastPrimaryViewName,
      'profile',
    );
    expect(
      (await alpha.read(appRecoveryProvider).loadState())?.lastPrimaryViewName,
      'timeline',
    );
  });

  test('clearing one account preserves another account recovery', () async {
    final _MemoryStore delegate = _MemoryStore();
    final ProviderContainer alpha = _container('alpha', delegate);
    final ProviderContainer beta = _container('beta', delegate);
    addTearDown(alpha.dispose);
    addTearDown(beta.dispose);

    await alpha
        .read(appRecoveryProvider)
        .saveState(lastPrimaryViewName: 'timeline');
    await beta
        .read(appRecoveryProvider)
        .saveState(lastPrimaryViewName: 'profile');

    await alpha.read(appRecoveryProvider).clearAll();

    expect(await alpha.read(appRecoveryProvider).loadState(), isNull);
    expect(
      (await beta.read(appRecoveryProvider).loadState())?.lastPrimaryViewName,
      'profile',
    );
  });
}

ProviderContainer _container(String accountId, SharedPrefsStore delegate) {
  return ProviderContainer(
    overrides: [
      sharedPrefsStoreProvider.overrideWithValue(delegate),
      accountStorageScopeProvider.overrideWithValue(
        AccountStorageScope.authenticated(accountId),
      ),
      accountLegacyOwnershipProvider.overrideWithValue(
        LegacyScopeOwnership.provenNotOwned,
      ),
    ],
  );
}

class _MemoryStore implements SharedPrefsStore {
  final Map<String, String> values = <String, String>{};

  @override
  Future<void> clear() async => values.clear();

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<void> init() async {}

  @override
  String? load(String key) => values[key];

  @override
  Future<void> save(String key, String value) async => values[key] = value;
}
