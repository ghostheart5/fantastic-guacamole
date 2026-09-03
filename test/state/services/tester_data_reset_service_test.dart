import 'package:fantastic_guacamole/core/data/account_data_registry.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_namespace.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/storage/hive_service.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/state/services/tester_data_reset_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  test('clears app data while preserving the Hive encryption key', () async {
    final _FakePreferences preferences = _FakePreferences();
    final _FakeHiveStore hive = _FakeHiveStore();
    final InMemorySecureStoreBackend secureBackend =
        InMemorySecureStoreBackend();
    final SecureStore secureStore = SecureStore(backend: secureBackend);

    await secureStore.writeString('hive_aes_key', 'keep-this-key');
    for (final String key in TesterDataResetService.secureKeys) {
      await secureStore.writeString(key, 'test-data');
    }

    final TesterDataResetService service = TesterDataResetService(
      preferences: preferences,
      hive: hive,
      secureStore: secureStore,
      scope: AccountStorageScope.authenticated('account-a'),
      legacyOwnership: LegacyScopeOwnership.provenOwned,
    );
    await service.reset();

    expect(preferences.didClear, isFalse);
    expect(hive.clearedBoxes, containsAll(TesterDataResetService.hiveBoxes));
    for (final String key in TesterDataResetService.secureKeys) {
      expect(await secureStore.readString(key), isNull);
    }
    expect(await secureStore.readString('hive_aes_key'), 'keep-this-key');
  });

  test(
    'reset of account B preserves account A legacy and scoped data',
    () async {
      final _FakePreferences preferences = _FakePreferences();
      final _FakePreferences sensitive = _FakePreferences();
      final _FakeHiveStore hive = _FakeHiveStore();
      final SecureStore secureStore = SecureStore(
        backend: InMemorySecureStoreBackend(),
      );
      final String namespaceA = AccountDataRegistry.accountNamespace(
        'account-a',
      );
      final String namespaceB = AccountDataRegistry.accountNamespace(
        'account-b',
      );
      await secureStore.writeString('identity_id', 'legacy-a');
      await secureStore.writeString(
        'learning_state_v2.$namespaceA',
        'private-a',
      );
      await secureStore.writeString(
        'learning_state_v2.$namespaceB',
        'private-b',
      );
      await preferences.save('notes_v1', 'legacy-a');
      await preferences.save('notes_v1.$namespaceA', 'private-a');
      await preferences.save('notes_v1.$namespaceB', 'private-b');
      await sensitive.save('memories_v1', 'legacy-a');
      await sensitive.save('governed_memories_v2.$namespaceA', 'private-a');
      await sensitive.save('governed_memories_v2.$namespaceB', 'private-b');

      final TesterDataResetService service = TesterDataResetService(
        preferences: preferences,
        sensitivePreferences: sensitive,
        hive: hive,
        secureStore: secureStore,
        scope: AccountStorageScope.authenticated('account-b'),
      );
      await service.reset();

      expect(await secureStore.readString('identity_id'), 'legacy-a');
      expect(
        await secureStore.readString('learning_state_v2.$namespaceA'),
        'private-a',
      );
      expect(
        await secureStore.readString('learning_state_v2.$namespaceB'),
        isNull,
      );
      expect(preferences.load('notes_v1'), 'legacy-a');
      expect(preferences.load('notes_v1.$namespaceA'), 'private-a');
      expect(preferences.load('notes_v1.$namespaceB'), isNull);
      expect(sensitive.load('memories_v1'), 'legacy-a');
      expect(sensitive.load('governed_memories_v2.$namespaceA'), 'private-a');
      expect(sensitive.load('governed_memories_v2.$namespaceB'), isNull);
      expect(hive.clearedBoxes, contains('tasks_box.$namespaceB'));
      expect(hive.clearedBoxes, isNot(contains('tasks_box')));
      expect(hive.clearedBoxes, isNot(contains('tasks_box.$namespaceA')));
      expect(preferences.didClear, isFalse);
      expect(sensitive.didClear, isFalse);
    },
  );
}

class _FakePreferences implements SharedPrefsStore, EnumerableSharedPrefsStore {
  bool didClear = false;
  final Map<String, String> values = <String, String>{};

  @override
  Future<void> clear() async {
    didClear = true;
  }

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<void> init() async {}

  @override
  String? load(String key) => values[key];

  @override
  Future<void> save(String key, String value) async => values[key] = value;

  @override
  Future<Set<String>> keys() async => values.keys.toSet();
}

class _FakeHiveStore implements HiveStore {
  final List<String> clearedBoxes = <String>[];

  @override
  Box<T> box<T>(String key) {
    throw UnimplementedError();
  }

  @override
  Future<void> clearBox(String key) async {
    clearedBoxes.add(key);
  }

  @override
  Future<void> closeBox(String key) async {}

  @override
  Future<void> init() async {}

  @override
  bool isBoxOpen(String key) => false;

  @override
  Future<Box<T>> openBox<T>(String key) {
    throw UnimplementedError();
  }
}
