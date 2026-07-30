import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class SecureStoreBackend {
  Future<String?> read({required String key});
  Future<void> write({required String key, required String value});
  Future<void> delete({required String key});
  Future<void> deleteAll();
}

class RealSecureStoreBackend implements SecureStoreBackend {
  RealSecureStoreBackend({required this._storage});

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read({required String key}) {
    return _storage.read(key: key);
  }

  @override
  Future<void> write({required String key, required String value}) {
    return _storage.write(key: key, value: value);
  }

  @override
  Future<void> delete({required String key}) {
    return _storage.delete(key: key);
  }

  @override
  Future<void> deleteAll() {
    return _storage.deleteAll();
  }
}

class InMemorySecureStoreBackend implements SecureStoreBackend {
  final Map<String, String> _memory = <String, String>{};

  @override
  Future<String?> read({required String key}) async {
    return _memory[key];
  }

  @override
  Future<void> write({required String key, required String value}) async {
    _memory[key] = value;
  }

  @override
  Future<void> delete({required String key}) async {
    _memory.remove(key);
  }

  @override
  Future<void> deleteAll() async {
    _memory.clear();
  }
}

class SecureStore {
  SecureStore({required SecureStoreBackend backend}) : this._(backend);

  SecureStore._(this._backend);

  final SecureStoreBackend _backend;

  Future<String?> readString(String key) {
    return _backend.read(key: key);
  }

  Future<void> writeString(String key, String value) {
    return _backend.write(key: key, value: value);
  }

  Future<void> delete(String key) {
    return _backend.delete(key: key);
  }

  Future<bool?> readBool(String key) async {
    final String? value = await _backend.read(key: key);
    if (value == null) {
      return null;
    }
    if (value == 'true') {
      return true;
    }
    if (value == 'false') {
      return false;
    }
    return null;
  }

  Future<void> writeBool(String key, bool value) {
    return _backend.write(key: key, value: value ? 'true' : 'false');
  }

  Future<double?> readDouble(String key) async {
    final String? value = await _backend.read(key: key);
    if (value == null) {
      return null;
    }
    return double.tryParse(value);
  }

  Future<void> writeDouble(String key, double value) {
    return _backend.write(key: key, value: value.toString());
  }

  Future<void> deleteAll() {
    return _backend.deleteAll();
  }
}
