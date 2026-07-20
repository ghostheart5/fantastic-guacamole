import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/features/auth/data/datasources/secure_store_auth_local_data_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('clears corrupted cached session payload instead of throwing', () async {
    final SecureStore store = SecureStore(
      backend: InMemorySecureStoreBackend(),
    );
    const String sessionKey = 'auth.cached_session';
    await store.writeString(sessionKey, '{not-json');

    final SecureStoreAuthLocalDataSource source =
        SecureStoreAuthLocalDataSource(secureStore: store);

    final result = await source.getCachedSession();

    expect(result, isNull);
    expect(await store.readString(sessionKey), isNull);
  });
}
