// Package imports.
import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/data/storage/hive_adapters.dart';
import 'package:hive_flutter/hive_flutter.dart';

abstract class HiveStore {
  Future<void> init();
  bool isBoxOpen(String key);
  Future<Box<T>> openBox<T>(String key);
  Box<T> box<T>(String key);
  Future<void> clearBox(String key);
  Future<void> closeBox(String key);
}

class HiveStoreAdapter implements HiveStore {
  const HiveStoreAdapter();

  @override
  Future<void> init() {
    return HiveService.init();
  }

  @override
  bool isBoxOpen(String key) {
    return Hive.isBoxOpen(key);
  }

  @override
  Future<Box<T>> openBox<T>(String key) async {
    await HiveService.init();
    if (Hive.isBoxOpen(key)) {
      return Hive.box<T>(key);
    }
    return Hive.openBox<T>(key);
  }

  @override
  Box<T> box<T>(String key) {
    if (!Hive.isBoxOpen(key)) {
      throw StateError('Hive box "$key" is not open.');
    }
    return Hive.box<T>(key);
  }

  @override
  Future<void> clearBox(String key) async {
    await HiveService.init();
    final bool wasOpen = Hive.isBoxOpen(key);
    final Box<dynamic> target = wasOpen
        ? Hive.box<dynamic>(key)
        : await Hive.openBox<dynamic>(key);
    await target.clear();
    if (!wasOpen) {
      await target.close();
    }
  }

  @override
  Future<void> closeBox(String key) {
    return HiveService.closeBox(key);
  }
}

class HiveService {
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;

    await Hive.initFlutter();
    HiveAdapters.registerAll();
    await HiveAdapters.openDefaultBoxes();

    _initialized = true;
    Logger.log('HiveService', 'Initialized');
  }

  static Future<Box<dynamic>> openBox(String key) async {
    await init();
    if (Hive.isBoxOpen(key)) {
      return Hive.box<dynamic>(key);
    }
    return Hive.openBox<dynamic>(key);
  }

  static Box<dynamic> box(String key) {
    if (!Hive.isBoxOpen(key)) {
      throw StateError(
        'Hive box "$key" is not open. Call HiveService.openBox($key) first.',
      );
    }
    return Hive.box<dynamic>(key);
  }

  static Future<void> closeBox(String key) async {
    if (Hive.isBoxOpen(key)) {
      await Hive.box<dynamic>(key).close();
    }
  }
}
