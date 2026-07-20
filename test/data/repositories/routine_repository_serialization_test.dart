import 'dart:io';

import 'package:fantastic_guacamole/data/local/hive_storage.dart';
import 'package:fantastic_guacamole/data/repositories/routine_repository.dart';
import 'package:fantastic_guacamole/data/storage/hive_boxes.dart';
import 'package:fantastic_guacamole/data/storage/hive_service.dart';
import 'package:fantastic_guacamole/domain/entities/routine_entity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory tempDir;
  late HiveStorage<String> storage;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('routine_repository_test_');
    await Hive.close();
    Hive.init(tempDir.path);
    storage = HiveStorage<String>(HiveBoxes.routines, hive: _DirectHiveStore());
    await storage.open();
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('preserves concurrent routine saves', () async {
    final RoutineRepository repository = RoutineRepository(storage);

    await Future.wait(<Future<void>>[
      repository.saveRoutine(
        RoutineEntity(
          id: 'routine-1',
          name: 'One',
          createdAt: DateTime.utc(2026, 7, 17, 10),
        ),
      ),
      repository.saveRoutine(
        RoutineEntity(
          id: 'routine-2',
          name: 'Two',
          createdAt: DateTime.utc(2026, 7, 17, 11),
        ),
      ),
    ]);

    final List<RoutineEntity> routines = repository.getRoutines();
    expect(routines.map((RoutineEntity routine) => routine.id).toSet(), <String>{
      'routine-1',
      'routine-2',
    });
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
  Box<T> box<T>(String key) => Hive.box<T>(key);

  @override
  Future<void> clearBox(String key) async {
    final Box<dynamic> box = Hive.isBoxOpen(key)
        ? Hive.box<dynamic>(key)
        : await Hive.openBox<dynamic>(key);
    await box.clear();
  }

  @override
  Future<void> closeBox(String key) async {
    if (Hive.isBoxOpen(key)) {
      await Hive.box<dynamic>(key).close();
    }
  }
}