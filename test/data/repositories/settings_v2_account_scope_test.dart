import 'dart:async';
import 'dart:convert';

import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/di/repositories_providers.dart';
import 'package:fantastic_guacamole/data/di/storage_providers.dart';
import 'package:fantastic_guacamole/data/repositories/settings_repository.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/data/sync/sync_mutation_dispatcher.dart';
import 'package:fantastic_guacamole/data/sync/sync_operation.dart';
import 'package:fantastic_guacamole/data/sync/sync_queue_store.dart';
import 'package:fantastic_guacamole/domain/entities/settings_entity.dart';
import 'package:fantastic_guacamole/domain/entities/app_theme_entity.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/settings_preference_provider.dart';
import 'package:fantastic_guacamole/state/providers/theme_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final NotifierProvider<_ScopeController, AccountStorageScope> _scopeProvider =
    NotifierProvider<_ScopeController, AccountStorageScope>(
      _ScopeController.new,
    );

void main() {
  test(
    'Settings V2 storage isolates A and B and preserves global legacy',
    () async {
      final _MemoryStore store = _MemoryStore()
        ..values['settings_entity_v1'] = '{"themeMode":"dark"}';
      final SettingsRepository a = _repository(store, 'a/b');
      await a.saveSettings(const SettingsEntity(themeMode: 'light'));
      final SettingsRepository b = _repository(store, 'a?b');
      expect(await b.getSettings(), isNull);
      await b.saveSettings(const SettingsEntity(themeMode: 'dark'));

      expect((await a.getSettings())!.themeMode, 'light');
      expect((await b.getSettings())!.themeMode, 'dark');
      expect(store.values['settings_entity_v1'], '{"themeMode":"dark"}');
      expect(
        store.values[SettingsRepository.canonicalStorageKeyForUser('a/b')],
        contains('"themeMode":"light"'),
      );
      expect(
        store.values[SettingsRepository.canonicalStorageKeyForUser('a?b')],
        contains('"themeMode":"dark"'),
      );
    },
  );

  test(
    'Settings repository fails closed outside a safe account scope',
    () async {
      final _MemoryStore store = _MemoryStore()
        ..values['settings_entity_v1'] = '{"themeMode":"dark"}';
      final SettingsRepository unsafe = SettingsRepository(
        store,
        storageScope: const AccountStorageScope.unsafe(),
      );

      expect(await unsafe.getSettings(), isNull);
      await expectLater(
        unsafe.saveSettings(const SettingsEntity(themeMode: 'light')),
        throwsStateError,
      );
      expect(store.values['settings_entity_v1'], '{"themeMode":"dark"}');
    },
  );

  test(
    'restart and same-user rebuild restore only the matching V2 Settings',
    () async {
      final _MemoryStore store = _MemoryStore();
      final SettingsRepository first = _repository(store, 'A');
      await first.saveSettings(
        const SettingsEntity(soundEnabled: false, themeMode: 'dark'),
      );

      final SettingsRepository rebuiltA = _repository(store, 'A');
      final SettingsRepository b = _repository(store, 'B');
      expect((await rebuiltA.getSettings())!.soundEnabled, isFalse);
      expect((await rebuiltA.getSettings())!.themeMode, 'dark');
      expect(await b.getSettings(), isNull);
    },
  );

  test(
    'scoped read and write failures never use the global Settings key',
    () async {
      final _FailingStore store = _FailingStore()
        ..values['settings_entity_v1'] = '{"themeMode":"dark"}'
        ..failLoads = true;
      final SettingsRepository reader = _repository(store, 'reader');
      expect(await reader.getSettings(), isNull);
      expect(store.loadKeys, <String>[
        SettingsRepository.canonicalStorageKeyForUser('reader'),
      ]);

      store.failLoads = false;
      store.failSaves = true;
      final SettingsRepository writer = _repository(store, 'writer');
      await expectLater(
        writer.saveSettings(const SettingsEntity(themeMode: 'light')),
        throwsStateError,
      );
      store.failSaves = false;
      await writer.saveSettings(const SettingsEntity(themeMode: 'light'));
      expect(store.values['settings_entity_v1'], '{"themeMode":"dark"}');
      expect(
        store.values[SettingsRepository.canonicalStorageKeyForUser('writer')],
        contains('"themeMode":"light"'),
      );
    },
  );

  test(
    'Settings provider and theme projection recreate across account scope',
    () async {
      final _MemoryStore store = _MemoryStore();
      final ProviderContainer container = _container(store);
      addTearDown(container.dispose);

      await _setScope(container, AccountStorageScope.authenticated('A'));
      await container
          .read(settingsPreferencesProvider.notifier)
          .setThemeMode('light');
      expect(
        (await _readTheme(container, expectedDark: false)).isDark,
        isFalse,
      );

      await _setScope(container, AccountStorageScope.authenticated('B'));
      expect(
        (await _readSettings(container)).themeMode,
        'system',
      );
      expect(
        (await _readTheme(container, expectedDark: true)).isDark,
        isTrue,
      );

      await _setScope(container, AccountStorageScope.authenticated('A'));
      expect(
        (await _readSettings(container)).themeMode,
        'light',
      );
    },
  );

  test(
    'Settings sync queues raw authenticated identity and never B payloads A',
    () async {
      final _MemoryStore store = _MemoryStore();
      final _Queue queue = _Queue();
      final SyncMutationDispatcher aDispatcher = SyncMutationDispatcher(
        queueStore: queue,
        userId: 'raw-A',
      );
      final SettingsRepository a = SettingsRepository(
        store,
        storageScope: AccountStorageScope.authenticated('local/A'),
        syncDispatcher: aDispatcher,
      );
      await a.saveSettings(const SettingsEntity(themeMode: 'light'));
      final SyncOperation aOperation = (await queue.readAll()).single;
      expect(aOperation.userId, 'raw-A');
      expect(aOperation.payload['user_id'], 'raw-A');
      expect(aOperation.payload.values, isNot(contains('v2.bG9jYWwvQQ==')));

      final SyncMutationDispatcher bDispatcher = SyncMutationDispatcher(
        queueStore: queue,
        userId: 'raw-B',
      );
      final SettingsRepository b = SettingsRepository(
        store,
        storageScope: AccountStorageScope.authenticated('local/B'),
        syncDispatcher: bDispatcher,
      );
      expect(await b.getSettings(), isNull);
      await b.saveSettings(const SettingsEntity(themeMode: 'dark'));
      final List<SyncOperation> operations = await queue.readAll();
      final SyncOperation bOperation = operations.singleWhere(
        (SyncOperation operation) => operation.userId == 'raw-B',
      );
      expect(bOperation.payload['theme_mode'], 'dark');
      expect(bOperation.payload['theme_mode'], isNot('light'));
      expect(bOperation.payload['user_id'], 'raw-B');
    },
  );

  test(
    'legacy migration inputs stay inactive in Settings preferences',
    () async {
      final _MemoryStore store = _MemoryStore()
        ..values['settings_entity_v1'] = '{"themeMode":"dark"}';
      final ProviderContainer container = _container(store);
      addTearDown(container.dispose);
      await _setScope(container, AccountStorageScope.authenticated('A'));

      final SettingsEntity settings = await _readSettings(container);
      expect(settings.themeMode, 'system');
      expect(settings.soundEnabled, isTrue);
      expect(store.values['settings_entity_v1'], '{"themeMode":"dark"}');
    },
  );

  test('theme projection clears at signed-out and restores the owning scope', () async {
    final ProviderContainer container = _container(_MemoryStore());
    addTearDown(container.dispose);

    await _setScope(container, AccountStorageScope.authenticated('A'));
    await container
        .read(settingsPreferencesProvider.notifier)
        .setThemeMode('light');
    container.invalidate(currentThemeProvider);
    expect((await _readTheme(container, expectedDark: false)).isDark, isFalse);

    await _setScope(container, const AccountStorageScope.unsafe());
    expect((await _readSettings(container)).themeMode, 'system');
    expect((await _readTheme(container, expectedDark: true)).isDark, isTrue);

    await _setScope(container, AccountStorageScope.authenticated('A'));
    expect((await _readSettings(container)).themeMode, 'light');
    expect((await _readTheme(container, expectedDark: false)).isDark, isFalse);
  });

  test('same-user scope refresh preserves the current theme projection', () async {
    final ProviderContainer container = _container(_MemoryStore());
    addTearDown(container.dispose);

    await _setScope(container, AccountStorageScope.authenticated('A'));
    await container
        .read(settingsPreferencesProvider.notifier)
        .setThemeMode('light');
    container.invalidate(currentThemeProvider);
    await _readTheme(container, expectedDark: false);

    await _setScope(container, AccountStorageScope.authenticated('A'));
    expect((await _readSettings(container)).themeMode, 'light');
    expect((await _readTheme(container, expectedDark: false)).isDark, isFalse);
  });

  test('rapid provider scope changes settle the theme on C only', () async {
    final ProviderContainer container = _container(_MemoryStore());
    addTearDown(container.dispose);

    await _setScope(container, AccountStorageScope.authenticated('A'));
    await container
        .read(settingsPreferencesProvider.notifier)
        .setThemeMode('light');
    await _setScope(container, AccountStorageScope.authenticated('B'));
    await container
        .read(settingsPreferencesProvider.notifier)
        .setThemeMode('dark');
    await _setScope(container, AccountStorageScope.authenticated('C'));
    await container
        .read(settingsPreferencesProvider.notifier)
        .setThemeMode('light');
    container.invalidate(currentThemeProvider);

    expect((await _readSettings(container)).themeMode, 'light');
    expect((await _readTheme(container, expectedDark: false)).isDark, isFalse);
  });
}

