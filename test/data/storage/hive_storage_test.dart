import 'package:fantastic_guacamole/data/storage/hive_boxes.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HiveService', () {
    test('critical box names are valid and encrypted set is consistent', () {
      expect(HiveBoxes.tasks, isNotEmpty);
      expect(HiveBoxes.goals, isNotEmpty);
      expect(HiveBoxes.progression, isNotEmpty);
      expect(HiveBoxes.encryptedBoxes.contains(HiveBoxes.tasks), isTrue);
    });

    test('secure store wrapper round-trips values', () async {
      final store = SecureStore(backend: InMemorySecureStoreBackend());
      await store.writeString('key', 'value');
      expect(await store.readString('key'), 'value');
      await store.delete('key');
      expect(await store.readString('key'), isNull);
    });
  });
}
