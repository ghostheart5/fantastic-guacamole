import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SecureStore', () {
    test('stores and reloads booleans and doubles', () async {
      final store = SecureStore(backend: InMemorySecureStoreBackend());
      await store.writeBool('flag', true);
      await store.writeDouble('ratio', 0.75);
      expect(await store.readBool('flag'), isTrue);
      expect(await store.readDouble('ratio'), 0.75);
    });

    test('deleteAll clears all values', () async {
      final store = SecureStore(backend: InMemorySecureStoreBackend());
      await store.writeString('a', '1');
      await store.deleteAll();
      expect(await store.readString('a'), isNull);
    });
  });
}
