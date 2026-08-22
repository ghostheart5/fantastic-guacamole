import 'dart:async';

import '../../helpers/controllable_shared_preferences_platform.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/di/repositories_providers.dart';
import 'package:fantastic_guacamole/data/di/storage_providers.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/data/sync/sync_mutation_dispatcher.dart';
import 'package:fantastic_guacamole/data/sync/sync_queue_store.dart';
import 'package:fantastic_guacamole/domain/entities/extended_domain_entities.dart';
import 'package:fantastic_guacamole/domain/entities/settings_entity.dart';
import 'package:fantastic_guacamole/engine/learning/learning_state.dart';
import 'package:fantastic_guacamole/state/controllers/learning_controller.dart';
import 'package:fantastic_guacamole/state/controllers/profile_controller.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/settings_preference_provider.dart';
import 'package:fantastic_guacamole/state/services/extended_domain_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

final NotifierProvider<_ScopeController, AccountStorageScope> _scopeProvider =
    NotifierProvider<_ScopeController, AccountStorageScope>(
      _ScopeController.new,
    );

void main() {
  late SharedPreferencesStorePlatform originalPlatform;
  late ControllableSharedPreferencesPlatform platform;
  late ProviderContainer container;
  late _MemoryPrefs settingsStore;

  setUp(() async {
    originalPlatform = SharedPreferencesStorePlatform.instance;
    platform = ControllableSharedPreferencesPlatform(<String, Object>{
      'flutter.extended_domain.si_queries': '[{"id":"LEGACY_EXTENDED"}]',
    });
    SharedPreferences.resetStatic();
    SharedPreferencesStorePlatform.instance = platform;
    settingsStore = _MemoryPrefs()
      ..values['settings_entity_v1'] = '{"themeMode":"dark"}';
    final InMemorySecureStoreBackend secureBackend =
        InMemorySecureStoreBackend();
    container = ProviderContainer(
      overrides: [
        secureStoreProvider.overrideWithValue(
          SecureStore(backend: secureBackend),
        ),
        syncMutationDispatcherProvider.overrideWithValue(
          SyncMutationDispatcher(
            queueStore: SyncQueueStore.unavailable(),
            userId: null,
          ),
        ),
        sharedPrefsStoreProvider.overrideWithValue(settingsStore),
        accountStorageScopeProvider.overrideWith(
          (Ref ref) => ref.watch(_scopeProvider),
        ),
      ],
    );
    final SecureStore store = container.read(secureStoreProvider);
    await store.writeString('profile_state_v2', '{"name":"LEGACY_PROFILE"}');
    await store.writeString('ai_learning', '{"completed":99}');
  });

  tearDown(() async {
    container.dispose();
    SharedPreferences.resetStatic();
    SharedPreferencesStorePlatform.instance = originalPlatform;
  });

  test(
    'real Profile Learning Settings and ExtendedDomain hand off A to B to A',
    () async {
      await _setScope(container, AccountStorageScope.authenticated('A'));
      container.read(profileProvider.notifier).updateName('A_PROFILE_ONLY');
      await container
          .read(learningProvider.notifier)
          .apply(const LearningState(completed: 41));
      await container
          .read(settingsPreferencesProvider.notifier)
          .setThemeMode('light');
      await _extended(container).initialize();
      await container
          .read(saveSiQueryExtendedUseCaseProvider)
          .call(const SiQuery(id: 'A_EXTENDED_ONLY'));
      await _flush();
      expect(container.read(profileProvider).name, 'A_PROFILE_ONLY');
      expect(container.read(learningProvider).completed, 41);
      expect((await _readSettings(container)).themeMode, 'light');
      expect(_queries(container), contains('A_EXTENDED_ONLY'));

      final Object settingsA = container.read(settingsRepositoryProvider);
      final Object extendedA = _extended(container);
      final Object siUseCaseA = container.read(
        getSiQueriesExtendedUseCaseProvider,
      );
      container.read(siQueriesProvider);

      await _transition(container, AccountStorageScope.authenticated('B'));
      await _extended(container).initialize();
      expect(
        identical(settingsA, container.read(settingsRepositoryProvider)),
        isFalse,
      );
      expect(identical(extendedA, _extended(container)), isFalse);
      expect(
        identical(
          siUseCaseA,
          container.read(getSiQueriesExtendedUseCaseProvider),
        ),
        isFalse,
      );
      expect(container.read(profileProvider).name, 'Operative');
      expect(container.read(learningProvider).completed, 0);
      expect((await _readSettings(container)).themeMode, 'system');
      expect(_queries(container), isNot(contains('A_EXTENDED_ONLY')));
      expect(_projection(container), isNot(contains('A_EXTENDED_ONLY')));

      container.read(profileProvider.notifier).updateName('B_PROFILE_ONLY');
      await container
          .read(learningProvider.notifier)
          .apply(const LearningState(completed: 82));
      await container
          .read(settingsPreferencesProvider.notifier)
          .setThemeMode('dark');
      await container
          .read(saveSiQueryExtendedUseCaseProvider)
          .call(const SiQuery(id: 'B_EXTENDED_ONLY'));
      container.invalidate(siQueriesProvider);
      await _flush();
      expect(container.read(profileProvider).name, 'B_PROFILE_ONLY');
      expect(container.read(learningProvider).completed, 82);
      expect((await _readSettings(container)).themeMode, 'dark');
      expect(_projection(container), contains('B_EXTENDED_ONLY'));

      await _transition(container, AccountStorageScope.authenticated('A'));
      await _extended(container).initialize();
      expect(container.read(profileProvider).name, 'A_PROFILE_ONLY');
      expect(container.read(learningProvider).completed, 41);
      expect((await _readSettings(container)).themeMode, 'light');
      expect(_queries(container), contains('A_EXTENDED_ONLY'));
      expect(_queries(container), isNot(contains('B_EXTENDED_ONLY')));
      expect(
        settingsStore.values['settings_entity_v1'],
        '{"themeMode":"dark"}',
      );
      expect(
        platform.values['flutter.extended_domain.si_queries'],
        '[{"id":"LEGACY_EXTENDED"}]',
      );
    },
  );

  test(
    'same user, signed out to B, and superseded C retain no A state',
    () async {
      await _setScope(container, AccountStorageScope.authenticated('A'));
      container.read(profileProvider.notifier).updateName('A_PROFILE_ONLY');
      await container
          .read(learningProvider.notifier)
          .apply(const LearningState(completed: 7));
      await container
          .read(settingsPreferencesProvider.notifier)
          .setThemeMode('light');
      await _extended(container).initialize();
      await container
          .read(saveSiQueryExtendedUseCaseProvider)
          .call(const SiQuery(id: 'A_EXTENDED_ONLY'));
      await _flush();

      await _setScope(container, AccountStorageScope.authenticated('A'));
      expect(container.read(profileProvider).name, 'A_PROFILE_ONLY');
      expect(container.read(learningProvider).completed, 7);
      expect((await _readSettings(container)).themeMode, 'light');

      await _transition(container, const AccountStorageScope.signedOut());
      expect(container.read(profileProvider).name, 'Operative');
      expect(container.read(learningProvider).completed, 0);
      expect((await _readSettings(container)).themeMode, 'system');
      await _transition(container, AccountStorageScope.authenticated('B'));
      await _extended(container).initialize();
      expect(container.read(profileProvider).name, 'Operative');
      expect(container.read(learningProvider).completed, 0);
      expect((await _readSettings(container)).themeMode, 'system');
      expect(_queries(container), isNot(contains('A_EXTENDED_ONLY')));

      await _transition(container, const AccountStorageScope.unsafe());
      await _transition(container, AccountStorageScope.authenticated('C'));
      await _extended(container).initialize();
      expect(container.read(profileProvider).name, 'Operative');
      expect(container.read(learningProvider).completed, 0);
      expect((await _readSettings(container)).themeMode, 'system');
      expect(_queries(container), isNot(contains('A_EXTENDED_ONLY')));
    },
  );
}

