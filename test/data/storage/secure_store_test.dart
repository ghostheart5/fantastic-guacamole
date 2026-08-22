import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late InMemorySecureStoreBackend backend;
  late SecureStore store;

  setUp(() {
    backend = InMemorySecureStoreBackend();
    store = SecureStore(backend: backend);
  });

  test('string values can be written, read, and deleted', () async {
    expect(await store.readString('name'), isNull);

    await store.writeString('name', 'ChronoSpark');
    expect(await store.readString('name'), 'ChronoSpark');

    await store.delete('name');
    expect(await store.readString('name'), isNull);
  });

  test(
    'boolean values preserve true, false, missing, and invalid states',
    () async {
      expect(await store.readBool('enabled'), isNull);

      await store.writeBool('enabled', true);
      expect(await store.readBool('enabled'), isTrue);

      await store.writeBool('enabled', false);
      expect(await store.readBool('enabled'), isFalse);

      await backend.write(key: 'enabled', value: 'not-a-boolean');
      expect(await store.readBool('enabled'), isNull);
    },
  );

  test('double values preserve numbers and reject invalid text', () async {
    expect(await store.readDouble('score'), isNull);

    await store.writeDouble('score', 12.5);
    expect(await store.readDouble('score'), 12.5);

    await backend.write(key: 'score', value: 'not-a-number');
    expect(await store.readDouble('score'), isNull);
  });

  test('deleteAll clears every stored value', () async {
    await store.writeString('first', 'one');
    await store.writeString('second', 'two');

    await store.deleteAll();

    expect(await store.readString('first'), isNull);
    expect(await store.readString('second'), isNull);
  });
}
