import 'dart:io';

import 'package:fantastic_guacamole/data/local/hive_storage.dart';
import 'package:fantastic_guacamole/data/repositories/goal_repository.dart';
import 'package:fantastic_guacamole/data/repositories/habit_repository.dart';
import 'package:fantastic_guacamole/data/repositories/task_repository.dart';
import 'package:fantastic_guacamole/data/storage/hive_service.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

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

HiveStorage<String> _storage(String key) =>
    HiveStorage<String>(key, hive: const _TestHiveStore());

TaskEntity _task(String id) =>
    TaskEntity(id: id, title: id, createdAt: DateTime.utc(2026, 8, 13));

GoalEntity _goal(String id) =>
    GoalEntity(id: id, title: id, createdAt: DateTime.utc(2026, 8, 13));

HabitRecord _habit(String id) =>
    HabitRecord(id: id, title: id, createdAt: DateTime.utc(2026, 8, 13));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    Hive.init(Directory.systemTemp.createTempSync('root05-exec1-').path);
  });

  group('Root-05 EXEC-1 repository drains', () {
    test('T01 TASK-DRAIN-H01 drains an accepted task write', () async {
      final HiveStorage<String> storage = _storage('task-drain-1');
      final TaskRepository repository = TaskRepository(storage: storage);

      final Future<void> accepted = repository.saveTask(_task('task-1'));
      await repository.cancelAndDrain();
      await accepted;

      expect(storage.get('task-1'), isNotNull);
    });

    test('T02 TASK-DRAIN-H02 serializes save and delete', () async {
      final HiveStorage<String> storage = _storage('task-drain-2');
      final TaskRepository repository = TaskRepository(storage: storage);

      await Future.wait(<Future<void>>[
        repository.saveTask(_task('task-2')),
        repository.deleteTask('task-2'),
      ]);

      expect(storage.get('task-2'), isNull);
    });

    test('T03 TASK-DRAIN-H03 rejects work admitted after drain', () async {
      final TaskRepository repository = TaskRepository(
        storage: _storage('task-drain-3'),
      );
      await repository.cancelAndDrain();

      await expectLater(
        repository.saveTask(_task('task-3')),
        throwsA(isA<StateError>()),
      );
    });

    test(
      'T04 TASK-DRAIN-H04 closes admission before queued action executes',
      () async {
        final TaskRepository repository = TaskRepository(
          storage: _storage('task-drain-4'),
        );
        await repository.cancelAndDrain();

        await expectLater(
          repository.deleteTask('task-4'),
          throwsA(isA<StateError>()),
        );
      },
    );

    test('T05 TASK-DRAIN-H05 keeps the drain repeat-safe', () async {
      final TaskRepository repository = TaskRepository(
        storage: _storage('task-drain-5'),
      );

      await repository.cancelAndDrain();
      await repository.cancelAndDrain();

      await expectLater(
        repository.saveTask(_task('task-5')),
        throwsA(isA<StateError>()),
      );
    });

    test('T06 HABIT-DRAIN-H01 drains an accepted habit write', () async {
      final HiveStorage<String> storage = _storage('habit-drain-1');
      final HabitRepository repository = HabitRepository(storage);

      final Future<void> accepted = repository.saveHabits(<HabitRecord>[
        _habit('habit-1'),
      ]);
      await repository.cancelAndDrain();
      await accepted;

      expect(storage.get('habit_records_v1'), isNotNull);
    });

    test('T07 HABIT-DRAIN-H02 serializes and gates habit saves', () async {
      final HiveStorage<String> storage = _storage('habit-drain-2');
      final HabitRepository repository = HabitRepository(storage);

      await repository.saveHabits(<HabitRecord>[_habit('habit-2')]);
      await repository.cancelAndDrain();

      await expectLater(
        repository.saveHabits(<HabitRecord>[_habit('habit-3')]),
        throwsA(isA<StateError>()),
      );
      expect(storage.get('habit_records_v1'), contains('habit-2'));
    });

    test('T08 GOAL-DRAIN-H01 drains an accepted goal write', () async {
      final HiveStorage<String> storage = _storage('goal-drain-1');
      final GoalRepository repository = GoalRepository(storage);
      await storage.open();

      final Future<void> accepted = repository.saveGoal(_goal('goal-1'));
      await repository.cancelAndDrain();
      await accepted;

      expect(storage.get('goals_v2'), contains('goal-1'));
    });

    test('T09 GOAL-DRAIN-H02 gates later goal writes', () async {
      final GoalRepository repository = GoalRepository(
        _storage('goal-drain-2'),
      );
      await repository.cancelAndDrain();

      await expectLater(
        repository.saveGoal(_goal('goal-2')),
        throwsA(isA<StateError>()),
      );
    });

    test('T10 GOAL-DRAIN-H03 keeps the goal tail repeat-safe', () async {
      final GoalRepository repository = GoalRepository(
        _storage('goal-drain-3'),
      );
      await repository.cancelAndDrain();
      await repository.cancelAndDrain();

      await expectLater(
        repository.deleteGoal('goal-3'),
        throwsA(isA<StateError>()),
      );
    });
  });
}
