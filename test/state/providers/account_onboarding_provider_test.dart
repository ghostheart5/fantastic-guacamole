import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_namespace.dart';
import 'package:fantastic_guacamole/state/core/app_providers.dart';
import 'package:fantastic_guacamole/state/providers/account_onboarding_provider.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'same-account refresh preserves completed onboarding without loading',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final scope = NotifierProvider<_ScopeNotifier, AccountStorageScope>(
        _ScopeNotifier.new,
      );
      final container = ProviderContainer(
        overrides: [
          accountStorageScopeProvider.overrideWith((ref) => ref.watch(scope)),
          accountLegacyOwnershipProvider.overrideWithValue(
            LegacyScopeOwnership.ambiguous,
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(accountOnboardingCompleteProvider.future);
      await container
          .read(accountOnboardingCompleteProvider.notifier)
          .complete();
      final observed = <AsyncValue<bool>>[];
      container.listen(
        accountOnboardingCompleteProvider,
        (_, next) => observed.add(next),
      );
      container
          .read(scope.notifier)
          .set(AccountStorageScope.authenticated('refresh-user'));
      expect(
        container.read(accountOnboardingCompleteProvider).asData?.value,
        isTrue,
      );
      await container.pump();
      expect(observed.any((value) => value.isLoading), isFalse);

      container
          .read(scope.notifier)
          .set(AccountStorageScope.authenticated('different-user'));
      expect(
        container.read(accountOnboardingCompleteProvider).asData?.value,
        isNot(true),
      );
      expect(
        await container.read(accountOnboardingCompleteProvider.future),
        isFalse,
      );
      container
          .read(scope.notifier)
          .set(AccountStorageScope.authenticated('refresh-user'));
      expect(
        container.read(accountOnboardingCompleteProvider).asData?.value,
        isTrue,
        reason:
            'Returning to a completed account must not briefly reopen setup.',
      );
      expect(
        await container.read(accountOnboardingCompleteProvider.future),
        isTrue,
      );
      container.read(scope.notifier).set(const AccountStorageScope.unsafe());
      expect(
        container.read(accountOnboardingCompleteProvider).asData?.value,
        isNot(true),
      );
      expect(
        await container.read(accountOnboardingCompleteProvider.future),
        isFalse,
      );
    },
  );

  test(
    'stored completion survives legacy-ownership refresh without loading',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final ownership =
          NotifierProvider<_OwnershipNotifier, LegacyScopeOwnership>(
            _OwnershipNotifier.new,
          );
      final container = ProviderContainer(
        overrides: [
          accountStorageScopeProvider.overrideWithValue(
            AccountStorageScope.authenticated('completed-account'),
          ),
          accountLegacyOwnershipProvider.overrideWith(
            (ref) => ref.watch(ownership),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(accountOnboardingCompleteProvider.future);
      await container
          .read(accountOnboardingCompleteProvider.notifier)
          .complete();
      for (final value in LegacyScopeOwnership.values) {
        container.read(ownership.notifier).set(value);
        expect(
          container.read(accountOnboardingCompleteProvider).asData?.value,
          isTrue,
        );
      }
      await container.read(accountOnboardingCompleteProvider.notifier).reset();
      container.read(ownership.notifier).set(LegacyScopeOwnership.provenOwned);
      expect(
        container.read(accountOnboardingCompleteProvider).asData?.value,
        isFalse,
      );
    },
  );

  test(
    'legacy device completion is read-only for only the proven owner',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        onboardingCompleteStorageKey: true,
      });

      final ProviderContainer existingAccount = ProviderContainer(
        overrides: [
          accountStorageScopeProvider.overrideWithValue(
            AccountStorageScope.authenticated('existing-user'),
          ),
          accountLegacyOwnershipProvider.overrideWithValue(
            LegacyScopeOwnership.provenOwned,
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
          accountLegacyOwnershipProvider.overrideWithValue(
            LegacyScopeOwnership.ambiguous,
          ),
        ],
      );
      addTearDown(newAccount.dispose);
      expect(
        await newAccount.read(accountOnboardingCompleteProvider.future),
        isFalse,
      );
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(onboardingCompleteStorageKey), isTrue);
      expect(
        prefs.getBool(
          'onboarding_profile_complete_v1.'
          '${AccountStorageScope.authenticated('existing-user').v2Namespace}',
        ),
        isNull,
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

class _ScopeNotifier extends Notifier<AccountStorageScope> {
  @override
  AccountStorageScope build() =>
      AccountStorageScope.authenticated('refresh-user');

  void set(AccountStorageScope scope) => state = scope;
}

class _OwnershipNotifier extends Notifier<LegacyScopeOwnership> {
  @override
  LegacyScopeOwnership build() => LegacyScopeOwnership.ambiguous;

  void set(LegacyScopeOwnership value) => state = value;
}
