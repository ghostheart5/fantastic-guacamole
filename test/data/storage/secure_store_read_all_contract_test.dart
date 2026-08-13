import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SecureStore.readAll', () {
    test('empty store returns an empty immutable snapshot', () async {
      final SecureStore store = SecureStore(
        backend: InMemorySecureStoreBackend(),
      );

      final Map<String, String> values = await store.readAll();

      expect(values, isEmpty);
      expect(() => values['new'] = 'value', throwsUnsupportedError);
    });

    test('returns multiple values without changing existing reads', () async {
      final SecureStore store = SecureStore(
        backend: InMemorySecureStoreBackend(),
      );
      await store.writeString('user.a', 'alpha');
      await store.writeString('user.b', 'beta');

      expect(await store.readAll(), <String, String>{
        'user.a': 'alpha',
        'user.b': 'beta',
      });
      expect(await store.readString('user.a'), 'alpha');
      expect(await store.readString('user.b'), 'beta');
    });

    test('snapshot mutation cannot affect stored values', () async {
      final SecureStore store = SecureStore(
        backend: InMemorySecureStoreBackend(),
      );
      await store.writeString('auth.cached_session', 'session-a');

      final Map<String, String> values = await store.readAll();
      expect(
        () => values.remove('auth.cached_session'),
        throwsUnsupportedError,
      );

      expect(await store.readString('auth.cached_session'), 'session-a');
    });

    test(
      'deleted entries are absent and repeated reads are non-mutating',
      () async {
        final SecureStore store = SecureStore(
          backend: InMemorySecureStoreBackend(),
        );
        await store.writeString('previous.user-a', 'remove');
        await store.writeString('hive.cipher', 'preserve');
        await store.delete('previous.user-a');

        final Map<String, String> first = await store.readAll();
        final Map<String, String> second = await store.readAll();

        expect(first, <String, String>{'hive.cipher': 'preserve'});
        expect(second, first);
        expect(await store.readString('hive.cipher'), 'preserve');
      },
    );
  });
}
