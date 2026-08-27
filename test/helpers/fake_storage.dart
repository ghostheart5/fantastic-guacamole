class FakeStorage {
  final Map<String, Object?> _store = <String, Object?>{};

  Object? read(String key) => _store[key];

  void write(String key, Object? value) {
    _store[key] = value;
  }

  void remove(String key) {
    _store.remove(key);
  }

  void clear() {
    _store.clear();
  }

  bool contains(String key) => _store.containsKey(key);

  int get length => _store.length;
}
