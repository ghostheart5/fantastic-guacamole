import 'dart:io';

import 'package:fantastic_guacamole/data/local/hive_storage.dart';
import 'package:fantastic_guacamole/data/storage/hive_adapters.dart';
import 'package:fantastic_guacamole/data/storage/hive_boxes.dart';
import 'package:fantastic_guacamole/data/storage/hive_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_service_test_');
    await Hive.close();
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('opens required boxes', () async {
    await HiveAdapters.openDefaultBoxes();

    expect(Hive.isBoxOpen(HiveBoxes.tasks), isTrue);
  });

  test('reads empty storage safely', () async {
    final storage = HiveStorage<String>(HiveBoxes.tasks, hive: _DirectHiveStore());
    await storage.open();

    expect(storage.getAll(), isEmpty);
    expect(storage.get('missing'), isNull);
  });

  test('writes task payload and reads it back', () async {
    final storage = HiveStorage<String>(HiveBoxes.tasks, hive: _DirectHiveStore());
    await storage.open();

    await storage.put('task-1', '{"id":"task-1","title":"Write"}');

    expect(storage.get('task-1'), '{"id":"task-1","title":"Write"}');
  });

  test('handles corrupted object/map shape by surfacing cast error', () async {
    const String corruptedBoxKey = 'corrupted_tasks_box';
    final dynamicBox = await Hive.openBox<dynamic>(corruptedBoxKey);
    await dynamicBox.put('bad-shape', 42);
    await dynamicBox.close();
    final storage = HiveStorage<String>(corruptedBoxKey, hive: _DirectHiveStore());
    await storage.open();

    expect(() => storage.getAll(), throwsA(anyOf(isA<TypeError>(), isA<Error>())));
  });

  test('closes and cleans boxes between tests', () async {
    final hive = _DirectHiveStore();
    final storage = HiveStorage<String>(HiveBoxes.tasks, hive: hive);
    await storage.open();
    await storage.put('task-1', 'value');

    await hive.clearBox(HiveBoxes.tasks);
    expect(storage.getAll(), isEmpty);

    await storage.close();
    expect(Hive.isBoxOpen(HiveBoxes.tasks), isFalse);
  });
}

class _DirectHiveStore implements HiveStore {
  @override
  Future<void> init() async {}

  @override
  bool isBoxOpen(String key) => Hive.isBoxOpen(key);

  @override
  Future<Box<T>> openBox<T>(String key) async {
    if (Hive.isBoxOpen(key)) {
      return Hive.box<T>(key);
    }
    return Hive.openBox<T>(key);
  }

  @override
  Box<T> box<T>(String key) {
    if (!Hive.isBoxOpen(key)) {
      throw StateError('Box not open: $key');
    }
    return Hive.box<T>(key);
  }

  @override
  Future<void> clearBox(String key) async {
    final box = Hive.isBoxOpen(key) ? Hive.box<String>(key) : await Hive.openBox<String>(key);
    await box.clear();
  }

  @override
  Future<void> closeBox(String key) async {
    if (Hive.isBoxOpen(key)) {
      await Hive.box<String>(key).close();
    }
  }
}
