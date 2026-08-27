import 'package:fantastic_guacamole/data/storage/storage_keys.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all storage keys are non-empty', () {
    const keys = <String>[
      StorageKeys.credentials,
      StorageKeys.session,
      StorageKeys.identity,
      StorageKeys.notifications,
      StorageKeys.theme,
      StorageKeys.settings,
      StorageKeys.storageVersion,
    ];

    for (final key in keys) {
      expect(key.trim(), isNotEmpty);
    }
  });

  test('box key constants are unique', () {
    const boxKeys = <String>[
      StorageKeys.credentials,
      StorageKeys.session,
      StorageKeys.identity,
      StorageKeys.notifications,
      StorageKeys.theme,
      StorageKeys.settings,
    ];

    expect(boxKeys.toSet().length, boxKeys.length);
  });

  test('storageVersion key is not reused as box key', () {
    const boxKeys = <String>{
      StorageKeys.credentials,
      StorageKeys.session,
      StorageKeys.identity,
      StorageKeys.notifications,
      StorageKeys.theme,
      StorageKeys.settings,
    };

    expect(boxKeys.contains(StorageKeys.storageVersion), isFalse);
  });
}
