import '../../helpers/controllable_shared_preferences_platform.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/domain/entities/extended_domain_entities.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/services/extended_domain_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

void main() {
  late AccountStorageScope testScope;
  late SharedPreferencesStorePlatform original;
  late ControllableSharedPreferencesPlatform platform;
  late AccountStorageScope scope;
  late ProviderContainer container;

  setUp(() {
    original = SharedPreferencesStorePlatform.instance;
    platform = ControllableSharedPreferencesPlatform(<String, Object>{
      'flutter.extended_domain.si_queries': '[{"id":"LEGACY"}]',
      'flutter.extended_domain.settings.A': '[{"id":"LEGACY_V1"}]',
    });
    SharedPreferences.resetStatic();
    SharedPreferencesStorePlatform.instance = platform;
    scope = AccountStorageScope.authenticated('A');
    testScope = scope;
    container = ProviderContainer(overrides: [
      accountStorageScopeProvider.overrideWith((Ref ref) => testScope),
    ]);
  });
  tearDown(() {
    container.dispose();
    SharedPreferences.resetStatic();
    SharedPreferencesStorePlatform.instance = original;
  });

  test('real SI query and extended setting providers isolate A to B to A', () async {
    await _repository(container).initialize();
    await container.read(saveSiQueryExtendedUseCaseProvider).call(const SiQuery(id: 'A_SI_QUERY'));
    await container.read(saveExtendedAppSettingUseCaseProvider).call(const AppSetting(id: 'A_EXT_SETTING'));
    await container.read(saveCoachMessageUseCaseProvider).call(const CoachMessage(id: 'A_COACH'));
    await container.read(saveJournalEntryUseCaseProvider).call(const JournalEntry(id: 'A_JOURNAL'));
    await container.read(saveAnalyticsMetricUseCaseProvider).call(const AnalyticsMetric(id: 'A_ANALYTICS'));
    expect(_queries(container), contains('A_SI_QUERY'));
    expect(_settings(container), contains('A_EXT_SETTING'));
    expect(_coach(container), contains('A_COACH'));
    expect(_journal(container), contains('A_JOURNAL'));
    expect(_analytics(container), contains('A_ANALYTICS'));
    final Object repositoryA = _repository(container);
    final List<Object> providersA = _providers(container);

    testScope = AccountStorageScope.authenticated('B'); container.invalidate(accountStorageScopeProvider);
    await _repository(container).initialize();
    expect(identical(repositoryA, _repository(container)), isFalse);
    for (int i = 0; i < providersA.length; i++) {
      expect(identical(providersA[i], _providers(container)[i]), isFalse);
    }
    expect(_queries(container), isNot(contains('A_SI_QUERY')));
    expect(_settings(container), isNot(contains('A_EXT_SETTING')));
    expect(_coach(container), isNot(contains('A_COACH')));
    expect(_journal(container), isNot(contains('A_JOURNAL')));
    expect(_analytics(container), isNot(contains('A_ANALYTICS')));
    await container.read(saveSiQueryExtendedUseCaseProvider).call(const SiQuery(id: 'B_SI_QUERY'));
    await container.read(saveExtendedAppSettingUseCaseProvider).call(const AppSetting(id: 'B_EXT_SETTING'));
    await container.read(saveCoachMessageUseCaseProvider).call(const CoachMessage(id: 'B_COACH'));
    await container.read(saveJournalEntryUseCaseProvider).call(const JournalEntry(id: 'B_JOURNAL'));
    await container.read(saveAnalyticsMetricUseCaseProvider).call(const AnalyticsMetric(id: 'B_ANALYTICS'));
    expect(_queries(container), contains('B_SI_QUERY'));
    expect(_settings(container), contains('B_EXT_SETTING'));
    expect(_coach(container), contains('B_COACH'));
    expect(_journal(container), contains('B_JOURNAL'));
    expect(_analytics(container), contains('B_ANALYTICS'));

    testScope = AccountStorageScope.authenticated('A'); container.invalidate(accountStorageScopeProvider);
    await _repository(container).initialize();
    expect(_queries(container), contains('A_SI_QUERY'));
    expect(_queries(container), isNot(contains('B_SI_QUERY')));
    expect(_settings(container), contains('A_EXT_SETTING'));
    expect(_settings(container), isNot(contains('B_EXT_SETTING')));
    expect(_coach(container), contains('A_COACH'));
    expect(_coach(container), isNot(contains('B_COACH')));
    expect(_journal(container), contains('A_JOURNAL'));
    expect(_journal(container), isNot(contains('B_JOURNAL')));
    expect(_analytics(container), contains('A_ANALYTICS'));
    expect(_analytics(container), isNot(contains('B_ANALYTICS')));
    expect(platform.values['flutter.extended_domain.si_queries'], '[{"id":"LEGACY"}]');
    expect(platform.values['flutter.extended_domain.settings.A'], '[{"id":"LEGACY_V1"}]');
  });

  test('siQueriesProvider remains scoped through same-user and signed-out to B', () async {
    await _repository(container).initialize();
    await container.read(saveSiQueryExtendedUseCaseProvider).call(const SiQuery(id: 'A_SI_QUERY'));
    expect(_siProjection(container), contains('A_SI_QUERY'));
    testScope = AccountStorageScope.authenticated('A'); container.invalidate(accountStorageScopeProvider);
    await _repository(container).initialize();
    expect(_siProjection(container).where((id) => id == 'A_SI_QUERY'), hasLength(1));
    testScope = const AccountStorageScope.signedOut(); container.invalidate(accountStorageScopeProvider);
    await _repository(container).initialize();
    expect(_siProjection(container), isNot(contains('A_SI_QUERY')));
    testScope = AccountStorageScope.authenticated('B'); container.invalidate(accountStorageScopeProvider);
    await _repository(container).initialize();
    expect(_siProjection(container), isNot(contains('A_SI_QUERY')));
    await container.read(saveSiQueryExtendedUseCaseProvider).call(const SiQuery(id: 'B_SIGNED_OUT_QUERY'));
    container.invalidate(siQueriesProvider);
    expect(_siProjection(container), contains('B_SIGNED_OUT_QUERY'));
    expect(platform.values['flutter.extended_domain.si_queries'], '[{"id":"LEGACY"}]');
  });
}

