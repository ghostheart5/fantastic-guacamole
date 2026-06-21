abstract class KeyValueStore {
  Future<void> putString(String key, String value);
  Future<String?> getString(String key);
}

class InMemoryKeyValueStore implements KeyValueStore {
  final Map<String, String> _store = <String, String>{};

  @override
  Future<String?> getString(String key) async => _store[key];

  @override
  Future<void> putString(String key, String value) async {
    _store[key] = value;
  }
}
