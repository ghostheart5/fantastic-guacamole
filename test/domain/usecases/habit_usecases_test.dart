import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_occurrence_entity.dart';
import 'package:fantastic_guacamole/domain/planning/rhythm_planning_context.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_habit_repository.dart';
import 'package:fantastic_guacamole/domain/usecases/habit_usecases.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeHabitRepository implements IHabitRepository {
  List<HabitEntity> stored = const <HabitEntity>[];
  int saveCount = 0;

  @override
  Future<List<HabitEntity>> getHabits() async => stored;

  @override
  Future<void> saveHabits(List<HabitEntity> habits) async {
    saveCount++;
    stored = habits;
  }
}

HabitEntity _habit(String id, {String? title, bool active = true}) {
  return HabitEntity(
    id: id,
    title: title ?? 'Habit $id',
    createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    status: active ? HabitStatus.active : HabitStatus.paused,
  );
}

void main() {
  late _FakeHabitRepository repository;

  setUp(() => repository = _FakeHabitRepository());

  test(
    'frequency editing persists target and preserves identity and creation',
    () async {
      final original = _habit('frequency');
      final next = await UpdateHabit(repository)(
        current: [original],
        id: original.id,
        title: original.title,
        cadence: HabitCadence.weekly,
        targetCount: 3,
      );
      expect(next.single.id, original.id);
      expect(next.single.createdAt, original.createdAt);
      expect(repository.stored.single.cadence, HabitCadence.weekly);
      expect(repository.stored.single.targetCount, 3);
      await expectLater(
        UpdateHabit(repository)(
          current: next,
          id: original.id,
          title: original.title,
          targetCount: 0,
        ),
        throwsArgumentError,
      );
      expect(repository.saveCount, 1);
    },
  );

  test(
    'changed definition does not inherit completed daily or prior target',
    () async {
      final now = DateTime(2026, 10, 5, 18);
      final original = HabitEntity(
        id: 'revision',
        title: 'Synthetic rhythm',
        createdAt: now,
      );
      final outcomes = [
        HabitOccurrenceEntity(
          habitId: original.id,
          occurrenceKey: RhythmPlanningContext.occurrenceKey(original, now),
          operationId: 'first',
          outcome: HabitOccurrenceOutcome.completed,
          recordedAt: now,
        ),
      ];
      expect(
        RhythmPlanningContext.build([original], outcomes, now).single.status,
        RhythmPeriodStatus.completed,
      );
      var next = await UpdateHabit(repository)(
        current: [original],
        id: original.id,
        title: original.title,
        cadence: HabitCadence.weekly,
        targetCount: 2,
      );
      expect(
        RhythmPlanningContext.build(next, outcomes, now).single.status,
        RhythmPeriodStatus.unrecorded,
      );
      expect(next.single.frequencyRevision, 1);
      next = await UpdateHabit(repository)(
        current: next,
        id: original.id,
        title: original.title,
        cadence: HabitCadence.daily,
        targetCount: 1,
      );
      expect(
        RhythmPlanningContext.build(next, outcomes, now).single.status,
        RhythmPeriodStatus.unrecorded,
      );
      expect(next.single.frequencyRevision, 2);
      final restored = HabitEntity.fromJson(next.single.toJson());
      expect(restored.frequencyRevision, 2);
      expect(restored.frequencyStartedAt, next.single.frequencyStartedAt);
      final renamed = (await UpdateHabit(repository)(
        current: next,
        id: original.id,
        title: 'Renamed',
      )).single;
      expect(renamed.frequencyStartedAt, restored.frequencyStartedAt);
      expect(outcomes, hasLength(1));
    },
  );

  test(
    'revised rhythm import rejects malformed revision and missing start',
    () {
      final legacy = _habit('import').toJson();
      expect(HabitEntity.fromJson(legacy).frequencyRevision, 0);
      expect(
        () => HabitEntity.fromJson({...legacy, 'frequencyRevision': -1}),
        throwsFormatException,
      );
      expect(
        () => HabitEntity.fromJson({...legacy, 'frequencyRevision': '1'}),
        throwsFormatException,
      );
      expect(
        () => HabitEntity.fromJson({...legacy, 'frequencyRevision': 1}),
        throwsFormatException,
      );
      expect(
        () => HabitEntity.fromJson({
          ...legacy,
          'frequencyRevision': 1,
          'frequencyStartedAt': 'invalid',
        }),
        throwsFormatException,
      );
    },
  );
  group('GetHabits', () {
    test('returns what the repository holds', () async {
      repository.stored = <HabitEntity>[_habit('a')];
      final List<HabitEntity> habits = await GetHabits(repository)();
      expect(habits.single.id, 'a');
    });
  });

  group('CreateHabit', () {
    test('adds a trimmed habit to the front and persists', () async {
      final List<HabitEntity> next = await CreateHabit(repository)(
        current: <HabitEntity>[_habit('existing')],
        title: '  Morning run  ',
        id: 'new-id',
      );

      expect(next.first.id, 'new-id');
      expect(next.first.title, 'Morning run');
      expect(next.first.active, isTrue);
      expect(next.last.id, 'existing');
      expect(repository.saveCount, 1);
      expect(repository.stored, next);
    });

    test('rejects a blank title without saving', () async {
      final List<HabitEntity> current = <HabitEntity>[_habit('a')];
      final List<HabitEntity> next = await CreateHabit(repository)(
        current: current,
        title: '   ',
      );

      expect(next, same(current));
      expect(repository.saveCount, 0);
    });
  });

  group('ToggleHabit', () {
    test('flips only the targeted habit and persists', () async {
      final List<HabitEntity> next = await ToggleHabit(repository)(
        current: <HabitEntity>[
          _habit('a', active: true),
          _habit('b', active: true),
        ],
        id: 'a',
      );

      expect(next.firstWhere((HabitEntity h) => h.id == 'a').active, isFalse);
      expect(next.firstWhere((HabitEntity h) => h.id == 'b').active, isTrue);
      expect(repository.saveCount, 1);
    });

    test('toggles an inactive habit back to active', () async {
      final List<HabitEntity> next = await ToggleHabit(repository)(
        current: <HabitEntity>[_habit('a', active: false)],
        id: 'a',
      );

      expect(next.single.active, isTrue);
    });

    test('an unknown id changes nothing and does not save', () async {
      final List<HabitEntity> current = <HabitEntity>[_habit('a')];
      final List<HabitEntity> next = await ToggleHabit(repository)(
        current: current,
        id: 'missing',
      );

      expect(next, same(current));
      expect(repository.saveCount, 0);
    });
  });

  group('UpdateHabit', () {
    test('renames while preserving the active flag', () async {
      final List<HabitEntity> next = await UpdateHabit(repository)(
        current: <HabitEntity>[_habit('a', title: 'Old', active: false)],
        id: 'a',
        title: '  New name ',
      );

      expect(next.single.title, 'New name');
      expect(next.single.active, isFalse);
      expect(repository.saveCount, 1);
    });

    test('ignores blank titles and unknown ids', () async {
      final List<HabitEntity> current = <HabitEntity>[_habit('a')];

      expect(
        await UpdateHabit(repository)(current: current, id: 'a', title: '  '),
        same(current),
      );
      expect(
        await UpdateHabit(repository)(current: current, id: 'nope', title: 'x'),
        same(current),
      );
      expect(repository.saveCount, 0);
    });
  });

  group('DeleteHabit', () {
    test('removes the habit and persists', () async {
      final List<HabitEntity> next = await DeleteHabit(repository)(
        current: <HabitEntity>[_habit('a'), _habit('b')],
        id: 'a',
      );

      expect(next.single.id, 'b');
      expect(repository.saveCount, 1);
    });

    test('an unknown id changes nothing and does not save', () async {
      final List<HabitEntity> current = <HabitEntity>[_habit('a')];
      expect(
        await DeleteHabit(repository)(current: current, id: 'missing'),
        same(current),
      );
      expect(repository.saveCount, 0);
    });
  });

  group('SaveHabits', () {
    test('bulk replaces the stored list', () async {
      final List<HabitEntity> replacement = <HabitEntity>[_habit('x')];
      final List<HabitEntity> next = await SaveHabits(repository)(replacement);

      expect(next, replacement);
      expect(repository.stored, replacement);
      expect(repository.saveCount, 1);
    });
  });
}
