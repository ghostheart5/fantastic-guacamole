import 'dart:io';

import 'package:fantastic_guacamole/data/storage/hive_service.dart';
import 'package:hive/hive.dart';

class RealHiveTestFixture {
  RealHiveTestFixture._(this.directory);

  final Directory directory;
  final HiveStore hiveStore = const _TestHiveStore();

  static Future<RealHiveTestFixture> create() async {
    final Directory directory = await Directory.systemTemp.createTemp(
      'fantastic-guacamole-sync-queue-',
    );
    Hive.init(directory.path);
    return RealHiveTestFixture._(directory);
  }

  Future<void> dispose() async {
    await Hive.close();
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }
}

class _TestHiveStore implements HiveStore {
  const _TestHiveStore();

  @override
  Box<T> box<T>(String key) => Hive.box<T>(key);

  @override
  Future<void> clearBox(String key) async => Hive.box<dynamic>(key).clear();

  @override
  Future<void> closeBox(String key) async => Hive.box<dynamic>(key).close();

  @override
  Future<void> init() async {}

  @override
  bool isBoxOpen(String key) => Hive.isBoxOpen(key);

  @override
  Future<Box<T>> openBox<T>(String key) => Hive.openBox<T>(key);
}
