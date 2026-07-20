import 'dart:io';

import 'package:fantastic_guacamole/data/local/hive_storage.dart';
import 'package:fantastic_guacamole/data/repositories/goal_repository.dart';
import 'package:fantastic_guacamole/data/storage/hive_boxes.dart';
import 'package:fantastic_guacamole/data/storage/hive_service.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory tempDir;
  late HiveStorage<String> storage;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('goal_repository_test_');
    await Hive.close();
    Hive.init(tempDir.path);
    storage = HiveStorage<String>(HiveBoxes.goals, hive: _DirectHiveStore());
    await storage.open();
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('preserves concurrent goal saves', () async {
    final GoalRepository repository = GoalRepository(storage);

    await Future.wait(<Future<void>>[
      repository.saveGoal(
        GoalEntity(
          id: 'goal-1',
          title: 'One',
          createdAt: DateTime.utc(2026, 7, 17, 10),
        ),
      ),
      repository.saveGoal(
        GoalEntity(
          id: 'goal-2',
          title: 'Two',
          createdAt: DateTime.utc(2026, 7, 17, 11),
        ),
      ),
    ]);

    final List<GoalEntity> goals = repository.getGoals();
    expect(goals.map((GoalEntity goal) => goal.id).toSet(), <String>{
      'goal-1',
      'goal-2',
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