ExtendedDomainService _repository(ProviderContainer c) => c.read(extendedDomainRepositoryProvider);
List<String> _queries(ProviderContainer c) => c.read(getSiQueriesExtendedUseCaseProvider).call().map((e) => e.id).toList();
List<String> _siProjection(ProviderContainer c) => c.read(siQueriesProvider).map((e) => e.id).toList();
List<String> _settings(ProviderContainer c) => c.read(getExtendedAppSettingsUseCaseProvider).call().map((e) => e.id).toList();
List<String> _coach(ProviderContainer c) => c.read(getCoachMessagesUseCaseProvider).call().map((e) => e.id).toList();
List<String> _journal(ProviderContainer c) => c.read(getJournalEntriesUseCaseProvider).call().map((e) => e.id).toList();
List<String> _analytics(ProviderContainer c) => c.read(getAnalyticsMetricsUseCaseProvider).call().map((e) => e.id).toList();
List<Object> _providers(ProviderContainer c) => <Object>[
  c.read(getCoachMessagesUseCaseProvider),
  c.read(saveCoachMessageUseCaseProvider),
  c.read(getSiQueriesExtendedUseCaseProvider),
  c.read(saveSiQueryExtendedUseCaseProvider),
  c.read(getJournalEntriesUseCaseProvider),
  c.read(saveJournalEntryUseCaseProvider),
  c.read(getAnalyticsMetricsUseCaseProvider),
  c.read(saveAnalyticsMetricUseCaseProvider),
  c.read(getExtendedAppSettingsUseCaseProvider),
  c.read(saveExtendedAppSettingUseCaseProvider),
];
