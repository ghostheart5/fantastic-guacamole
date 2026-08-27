import 'package:fantastic_guacamole/data/storage/hive_service.dart';
import 'package:hive/hive.dart';

/// ChronoSpark HiveStorage
/// A typed, safe wrapper around Hive boxes.
/// Provides:
/// - safe read/write
/// - typed access
/// - existence checks
/// - lifecycle management
/// - non-null guarantees
class HiveStorage<T> {
  final String boxKey;
  final HiveStore _hive;

  HiveStorage(this.boxKey, {required this._hive});

  // ------------------------------------------------------------
  // BOX ACCESS
  // ------------------------------------------------------------

  Future<Box<T>> _ensureOpen() async {
    return _hive.openBox<T>(boxKey);
  }

  Future<Box<T>> open() async {
    return _ensureOpen();
  }

  Box<T> box() {
    if (!_hive.isBoxOpen(boxKey)) {
      throw StateError(
        'Hive box "$boxKey" is not open. Call open() before using synchronous accessors.',
      );
    }
    return _hive.box<T>(boxKey);
  }

  // ------------------------------------------------------------
  // READ
  // ------------------------------------------------------------

  T? get(String key) {
    return box().get(key);
  }

  T getOrDefault(String key, T fallback) {
    return box().get(key) ?? fallback;
  }

  Map<dynamic, T> getAll() {
    return box().toMap().cast<dynamic, T>();
  }

  // ------------------------------------------------------------
  // WRITE
  // ------------------------------------------------------------

  Future<void> put(String key, T value) async {
    final target = await _ensureOpen();
    await target.put(key, value);
  }

  Future<void> putAll(Map<String, T> values) async {
    final target = await _ensureOpen();
    await target.putAll(values);
  }

  Future<void> delete(String key) async {
    final target = await _ensureOpen();
    await target.delete(key);
  }

  Future<void> clear() async {
    final target = await _ensureOpen();
    await target.clear();
  }

  // ------------------------------------------------------------
  // LIST OPERATIONS
  // ------------------------------------------------------------

  Future<void> add(T value) async {
    final target = await _ensureOpen();
    await target.add(value);
  }

  Future<void> deleteAt(int index) async {
    final target = await _ensureOpen();
    await target.deleteAt(index);
  }

  // ------------------------------------------------------------
  // LIFECYCLE
  // ------------------------------------------------------------

  Future<void> close() async {
    if (_hive.isBoxOpen(boxKey)) {
      await box().close();
    }
  }
}
