import 'dart:io';

import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/adapters/habit_routine_compatibility.dart';
import 'package:fantastic_guacamole/data/local/hive_storage.dart';
import 'package:fantastic_guacamole/data/repositories/habit_repository.dart';
import 'package:fantastic_guacamole/data/storage/hive_boxes.dart';
import 'package:fantastic_guacamole/data/storage/hive_service.dart';
import 'package:fantastic_guacamole/domain/entities/routine_entity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

const _HiveStore _hive = _HiveStore();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => Hive.init(Directory.systemTemp.createTempSync('routine-write-').path));

  test('lossless create and update delegate only to scoped canonical Habits',
      () async {
    final AccountStorageScope scope = AccountStorageScope.authenticated('write-a');
    final HabitRepository habits = _habits(scope);
    final HabitBackedRoutineWriteRepository adapter =
        HabitBackedRoutineWriteRepository(habits);
    final HiveStorage<String> legacy = HiveStorage<String>(HiveBoxes.routines, hive: _hive);
    const String sentinel = '["LEGACY_PRIVATE_ROUTINE"]';
    await legacy.put('routines_v1', sentinel);

    await adapter.saveRoutine(_routine('same', 'A_CREATED'));
    expect((await habits.getHabits()).single.title, 'A_CREATED');
    expect(await legacy.open().then((_) => legacy.get('routines_v1')), sentinel);

    await adapter.saveRoutine(_routine('same', 'A_UPDATED', status: RoutineStatus.paused));
    final HabitRecord updated = (await habits.getHabits()).single;
    expect(updated.title, 'A_UPDATED');
    expect(updated.status.name, 'paused');
    expect(await legacy.open().then((_) => legacy.get('routines_v1')), sentinel);
  });

  test('task-linked, delete, and bulk Routine writes fail closed', () async {
    final AccountStorageScope scope = AccountStorageScope.authenticated('write-closed');
    final HabitRepository habits = _habits(scope);
    final HabitBackedRoutineWriteRepository adapter = HabitBackedRoutineWriteRepository(habits);
    await habits.saveHabits(<HabitRecord>[
      const HabitRecord(id: 'keep', title: 'KEEP'),
    ]);
    final List<HabitRecord> before = await habits.getHabits();

    await expectLater(adapter.saveRoutine(_routine('task-linked', 'NOPE', taskIds: const <String>['task-1'])), throwsUnsupportedError);
    await expectLater(adapter.deleteRoutine('keep'), throwsUnsupportedError);
    await expectLater(adapter.saveRoutines(<RoutineEntity>[_routine('replacement', 'NOPE')]), throwsUnsupportedError);
    expect(await habits.getHabits(), hasLength(before.length));
    expect((await habits.getHabits()).single.title, 'KEEP');
  });

  test('A/B, signed-out, restart, and stale adapters remain scope-bound', () async {
    final AccountStorageScope a = AccountStorageScope.authenticated('write-account-a');
    final AccountStorageScope b = AccountStorageScope.authenticated('write-account-b');
    final HabitBackedRoutineWriteRepository adapterA = HabitBackedRoutineWriteRepository(_habits(a));
    final HabitBackedRoutineWriteRepository adapterB = HabitBackedRoutineWriteRepository(_habits(b));
    await adapterA.saveRoutine(_routine('same', 'A_VALUE'));
    await adapterB.saveRoutine(_routine('same', 'B_VALUE'));
    expect((await _habits(a).getHabits()).single.title, 'A_VALUE');
    expect((await _habits(b).getHabits()).single.title, 'B_VALUE');

    final HabitBackedRoutineWriteRepository recreatedA = HabitBackedRoutineWriteRepository(_habits(a));
    await recreatedA.saveRoutine(_routine('same', 'A_RESTARTED'));
    await adapterA.saveRoutine(_routine('stale-a', 'A_STALE'));
    expect((await _habits(a).getHabits()).map((item) => item.title), containsAll(<String>['A_RESTARTED', 'A_STALE']));
    expect((await _habits(b).getHabits()).single.title, 'B_VALUE');

    final HabitBackedRoutineWriteRepository signedOut =
        HabitBackedRoutineWriteRepository(HabitRepository.unavailable());
    await expectLater(signedOut.saveRoutine(_routine('signed-out', 'NOPE')), throwsA(isA<StateError>()));
  });

  test('canonical Habit write failure has no Routine fallback and retry succeeds', () async {
    final AccountStorageScope scope = AccountStorageScope.authenticated('write-retry');
    final HabitBackedRoutineWriteRepository failing = HabitBackedRoutineWriteRepository(
      HabitRepository(HiveStorage<String>(HiveBoxes.accountScoped(HiveBoxes.habits, scope), hive: const _FailingHiveStore())),
    );
    await expectLater(failing.saveRoutine(_routine('retry', 'FAIL')), throwsA(isA<StateError>()));
    final HabitBackedRoutineWriteRepository retry = HabitBackedRoutineWriteRepository(_habits(scope));
    await retry.saveRoutine(_routine('retry', 'SUCCESS'));
    expect((await _habits(scope).getHabits()).single.title, 'SUCCESS');
  });
}

HabitRepository _habits(AccountStorageScope scope) => HabitRepository(
  HiveStorage<String>(HiveBoxes.accountScoped(HiveBoxes.habits, scope), hive: _hive),
);

RoutineEntity _routine(String id, String title, {List<String> taskIds = const <String>[], RoutineStatus status = RoutineStatus.active}) => RoutineEntity(
  id: id,
  name: title,
  createdAt: DateTime.utc(2026, 8, 15),
  updatedAt: DateTime.utc(2026, 8, 16),
  userId: 'user',
  description: '$title description',
  cadence: RoutineCadence.weekly,
  targetCount: 2,
  status: status,
  stepTaskIds: taskIds,
);

class _HiveStore implements HiveStore {
  const _HiveStore();
  @override Box<T> box<T>(String key) => Hive.box<T>(key);
  @override Future<void> clearBox(String key) async => Hive.box<dynamic>(key).clear();
  @override Future<void> closeBox(String key) async => Hive.box<dynamic>(key).close();
  @override Future<void> init() async {}
  @override bool isBoxOpen(String key) => Hive.isBoxOpen(key);
  @override Future<Box<T>> openBox<T>(String key) => Hive.openBox<T>(key);
}

class _FailingHiveStore implements HiveStore {
  const _FailingHiveStore();
  @override Box<T> box<T>(String key) => throw StateError('Habit write failure');
  @override Future<void> clearBox(String key) async {}
  @override Future<void> closeBox(String key) async {}
  @override Future<void> init() async {}
  @override bool isBoxOpen(String key) => false;
  @override Future<Box<T>> openBox<T>(String key) => Future<Box<T>>.error(StateError('Habit write failure'));
}
