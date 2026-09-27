import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/assistant_conversation_provider.dart';
import 'package:fantastic_guacamole/state/providers/billing_availability_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ProviderContainer configured({
    bool proxyAvailable = true,
    bool creditSpendingAvailable = true,
    AccountStorageScope? scope,
  }) => ProviderContainer(
    overrides: [
      internalCreditTestEnabledProvider.overrideWithValue(false),
      aiProxyAvailableProvider.overrideWithValue(proxyAvailable),
      creditSpendingAvailableProvider.overrideWithValue(
        creditSpendingAvailable,
      ),
      accountStorageScopeProvider.overrideWithValue(
        scope ?? AccountStorageScope.authenticated('public-review-account'),
      ),
    ],
  );

  test('public conversations do not require private tester membership', () {
    final container = configured();
    addTearDown(container.dispose);
    expect(container.read(internalCreditTestEnabledProvider), isFalse);
    expect(container.read(assistantConversationAvailableProvider), isTrue);
  });

  test('conversations require both reviewed proxy and credit availability', () {
    for (final flags in [(false, true), (true, false), (false, false)]) {
      final container = configured(
        proxyAvailable: flags.$1,
        creditSpendingAvailable: flags.$2,
      );
      addTearDown(container.dispose);
      expect(container.read(assistantConversationAvailableProvider), isFalse);
    }
  });

  test('signed-out and unsafe account scopes cannot open conversations', () {
    for (final scope in [
      const AccountStorageScope.signedOut(),
      const AccountStorageScope.unsafe(),
    ]) {
      final container = configured(scope: scope);
      addTearDown(container.dispose);
      expect(container.read(assistantConversationAvailableProvider), isFalse);
    }
  });
}
