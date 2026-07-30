import 'package:fantastic_guacamole/data/storage/hive_service.dart';
import 'package:hive/hive.dart';

/// ChronoSpark HiveStorage.
///
/// A typed-safe wrapper around Hive boxes.
///
/// HiveService opens shared app boxes as dynamic Hive boxes during startup.
/// This wrapper uses dynamic Hive boxes internally and casts values at the
/// boundary. This prevents Hive type conflicts when repositories request typed
/// access after startup has already opened the same box dynamically.
class HiveStorage<T> {
  HiveStorage(this.boxKey, {required this._hive});

  final String boxKey;
  final HiveStore _hive;

  Future<Box<dynamic>> _ensureOpen() async {
    if (_hive.isBoxOpen(boxKey)) {
      return _hive.box<dynamic>(boxKey);
    }

    return _hive.openBox<dynamic>(boxKey);
  }

  Future<Box<dynamic>> open() {
    return _ensureOpen();
  }

  Box<dynamic> box() {
    if (!_hive.isBoxOpen(boxKey)) {
      throw StateError(
        'Hive box "$boxKey" is not open. Call open() before using synchronous accessors.',
      );
    }

    return _hive.box<dynamic>(boxKey);
  }

  T? get(String key) {
    final Object? value = box().get(key);

    if (value == null) {
      return null;
    }

    if (value is T) {
      return value as T;
    }

    return null;
  }

  T getOrDefault(String key, T fallback) {
    return get(key) ?? fallback;
  }

  Map<dynamic, T> getAll() {
    final Map<dynamic, dynamic> raw = box().toMap();
    final Map<dynamic, T> typed = <dynamic, T>{};

    for (final MapEntry<dynamic, dynamic> entry in raw.entries) {
      final dynamic value = entry.value;

      if (value is! T) {
        throw StateError(
          'Hive box "$boxKey" contains a value with the wrong type at key "${entry.key}".',
        );
      }

      typed[entry.key] = value;
    }

    return typed;
  }

  Future<void> put(String key, T value) async {
    final Box<dynamic> target = await _ensureOpen();
    await target.put(key, value);
  }

  Future<void> putAll(Map<String, T> values) async {
    final Box<dynamic> target = await _ensureOpen();
    await target.putAll(values);
  }

  Future<void> delete(String key) async {
    final Box<dynamic> target = await _ensureOpen();
    await target.delete(key);
  }

  Future<void> clear() async {
    final Box<dynamic> target = await _ensureOpen();
    await target.clear();
  }

  Future<void> add(T value) async {
    final Box<dynamic> target = await _ensureOpen();
    await target.add(value);
  }

  Future<void> deleteAt(int index) async {
    final Box<dynamic> target = await _ensureOpen();
    await target.deleteAt(index);
  }

  Future<void> close() async {
    if (_hive.isBoxOpen(boxKey)) {
      await box().close();
    }
  }
}
