import 'dart:io';

import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/local/hive_storage.dart';
import 'package:fantastic_guacamole/data/repositories/goal_repository.dart';
import 'package:fantastic_guacamole/data/repositories/task_repository.dart';
import 'package:fantastic_guacamole/data/storage/hive_boxes.dart';
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

class _FailingHiveStore implements HiveStore {
  const _FailingHiveStore();

  @override
  Box<T> box<T>(String key) => throw StateError('injected read failure');
  @override
  Future<void> clearBox(String key) async {}
  @override
  Future<void> closeBox(String key) async {}
  @override
  Future<void> init() async {}
  @override
  bool isBoxOpen(String key) => false;
  @override
  Future<Box<T>> openBox<T>(String key) =>
      Future<Box<T>>.error(StateError('injected write failure'));
}

const _TestHiveStore _hive = _TestHiveStore();
HiveStorage<String> _storage(String base, AccountStorageScope scope) =>
    HiveStorage<String>(HiveBoxes.accountScoped(base, scope), hive: _hive);
TaskRepository _tasks(AccountStorageScope scope) =>
    TaskRepository(storage: _storage(HiveBoxes.tasks, scope));
GoalRepository _goals(AccountStorageScope scope) =>
    GoalRepository(_storage(HiveBoxes.goals, scope));
TaskEntity _task(String id, String title) =>
    TaskEntity(id: id, title: title, createdAt: DateTime.utc(2026, 8, 13));