Future<SettingsEntity> _readSettings(ProviderContainer container) async {
  final completer = Completer<SettingsEntity>();
  late ProviderSubscription<AsyncValue<SettingsEntity>> subscription;
  subscription = container.listen(settingsPreferencesProvider, (_, next) {
    if (next.hasValue && !completer.isCompleted) completer.complete(next.requireValue);
    if (next.hasError && !completer.isCompleted) completer.completeError(next.error!, next.stackTrace);
  }, fireImmediately: true);
  try { return await completer.future.timeout(const Duration(seconds: 3)); } finally { subscription.close(); }
}

Future<AppThemeEntity> _readTheme(
  ProviderContainer container, {
  required bool expectedDark,
}) async {
  await _flush();
  final completer = Completer<AppThemeEntity>();
  late ProviderSubscription<AsyncValue<AppThemeEntity>> subscription;
  subscription = container.listen(currentThemeProvider, (_, next) {
    if (next.hasValue &&
        next.requireValue.isDark == expectedDark &&
        !completer.isCompleted) {
      completer.complete(next.requireValue);
    }
    if (next.hasError && !completer.isCompleted) completer.completeError(next.error!, next.stackTrace);
  }, fireImmediately: true);
  try { return await completer.future.timeout(const Duration(seconds: 3)); } finally { subscription.close(); }
}