Future<void> _setScope(
  ProviderContainer container,
  AccountStorageScope scope,
) async {
  container.read(_scopeProvider.notifier).set(scope);
  container.read(profileProvider);
  container.read(learningProvider);
  await _readSettings(container);
  await _flush();
}

Future<SettingsEntity> _readSettings(ProviderContainer container) async {
  final Completer<SettingsEntity> result = Completer<SettingsEntity>();
  late ProviderSubscription<AsyncValue<SettingsEntity>> subscription;
  subscription = container.listen(settingsPreferencesProvider, (
    _,
    AsyncValue<SettingsEntity> next,
  ) {
    if (next.hasValue && !result.isCompleted) {
      result.complete(next.requireValue);
    } else if (next.hasError && !result.isCompleted) {
      result.completeError(next.error!, next.stackTrace);
    }
  }, fireImmediately: true);
  try {
    return await result.future.timeout(const Duration(seconds: 3));
  } finally {
    subscription.close();
  }
}

Future<void> _transition(
  ProviderContainer container,
  AccountStorageScope next,
) async {
  container.read(_scopeProvider.notifier).set(next);
  container.invalidate(profileProvider);
  container.invalidate(learningProvider);
  container.invalidate(settingsRepositoryProvider);
  container.invalidate(settingsPreferencesProvider);
  container.invalidate(extendedDomainRepositoryProvider);
  container.invalidate(getSiQueriesExtendedUseCaseProvider);
  container.invalidate(saveSiQueryExtendedUseCaseProvider);
  container.invalidate(siQueriesProvider);
  container.read(profileProvider);
  container.read(learningProvider);
  await _readSettings(container);
  await _flush();
}

ExtendedDomainService _extended(ProviderContainer container) =>
    container.read(extendedDomainRepositoryProvider);

List<String> _queries(ProviderContainer container) => container
    .read(getSiQueriesExtendedUseCaseProvider)
    .call()
    .map((SiQuery query) => query.id)
    .toList();

List<String> _projection(ProviderContainer container) =>
    container.read(siQueriesProvider).map((SiQuery query) => query.id).toList();

Future<void> _flush() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

class _ScopeController extends Notifier<AccountStorageScope> {
  @override
  AccountStorageScope build() => const AccountStorageScope.unsafe();

  void set(AccountStorageScope next) => state = next;
}

class _MemoryPrefs implements SharedPrefsStore {
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