GoalEntity _goal(String id, String title, {String? userId}) => GoalEntity(
  id: id,
  title: title,
  userId: userId,
  createdAt: DateTime.utc(2026, 8, 13),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final AccountStorageScope a = AccountStorageScope.authenticated('a/b');
  final AccountStorageScope b = AccountStorageScope.authenticated('a?b');
  setUpAll(
    () =>
        Hive.init(Directory.systemTemp.createTempSync('task-goal-scope-').path),
  );

  group('Task and Goal V2 account storage', () {
    test(
      'uses distinct V2 boxes for identities with a legacy V1 collision',
      () {
        expect(a.legacyV1Candidate, b.legacyV1Candidate);
        expect(
          HiveBoxes.accountScoped(HiveBoxes.tasks, a),
          isNot(HiveBoxes.accountScoped(HiveBoxes.tasks, b)),
        );
        expect(
          HiveBoxes.accountScoped(HiveBoxes.goals, a),
          isNot(HiveBoxes.accountScoped(HiveBoxes.goals, b)),
        );
        expect(
          HiveBoxes.isEncryptedBox(HiveBoxes.accountScoped(HiveBoxes.tasks, a)),
          isTrue,
        );
        expect(
          HiveBoxes.isEncryptedBox(HiveBoxes.accountScoped(HiveBoxes.goals, b)),
          isTrue,
        );
      },
    );

    test(
      'isolates task enumeration, identical IDs, deletion, and restart',
      () async {
        final TaskRepository aTasks = _tasks(a);
        final TaskRepository bTasks = _tasks(b);
        await aTasks.saveTask(_task('same-id', 'A task'));
        await bTasks.saveTask(_task('same-id', 'B task'));
        expect((await aTasks.getAllTasks()).single.title, 'A task');
        expect((await bTasks.getAllTasks()).single.title, 'B task');
        await aTasks.saveTask(_task('A-only', 'A only'));
        expect(
          (await bTasks.getAllTasks()).map((TaskEntity item) => item.id),
          isNot(contains('A-only')),
        );
        await aTasks.deleteTask('same-id');
        expect(await aTasks.getTaskById('same-id'), isNull);
        expect((await bTasks.getAllTasks()).single.title, 'B task');
        expect((await _tasks(a).getAllTasks()).single.id, 'A-only');
        expect((await _tasks(b).getAllTasks()).single.title, 'B task');
      },
    );

    test(
      'isolates goal aggregate, identical IDs, deletion, and restart',
      () async {
        final GoalRepository aGoals = _goals(a);
        final GoalRepository bGoals = _goals(b);
        await _storage(HiveBoxes.goals, a).open();
        await _storage(HiveBoxes.goals, b).open();
        await aGoals.saveGoal(_goal('same-id', 'A goal', userId: 'a/b'));
        await bGoals.saveGoal(_goal('same-id', 'B goal', userId: 'a?b'));
        expect(aGoals.getGoals().single.title, 'A goal');
        expect(bGoals.getGoals().single.title, 'B goal');
        await aGoals.deleteGoal('same-id');
        expect(aGoals.getGoals(), isEmpty);
        expect(bGoals.getGoals().single.title, 'B goal');
        expect(_goals(a).getGoals(), isEmpty);
        expect(_goals(b).getGoals().single.title, 'B goal');
      },
    );

    test('does not hydrate ambiguous global V1 task or goal state', () async {
      final AccountStorageScope legacyCandidate =
          AccountStorageScope.authenticated('legacy-owner-candidate');
      final HiveStorage<String> legacyTasks = HiveStorage<String>(
        HiveBoxes.tasks,
        hive: _hive,
      );
      final HiveStorage<String> legacyGoals = HiveStorage<String>(
        HiveBoxes.goals,
        hive: _hive,
      );
      await legacyTasks.put('legacy-task', '{"id":"legacy-task"}');
      await legacyGoals.put(
        'goals_v2',
        '[{"id":"legacy-goal","title":"legacy","createdAt":"2026-08-13T00:00:00.000Z","userId":"a/b"}]',
      );
      expect(await _tasks(legacyCandidate).getAllTasks(), isEmpty);
      await _storage(HiveBoxes.goals, legacyCandidate).open();
      expect(_goals(legacyCandidate).getGoals(), isEmpty);
      expect(legacyTasks.get('legacy-task'), isNotNull);
      expect(legacyGoals.get('goals_v2'), isNotNull);
    });

    test(
      'unsafe transitions cannot construct or write an active target',
      () async {
        const AccountStorageScope unsafe = AccountStorageScope.unsafe();
        expect(
          () => HiveBoxes.accountScoped(HiveBoxes.tasks, unsafe),
          throwsStateError,
        );
        await expectLater(
          TaskRepository.unavailable().saveTask(_task('blocked', 'blocked')),
          throwsA(isA<Object>()),
        );
        await expectLater(
          GoalRepository.unavailable().saveGoal(_goal('blocked', 'blocked')),
          throwsA(isA<Object>()),
        );
      },
    );

    test('scoped failures never fall back to global storage', () async {
      final HiveStorage<String> legacyTasks = HiveStorage<String>(
        HiveBoxes.tasks,
        hive: _hive,
      );
      final HiveStorage<String> legacyGoals = HiveStorage<String>(
        HiveBoxes.goals,
        hive: _hive,
      );
      await legacyTasks.put('legacy-preserved', '{"id":"legacy-preserved"}');
      await legacyGoals.put('goals_v2', '[]');
      final HiveStorage<String> failingTasks = HiveStorage<String>(
        HiveBoxes.accountScoped(HiveBoxes.tasks, a),
        hive: const _FailingHiveStore(),
      );
      final HiveStorage<String> failingGoals = HiveStorage<String>(
        HiveBoxes.accountScoped(HiveBoxes.goals, a),
        hive: const _FailingHiveStore(),
      );

      await expectLater(
        TaskRepository(
          storage: failingTasks,
        ).saveTask(_task('write-failure', 'write failure')),
        throwsA(isA<Object>()),
      );
      expect(
        () => GoalRepository(failingGoals).getGoals(),
        throwsA(isA<Object>()),
      );
      expect(legacyTasks.get('legacy-preserved'), isNotNull);
      expect(legacyGoals.get('goals_v2'), '[]');
    });
  });
}
