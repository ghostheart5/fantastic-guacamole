import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'all cached ExtendedDomain use cases recreate when the account scope changes',
    () {
      AccountStorageScope scope = AccountStorageScope.authenticated(
        'extended-a',
      );
      final ProviderContainer container = ProviderContainer(
      overrides: [
          accountStorageScopeProvider.overrideWith((Ref ref) => scope),
        ],
      );
      addTearDown(container.dispose);

      final Object repositoryA = container.read(
        extendedDomainRepositoryProvider,
      );
      final List<Object> useCasesA = _useCases(container);

      scope = AccountStorageScope.authenticated('extended-b');
      container.invalidate(accountStorageScopeProvider);

      final Object repositoryB = container.read(
        extendedDomainRepositoryProvider,
      );
      final List<Object> useCasesB = _useCases(container);
      expect(identical(repositoryA, repositoryB), isFalse);
      for (int index = 0; index < useCasesA.length; index++) {
        expect(
          identical(useCasesA[index], useCasesB[index]),
          isFalse,
          reason: 'use case $index',
        );
      }
    },
  );
}

List<Object> _useCases(ProviderContainer container) => <Object>[
  container.read(getCoachMessagesUseCaseProvider),
  container.read(saveCoachMessageUseCaseProvider),
  container.read(getSiQueriesExtendedUseCaseProvider),
  container.read(saveSiQueryExtendedUseCaseProvider),
  container.read(getJournalEntriesUseCaseProvider),
  container.read(saveJournalEntryUseCaseProvider),
  container.read(getAnalyticsMetricsUseCaseProvider),
  container.read(saveAnalyticsMetricUseCaseProvider),
  container.read(getExtendedAppSettingsUseCaseProvider),
  container.read(saveExtendedAppSettingUseCaseProvider),
];
