abstract class StorageService {
  Future<void> save(String key, String value);
  Future<String?> read(String key);
  Future<void> delete(String key);
  Future<void> clear();
  Future<bool> contains(String key);
  Future<void> saveAll(Map<String, String> values);
  Future<Map<String, String>> readAll();
}
