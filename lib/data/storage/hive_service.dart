// Package imports.
import 'dart:convert';
import 'dart:math';

import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/data/storage/hive_adapters.dart';
import 'package:fantastic_guacamole/data/storage/hive_boxes.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';

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
    return HiveService.openTypedBox<T>(key);
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
        : await HiveService.openBox(key);
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
  static SecureStore? _secureStore;
  static HiveAesCipher? _cipher;
  static const String cipherStoreKey = 'chronospark.hive.cipher.v1';

  static void configureSecureStore(SecureStore store) {
    _secureStore ??= store;
  }

  static Future<void> init({bool warmupBoxes = false}) async {
    if (_initialized) return;

    await Hive.initFlutter();
    HiveAdapters.registerAll();

    if (warmupBoxes) {
      final SecureStore? store = _secureStore;
      if (store != null) {
        _cipher = await _loadOrCreateCipher(store);
      }

      const Set<String> criticalBoxes = <String>{
        HiveBoxes.tasks,
        HiveBoxes.goals,
        HiveBoxes.habits,
        HiveBoxes.progression,
      };

      final Set<String> secondaryBoxes = HiveBoxes.encryptedBoxes.difference(
        criticalBoxes,
      );

      final List<Future<void>> warmupFutures = <Future<void>>[
        ...criticalBoxes.map((String box) => _openBoxWithTelemetry(box)),
        ...secondaryBoxes.map((String box) => _openBoxWithTelemetry(box)),
      ];

      await Future.wait(warmupFutures, eagerError: false);
    }

    _initialized = true;
    Logger.log('HiveService', 'Initialized');
  }

  static Future<Box<dynamic>> openBox(String key) async {
    await init();
    if (Hive.isBoxOpen(key)) {
      return Hive.box<dynamic>(key);
    }
    return _openBoxInternal<dynamic>(key);
  }

  static Future<Box<T>> openTypedBox<T>(String key) async {
    await init();
    if (Hive.isBoxOpen(key)) {
      return Hive.box<T>(key);
    }
    return _openBoxInternal<T>(key);
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

  static Future<Box<T>> _openBoxInternal<T>(String key) async {
    final HiveAesCipher? cipher = _shouldEncryptBox(key) ? _cipher : null;
    if (cipher == null) {
      return Hive.openBox<T>(key);
    }

    try {
      return await Hive.openBox<T>(key, encryptionCipher: cipher);
    } on Object catch (error) {
      // Migration-safe fallback for legacy unencrypted boxes.
      Logger.warn('Encrypted open failed for box "$key": $error');
      return Hive.openBox<T>(key);
    }
  }

  static bool _shouldEncryptBox(String key) {
    return HiveBoxes.isEncryptedBox(key);
  }

  static Future<void> _openBoxWithTelemetry(String box) async {
    if (Hive.isBoxOpen(box)) {
      return;
    }

    final Stopwatch boxStopwatch = Stopwatch()..start();
    debugPrint('CHRONOSPARK_HIVE_BOX_OPEN_START: $box');

    try {
      await _openBoxInternal<dynamic>(box).timeout(const Duration(seconds: 3));

      boxStopwatch.stop();
      debugPrint(
        'CHRONOSPARK_HIVE_BOX_OPEN_DONE: $box in ${boxStopwatch.elapsedMilliseconds}ms',
      );
    } on Object catch (error) {
      boxStopwatch.stop();
      debugPrint(
        'CHRONOSPARK_HIVE_BOX_OPEN_FAILED: $box in ${boxStopwatch.elapsedMilliseconds}ms: $error',
      );
      rethrow;
    }
  }

  static Future<HiveAesCipher> _loadOrCreateCipher(SecureStore store) async {
    final String? encoded = await store.readString(cipherStoreKey);
    if (encoded != null && encoded.trim().isNotEmpty) {
      try {
        final List<int> bytes = base64Decode(encoded);
        if (bytes.length == 32) {
          return HiveAesCipher(Uint8List.fromList(bytes));
        }
        Logger.warn(
          'Hive cipher payload had invalid length (${bytes.length}); regenerating.',
        );
      } on FormatException catch (error) {
        Logger.warn('Hive cipher payload was corrupted: $error');
      }

      await store.delete(cipherStoreKey);
    }

    final Random random = Random.secure();
    final Uint8List bytes = Uint8List.fromList(
      List<int>.generate(32, (_) => random.nextInt(256)),
    );
    await store.writeString(cipherStoreKey, base64Encode(bytes));
    return HiveAesCipher(bytes);
  }
}
