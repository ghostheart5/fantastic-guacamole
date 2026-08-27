import 'dart:convert';
import 'dart:io';

import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/data/local/hive_storage.dart';
import 'package:fantastic_guacamole/data/repositories/goal_repository.dart';
import 'package:fantastic_guacamole/data/storage/hive_boxes.dart';
import 'package:fantastic_guacamole/data/storage/hive_service.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

/// Corrupted storage must not be silently indistinguishable from "the user has
/// no goals". The read still degrades to an empty list so the app stays usable,
/// but the corruption is flagged and the unreadable payload is preserved.
void main() {
  late Directory tempDir;
  late HiveStorage<String> storage;
  late GoalRepository repository;

  const String key = 'goals_v2';
  const String backupKey = 'goals_v2_corrupt_backup';

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('goal_repository_test_');
    await Hive.close();
    Hive.init(tempDir.path);
    storage = HiveStorage<String>(HiveBoxes.goals, hive: _DirectHiveStore());
    await storage.open();
    repository = GoalRepository(storage);
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  GoalEntity goal(String id) => GoalEntity(
    id: id,
    title: 'Goal $id',
    createdAt: DateTime.utc(2026, 7, 4),
  );

  test('genuinely empty storage is not flagged as corrupted', () {
    expect(repository.getGoals(), isEmpty);
    expect(repository.lastReadCorrupted, isFalse);
  });

  test('a valid payload round trips and is not flagged', () async {
    await repository.saveGoals(<GoalEntity>[goal('a'), goal('b')]);

    expect(repository.getGoals(), hasLength(2));
    expect(repository.lastReadCorrupted, isFalse);
  });

  test('completion state survives a real storage round trip', () async {
    await repository.saveGoal(
      goal('a').markCompleted(DateTime.utc(2026, 7, 6)),
    );

    final GoalEntity stored = repository.getGoals().single;
    expect(stored.isCompleted, isTrue);
    expect(stored.completedAt, DateTime.utc(2026, 7, 6));
  });

  test('a corrupted payload is flagged rather than read as empty', () async {
    await storage.put(key, 'this is not json');

    await Logger.withMutedErrors(() async {
      expect(repository.getGoals(), isEmpty);
    });

    expect(
      repository.lastReadCorrupted,
      isTrue,
      reason:
          'an empty result from a corrupted read must be distinguishable '
          'from a genuinely empty collection',
    );
  });

  test('a structurally wrong payload is also flagged', () async {
    await storage.put(key, jsonEncode(<String, dynamic>{'not': 'a list'}));

    await Logger.withMutedErrors(() async {
      expect(repository.getGoals(), isEmpty);
    });

    expect(repository.lastReadCorrupted, isTrue);
  });

  test(
    'the unreadable payload is quarantined before being overwritten',
    () async {
      const String corrupt = 'this is not json';
      await storage.put(key, corrupt);

      await Logger.withMutedErrors(() async {
        // Simulates the real data-loss chain: corrupt read -> empty list ->
        // user adds a goal -> save would overwrite the original.
        await repository.saveGoal(goal('new'));
      });

      expect(
        storage.get(backupKey),
        corrupt,
        reason: 'the original payload must remain recoverable',
      );
      expect(repository.getGoals().single.id, 'new');
    },
  );

  test('a normal save does not create a quarantine backup', () async {
    await repository.saveGoals(<GoalEntity>[goal('a')]);

    expect(storage.get(backupKey), isNull);
  });

  test('the corrupted flag clears after a successful read', () async {
    await storage.put(key, 'not json');
    await Logger.withMutedErrors(() async => repository.getGoals());
    expect(repository.lastReadCorrupted, isTrue);

    await Logger.withMutedErrors(() async {
      await repository.saveGoals(<GoalEntity>[goal('a')]);
    });
    repository.getGoals();

    expect(repository.lastReadCorrupted, isFalse);
  });

  test('concurrent saves do not lose either goal', () async {
    await Future.wait(<Future<void>>[
      repository.saveGoal(goal('first')),
      repository.saveGoal(goal('second')),
    ]);

    expect(
      repository.getGoals().map((GoalEntity item) => item.id),
      containsAll(<String>['first', 'second']),
    );
    expect(repository.getGoals(), hasLength(2));
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
    final Box<String> box = Hive.isBoxOpen(key)
        ? Hive.box<String>(key)
        : await Hive.openBox<String>(key);
    await box.clear();
  }

  @override
  Future<void> closeBox(String key) async {
    if (Hive.isBoxOpen(key)) {
      await Hive.box<String>(key).close();
    }
  }
}