SettingsRepository _repository(_MemoryStore store, String userId) {
  return SettingsRepository(
    store,
    storageScope: AccountStorageScope.authenticated(userId),
  );
}

ProviderContainer _container(_MemoryStore store) {
  return ProviderContainer(
    overrides: [
      sharedPrefsStoreProvider.overrideWithValue(store),
      accountStorageScopeProvider.overrideWith(
        (Ref ref) => ref.watch(_scopeProvider),
      ),
      settingsRepositoryProvider.overrideWith(
        (Ref ref) => SettingsRepository(
          store,
          storageScope: ref.watch(accountStorageScopeProvider),
        ),
      ),
    ],
  );
}

Future<void> _setScope(
  ProviderContainer container,
  AccountStorageScope scope,
) async {
  container.read(_scopeProvider.notifier).set(scope);
  container.invalidate(settingsPreferencesProvider);
  await _readSettings(container);
  container.invalidate(currentThemeProvider);
  await _flush();
}

Future<void> _flush() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

class _ScopeController extends Notifier<AccountStorageScope> {
  @override
  AccountStorageScope build() => const AccountStorageScope.unsafe();

  void set(AccountStorageScope value) => state = value;
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
  Future<void> save(String key, String value) async {
    jsonDecode(value);
    values[key] = value;
  }
}

class _FailingStore extends _MemoryStore {
  final List<String> loadKeys = <String>[];
  bool failLoads = false;
  bool failSaves = false;

  @override
  String? load(String key) {
    loadKeys.add(key);
    if (failLoads) throw StateError('read failed');
    return super.load(key);
  }

  @override
  Future<void> save(String key, String value) async {
    if (failSaves) throw StateError('write failed');
    await super.save(key, value);
  }
}

class _Queue implements SyncQueueStoreContract {
  final List<SyncOperation> _operations = <SyncOperation>[];

  @override
  Future<void> enqueue(SyncOperation operation) async =>
      _operations.add(operation);

  @override
  Future<void> overwrite(List<SyncOperation> operations) async {
    _operations
      ..clear()
      ..addAll(operations);
  }

  @override
  Future<List<SyncOperation>> readAll() async =>
      List<SyncOperation>.from(_operations);

  @override
  Future<void> removeById(String operationId) async {
    _operations.removeWhere(
      (SyncOperation operation) => operation.operationId == operationId,
    );
  }

  @override
  Future<void> update(SyncOperation updated) async {
    final int index = _operations.indexWhere(
      (SyncOperation operation) => operation.operationId == updated.operationId,
    );
    if (index >= 0) _operations[index] = updated;
  }
}
