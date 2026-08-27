import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/state/core/app_providers.dart';
import 'package:fantastic_guacamole/state/providers/account_onboarding_provider.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'legacy device completion migrates to only the existing account',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        onboardingCompleteStorageKey: true,
      });

      final ProviderContainer existingAccount = ProviderContainer(
        overrides: [
          accountStorageScopeProvider.overrideWithValue(
            AccountStorageScope.authenticated('existing-user'),
          ),
        ],
      );
      addTearDown(existingAccount.dispose);
      expect(
        await existingAccount.read(accountOnboardingCompleteProvider.future),
        isTrue,
      );

      final ProviderContainer newAccount = ProviderContainer(
        overrides: [
          accountStorageScopeProvider.overrideWithValue(
            AccountStorageScope.authenticated('new-user'),
          ),
        ],
      );
      addTearDown(newAccount.dispose);
      expect(
        await newAccount.read(accountOnboardingCompleteProvider.future),
        isFalse,
      );
    },
  );

  test('completion persists within the active account only', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final ProviderContainer container = ProviderContainer(
      overrides: [
        accountStorageScopeProvider.overrideWithValue(
          AccountStorageScope.authenticated('guided-user'),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(
      await container.read(accountOnboardingCompleteProvider.future),
      isFalse,
    );
    await container.read(accountOnboardingCompleteProvider.notifier).complete();
    expect(container.read(accountOnboardingCompleteProvider).value, isTrue);
  });
}
