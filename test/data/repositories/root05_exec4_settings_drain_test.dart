import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/repositories/settings_repository.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/settings_entity.dart';
import 'package:flutter_test/flutter_test.dart';

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
  Future<void> save(String key, String value) async => values[key] = value;
}

void main() {
  test('R05-019 drains accepted settings work and gates later work', () async {
    final _MemoryStore store = _MemoryStore();
    final SettingsRepository repository = SettingsRepository(
      store,
      storageScope: AccountStorageScope.authenticated('drain-user'),
    );
    final Future<void> accepted = repository.saveSettings(
      const SettingsEntity(),
    );
    await repository.cancelAndDrain();
    await accepted;
    expect(
      store.values[SettingsRepository.canonicalStorageKeyForUser('drain-user')],
      isNotNull,
    );
    await expectLater(
      repository.saveSettings(const SettingsEntity(soundEnabled: false)),
      throwsA(isA<StateError>()),
    );
  });
}
