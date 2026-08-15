import 'dart:io';

import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/local/hive_storage.dart';
import 'package:fantastic_guacamole/data/repositories/habit_occurrence_repository.dart';
import 'package:fantastic_guacamole/data/storage/hive_boxes.dart';
import 'package:fantastic_guacamole/data/storage/hive_service.dart';
import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_occurrence_entity.dart';
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

const _Hive _hive = _Hive();

HabitOccurrenceRepository _repository(AccountStorageScope scope) =>
    HabitOccurrenceRepository(
      HiveStorage<String>(
        HiveBoxes.accountScoped(HiveBoxes.habitOccurrences, scope),
        hive: _hive,
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final AccountStorageScope a = AccountStorageScope.authenticated('habit-a');
  final AccountStorageScope b = AccountStorageScope.authenticated('habit-b');

  setUpAll(
    () => Hive.init(
      Directory.systemTemp.createTempSync('habit-occurrence-').path,
    ),
  );

  test('period keys are local, deterministic, and boundary-safe', () {
    final DateTime sunday = DateTime(2026, 1, 4, 23, 59);
    final DateTime monday = DateTime(2026, 1, 5);
    expect(
      HabitOccurrencePeriodKey.forDate(HabitCadence.daily, sunday),
      '2026-01-04',
    );
    expect(
      HabitOccurrencePeriodKey.forDate(HabitCadence.weekly, sunday),
      'W-2025-12-29',
    );
    expect(
      HabitOccurrencePeriodKey.forDate(HabitCadence.weekly, monday),
      'W-2026-01-05',
    );
    expect(
      HabitOccurrencePeriodKey.forDate(HabitCadence.monthly, monday),
      '2026-01',
    );
  });

  test(
    'complete, duplicate, conflicts, and multi-target ordinals are canonical',
    () async {
      final HabitOccurrenceRepository repository = _repository(a);
      const String period = '2026-08-15';
      expect(
        await repository.completeOccurrence(
          habitId: 'h',
          periodKey: period,
          ordinal: 1,
          targetCount: 3,
        ),
        HabitOccurrenceMutation.inserted,
      );
      expect(
        await repository.completeOccurrence(
          habitId: 'h',
          periodKey: period,
          ordinal: 1,
          targetCount: 3,
        ),
        HabitOccurrenceMutation.idempotent,
      );
      expect(
        await repository.skipOccurrence(
          habitId: 'h',
          periodKey: period,
          ordinal: 1,
          targetCount: 3,
        ),
        HabitOccurrenceMutation.conflict,
      );
      expect(
        await repository.completeOccurrence(
          habitId: 'h',
          periodKey: period,
          ordinal: 2,
          targetCount: 3,
        ),
        HabitOccurrenceMutation.inserted,
      );
      expect(
        await repository.completeOccurrence(
          habitId: 'h',
          periodKey: period,
          ordinal: 3,
          targetCount: 3,
        ),
        HabitOccurrenceMutation.inserted,
      );
      expect(
        await repository.completeOccurrence(
          habitId: 'h',
          periodKey: period,
          ordinal: 4,
          targetCount: 3,
        ),
        HabitOccurrenceMutation.exhausted,
      );
      expect(
        (await repository.listOccurrencesForPeriod('h', period)).length,
        3,
      );
    },
  );

  test('skip is idempotent and cannot later become complete', () async {
    final HabitOccurrenceRepository repository = _repository(a);
    expect(
      await repository.skipOccurrence(
        habitId: 'skip',
        periodKey: '2026-08-16',
        ordinal: 1,
        targetCount: 1,
      ),
      HabitOccurrenceMutation.inserted,
    );
    expect(
      await repository.skipOccurrence(
        habitId: 'skip',
        periodKey: '2026-08-16',
        ordinal: 1,
        targetCount: 1,
      ),
      HabitOccurrenceMutation.idempotent,
    );
    expect(
      await repository.completeOccurrence(
        habitId: 'skip',
        periodKey: '2026-08-16',
        ordinal: 1,
        targetCount: 1,
      ),
      HabitOccurrenceMutation.conflict,
    );
  });

  test('period status and streak derive without persisting misses', () {
    const HabitOccurrence complete = HabitOccurrence(
      habitId: 'h',
      periodKey: 'p',
      ordinal: 1,
      status: HabitOccurrenceStatus.completed,
    );
    const HabitOccurrence skipped = HabitOccurrence(
      habitId: 'h',
      periodKey: 'p',
      ordinal: 1,
      status: HabitOccurrenceStatus.skipped,
    );
    expect(
      deriveHabitPeriodStatus(
        targetCount: 1,
        occurrences: <HabitOccurrence>[complete],
        isCurrentPeriod: false,
      ),
      HabitPeriodStatus.completed,
    );
    expect(
      deriveHabitPeriodStatus(
        targetCount: 1,
        occurrences: <HabitOccurrence>[skipped],
        isCurrentPeriod: false,
      ),
      HabitPeriodStatus.skipped,
    );
    expect(
      deriveHabitPeriodStatus(
        targetCount: 3,
        occurrences: <HabitOccurrence>[complete],
        isCurrentPeriod: true,
      ),
      HabitPeriodStatus.open,
    );
    expect(
      deriveHabitPeriodStatus(
        targetCount: 3,
        occurrences: <HabitOccurrence>[complete],
        isCurrentPeriod: false,
      ),
      HabitPeriodStatus.missed,
    );
    final HabitStreak streak = deriveHabitStreak(<HabitPeriodStatus>[
      HabitPeriodStatus.completed,
      HabitPeriodStatus.completed,
      HabitPeriodStatus.skipped,
      HabitPeriodStatus.completed,
      HabitPeriodStatus.missed,
      HabitPeriodStatus.completed,
    ]);
    expect(streak.currentStreak, 1);
    expect(streak.longestStreak, 3);
  });

  test(
    'account scopes, restart, legacy global storage, and unsafe storage are isolated',
    () async {
      final HabitOccurrenceRepository aRepository = _repository(a);
      await aRepository.completeOccurrence(
        habitId: 'same',
        periodKey: '2026-08-17',
        ordinal: 1,
        targetCount: 1,
      );
      expect(await _repository(b).listOccurrencesForHabit('same'), isEmpty);
      await _repository(b).skipOccurrence(
        habitId: 'same',
        periodKey: '2026-08-17',
        ordinal: 1,
        targetCount: 1,
      );
      expect(
        (await _repository(a).listOccurrencesForHabit('same')).single.status,
        HabitOccurrenceStatus.completed,
      );
      expect(
        (await _repository(b).listOccurrencesForHabit('same')).single.status,
        HabitOccurrenceStatus.skipped,
      );
      await HiveStorage<String>(HiveBoxes.habitOccurrences, hive: _hive).put(
        HabitOccurrenceRepository.persistenceKey,
        '[{"habitId":"legacy","periodKey":"old","ordinal":1,"status":"completed"}]',
      );
      expect(
        await _repository(
          AccountStorageScope.authenticated('new-account'),
        ).listOccurrencesForHabit('legacy'),
        isEmpty,
      );
      await expectLater(
        HabitOccurrenceRepository.unavailable().listOccurrencesForHabit('same'),
        throwsA(isA<StateError>()),
      );
    },
  );
}
