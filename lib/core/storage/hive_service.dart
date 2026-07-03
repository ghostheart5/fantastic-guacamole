import 'dart:convert';
import 'dart:math';

import 'package:encrypt/encrypt.dart';
import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/core/storage/secure_hive_adapter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';

abstract class HiveStore {
  Future<void> init();
  bool isBoxOpen(String key);
  Future<Box<T>> openBox<T>(String key);
  Box<T> box<T>(String key);
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
  Future<void> closeBox(String key) {
    return HiveService.closeBox(key);
  }
}

class HiveService {
  static bool _initialized = false;

  static const String _keyStorageKey = 'hive_aes_key';

  static Future<void> init() async {
    if (_initialized) return;

    await Hive.initFlutter();

    const FlutterSecureStorage secureStorage = FlutterSecureStorage();
    String? keyBase64 = await secureStorage.read(key: _keyStorageKey);
    if (keyBase64 == null) {
      final Random rng = Random.secure();
      final List<int> keyBytes = List<int>.generate(
        32,
        (_) => rng.nextInt(256),
      );
      keyBase64 = base64Encode(keyBytes);
      await secureStorage.write(key: _keyStorageKey, value: keyBase64);
    }

    const int secureAdapterTypeId = 42;
    if (!Hive.isAdapterRegistered(secureAdapterTypeId)) {
      Hive.registerAdapter(SecureHiveAdapter(Key.fromBase64(keyBase64)));
    }

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
