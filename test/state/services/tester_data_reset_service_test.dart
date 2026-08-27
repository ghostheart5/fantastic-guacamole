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
    );
    await service.reset();

    expect(preferences.didClear, isTrue);
    expect(hive.clearedBoxes, containsAll(TesterDataResetService.hiveBoxes));
    for (final String key in TesterDataResetService.secureKeys) {
      expect(await secureStore.readString(key), isNull);
    }
    expect(await secureStore.readString('hive_aes_key'), 'keep-this-key');
  });
}

class _FakePreferences implements SharedPrefsStore {
  bool didClear = false;

  @override
  Future<void> clear() async {
    didClear = true;
  }

  @override
  Future<void> delete(String key) async {}

  @override
  Future<void> init() async {}

  @override
  String? load(String key) => null;

  @override
  Future<void> save(String key, String value) async {}
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
