import 'package:fantastic_guacamole/data/storage/storage_keys.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StorageKeys', () {
    test('all storage box keys are unique and end with _box', () {
      final List<String> boxKeys = <String>[
        StorageKeys.credentials,
        StorageKeys.session,
        StorageKeys.identity,
        StorageKeys.notifications,
        StorageKeys.theme,
        StorageKeys.settings,
      ];

      expect(boxKeys.toSet().length, boxKeys.length);
      expect(boxKeys.every((String key) => key.endsWith('_box')), isTrue);
    });

    test('storage version key is stable and not a box key', () {
      expect(StorageKeys.storageVersion, 'storage_version');
      expect(StorageKeys.storageVersion.endsWith('_box'), isFalse);
    });
  });
}
