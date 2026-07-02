import 'package:fantastic_guacamole/data/storage/secure_store.dart';

class IdentityRepository {
  IdentityRepository(this._store);

  final SecureStore _store;

  static const _key = 'identity_id';

  Future<String?> getIdentityId() => _store.readString(_key);

  Future<void> saveIdentityId(String id) => _store.writeString(_key, id);
}
