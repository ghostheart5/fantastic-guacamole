import 'dart:io';

import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/local/hive_storage.dart';
import 'package:fantastic_guacamole/data/repositories/habit_repository.dart';
import 'package:fantastic_guacamole/data/repositories/plan_repository.dart';
import 'package:fantastic_guacamole/data/storage/hive_boxes.dart';
import 'package:fantastic_guacamole/data/storage/hive_service.dart';
import 'package:fantastic_guacamole/domain/entities/time_block.dart';
import 'package:fantastic_guacamole/domain/entities/plan_entity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

class _Hive implements HiveStore {
  const _Hive();
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

class _FailHive implements HiveStore {
  const _FailHive();
  @override
  Box<T> box<T>(String key) => throw StateError('read failure');
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
      Future<Box<T>>.error(StateError('write failure'));
}

const _Hive _hive = _Hive();
HiveStorage<String> _store(
  String base,
  AccountStorageScope scope, [
  HiveStore hive = _hive,
]) => HiveStorage<String>(HiveBoxes.accountScoped(base, scope), hive: hive);
HabitRepository _habits(AccountStorageScope scope) =>
    HabitRepository(_store(HiveBoxes.habits, scope));
PlanRepository _plans(AccountStorageScope scope) =>
    PlanRepository(_store(HiveBoxes.dailyPlans, scope));
HabitRecord _habit(String id, String title) =>
    HabitRecord(id: id, title: title, createdAt: DateTime.utc(2026, 8, 13));
PlanEntity _plan(String id, DateTime date, String title) => PlanEntity(
  id: id,
  date: date,
  blocks: <TimeBlock>[
    TimeBlock(
      id: id,
      taskId: id,
      title: title,
      start: date,
      end: date.add(const Duration(minutes: 30)),
    ),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final AccountStorageScope a = AccountStorageScope.authenticated('a/b');
  final AccountStorageScope b = AccountStorageScope.authenticated('a?b');
  final DateTime date = DateTime.utc(2026, 8, 13);
  setUpAll(
    () => Hive.init(
      Directory.systemTemp.createTempSync('habit-plan-scope-').path,
    ),
  );
  test('isolates Habit A/B, identical IDs, restart, and legacy', () async {
    await _habits(a).saveHabits(<HabitRecord>[_habit('same', 'A')]);
    await _habits(b).saveHabits(<HabitRecord>[_habit('same', 'B')]);
    expect((await _habits(a).getHabits()).single.title, 'A');
    expect((await _habits(b).getHabits()).single.title, 'B');
    await HiveStorage<String>(
      HiveBoxes.habits,
      hive: _hive,
    ).put('habit_records_v1', '[{"id":"legacy","title":"legacy"}]');
    expect(
      (await _habits(AccountStorageScope.authenticated('legacy')).getHabits()),
      isEmpty,
    );
  });
  test('isolates Plan A/B, same date key, restart, and legacy', () async {
    await _plans(a).savePlan(_plan('same', date, 'A'));
    await _plans(b).savePlan(_plan('same', date, 'B'));
    expect((await _plans(a).getPlan(date))!.blocks.single.title, 'A');
    expect((await _plans(b).getPlan(date))!.blocks.single.title, 'B');
    await HiveStorage<String>(
      HiveBoxes.dailyPlans,
      hive: _hive,
    ).put('2026-08-13', '{}');
    expect(
      await _plans(
        AccountStorageScope.authenticated('legacy-plan'),
      ).getPlan(date),
      isNull,
    );
  });
  test(
    'unsafe and storage failures cannot fall back to global storage',
    () async {
      const AccountStorageScope unsafe = AccountStorageScope.unsafe();
      expect(
        () => HiveBoxes.accountScoped(HiveBoxes.habits, unsafe),
        throwsStateError,
      );
      await expectLater(
        HabitRepository.unavailable().saveHabits(<HabitRecord>[
          _habit('x', 'x'),
        ]),
        throwsA(isA<Object>()),
      );
      await expectLater(
        PlanRepository.unavailable().savePlan(_plan('x', date, 'x')),
        throwsA(isA<Object>()),
      );
      await expectLater(
        HabitRepository(
          _store(HiveBoxes.habits, a, const _FailHive()),
        ).saveHabits(<HabitRecord>[_habit('x', 'x')]),
        throwsA(isA<Object>()),
      );
      await expectLater(
        PlanRepository(
          _store(HiveBoxes.dailyPlans, a, const _FailHive()),
        ).savePlan(_plan('x', date, 'x')),
        throwsA(isA<Object>()),
      );
    },
  );
  test(
    'drained A plan instance cannot survive into a new B instance',
    () async {
      final PlanRepository aPlans = _plans(a);
      await aPlans.savePlan(_plan('A', date, 'A'));
      await aPlans.cancelAndDrain();
      await expectLater(
        aPlans.savePlan(_plan('stale-A', date, 'stale A')),
        throwsA(isA<StateError>()),
      );
      final PlanRepository bPlans = _plans(b);
      expect((await bPlans.getPlan(date))!.blocks.single.title, 'B');
    },
  );
}
