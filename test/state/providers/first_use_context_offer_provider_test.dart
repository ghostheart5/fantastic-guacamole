import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/di/storage_providers.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/first_use_context_offer_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('offer is one-shot per account and survives provider restart', () async {
    final _MemoryPrefs store = _MemoryPrefs();
    final AccountStorageScope first = AccountStorageScope.authenticated(
      'first-account',
    );
    ProviderContainer container = ProviderContainer(
      overrides: [
        sharedPrefsStoreProvider.overrideWithValue(store),
        accountStorageScopeProvider.overrideWithValue(first),
      ],
    );
    expect(
      await container.read(firstUseContextOfferActionsProvider).claim(),
      isTrue,
    );
    expect(
      await container.read(firstUseContextOfferActionsProvider).claim(),
      isFalse,
    );
    container.dispose();

    container = ProviderContainer(
      overrides: [
        sharedPrefsStoreProvider.overrideWithValue(store),
        accountStorageScopeProvider.overrideWithValue(first),
      ],
    );
    addTearDown(container.dispose);
    expect(
      await container.read(firstUseContextOfferActionsProvider).claim(),
      isFalse,
    );

    final ProviderContainer otherAccount = ProviderContainer(
      overrides: [
        sharedPrefsStoreProvider.overrideWithValue(store),
        accountStorageScopeProvider.overrideWithValue(
          AccountStorageScope.authenticated('second-account'),
        ),
      ],
    );
    addTearDown(otherAccount.dispose);
    expect(
      await otherAccount.read(firstUseContextOfferActionsProvider).claim(),
      isTrue,
    );
  });

  test('signed-out state fails closed and records no offer', () async {
    final _MemoryPrefs store = _MemoryPrefs();
    final ProviderContainer container = ProviderContainer(
      overrides: [
        sharedPrefsStoreProvider.overrideWithValue(store),
        accountStorageScopeProvider.overrideWithValue(
          const AccountStorageScope.signedOut(),
        ),
      ],
    );
    addTearDown(container.dispose);
    expect(
      await container.read(firstUseContextOfferActionsProvider).claim(),
      isFalse,
    );
    expect(store.values, isEmpty);
  });
}

class _MemoryPrefs implements SharedPrefsStore {
  final Map<String, String> values = <String, String>{};

  @override
  Future<void> init() async {}

  @override
  String? load(String key) => values[key];

  @override
  Future<void> save(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<void> clear() async => values.clear();
}
