import 'package:fantastic_guacamole/data/repositories/firebase_supabase_bridge_repository.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('constructs with the public store dependency and retains it', () async {
    final _MemorySecureStoreBackend backend = _MemorySecureStoreBackend();
    final FirebaseSupabaseBridgeRepository bridge =
        FirebaseSupabaseBridgeRepository(store: SecureStore(backend: backend));

    await bridge.cacheFirebaseMessagingToken('token');

    expect(await bridge.readCachedFirebaseMessagingToken(), 'token');
    expect(backend.values['bridge.firebase_messaging_token'], 'token');
  });
}

class _MemorySecureStoreBackend implements SecureStoreBackend {
  final Map<String, String> values = <String, String>{};

  @override
  Future<void> delete({required String key}) async => values.remove(key);

  @override
  Future<void> deleteAll() async => values.clear();

  @override
  Future<String?> read({required String key}) async => values[key];

  @override
  Future<void> write({required String key, required String value}) async {
    values[key] = value;
  }
}
