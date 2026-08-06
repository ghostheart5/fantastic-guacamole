import 'package:fantastic_guacamole/data/repositories/habit_repository.dart'
    show HabitRecord;
import 'package:fantastic_guacamole/domain/interfaces/i_habit_repository.dart';
import 'package:fantastic_guacamole/domain/usecases/habit_usecases.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeHabitRepository implements IHabitRepository {
  List<HabitRecord> stored = const <HabitRecord>[];
  int saveCount = 0;

  @override
  Future<List<HabitRecord>> getHabits() async => stored;

  @override
  Future<void> saveHabits(List<HabitRecord> habits) async {
    saveCount++;
    stored = habits;
  }
}

HabitRecord _habit(String id, {String? title, bool active = true}) {
  return HabitRecord(id: id, title: title ?? 'Habit $id', active: active);
}

void main() {
  late _FakeHabitRepository repository;

  setUp(() => repository = _FakeHabitRepository());

  group('GetHabits', () {
    test('returns what the repository holds', () async {
      repository.stored = <HabitRecord>[_habit('a')];
      final List<HabitRecord> habits = await GetHabits(repository)();
      expect(habits.single.id, 'a');
    });
  });

  group('CreateHabit', () {
    test('adds a trimmed habit to the front and persists', () async {
      final List<HabitRecord> next = await CreateHabit(repository)(
        current: <HabitRecord>[_habit('existing')],
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
      final List<HabitRecord> current = <HabitRecord>[_habit('a')];
      final List<HabitRecord> next = await CreateHabit(
        repository,
      )(current: current, title: '   ');

      expect(next, same(current));
      expect(repository.saveCount, 0);
    });
  });

  group('ToggleHabit', () {
    test('flips only the targeted habit and persists', () async {
      final List<HabitRecord> next = await ToggleHabit(repository)(
        current: <HabitRecord>[
          _habit('a', active: true),
          _habit('b', active: true),
        ],
        id: 'a',
      );

      expect(next.firstWhere((HabitRecord h) => h.id == 'a').active, isFalse);
      expect(next.firstWhere((HabitRecord h) => h.id == 'b').active, isTrue);
      expect(repository.saveCount, 1);
    });

    test('toggles an inactive habit back to active', () async {
      final List<HabitRecord> next = await ToggleHabit(
        repository,
      )(current: <HabitRecord>[_habit('a', active: false)], id: 'a');

      expect(next.single.active, isTrue);
    });

    test('an unknown id changes nothing and does not save', () async {
      final List<HabitRecord> current = <HabitRecord>[_habit('a')];
      final List<HabitRecord> next = await ToggleHabit(
        repository,
      )(current: current, id: 'missing');

      expect(next, same(current));
      expect(repository.saveCount, 0);
    });
  });

  group('UpdateHabit', () {
    test('renames while preserving the active flag', () async {
      final List<HabitRecord> next = await UpdateHabit(repository)(
        current: <HabitRecord>[_habit('a', title: 'Old', active: false)],
        id: 'a',
        title: '  New name ',
      );

      expect(next.single.title, 'New name');
      expect(next.single.active, isFalse);
      expect(repository.saveCount, 1);
    });

    test('ignores blank titles and unknown ids', () async {
      final List<HabitRecord> current = <HabitRecord>[_habit('a')];

      expect(
        await UpdateHabit(repository)(current: current, id: 'a', title: '  '),
        same(current),
      );
      expect(
        await UpdateHabit(
          repository,
        )(current: current, id: 'nope', title: 'x'),
        same(current),
      );
      expect(repository.saveCount, 0);
    });
  });

  group('DeleteHabit', () {
    test('removes the habit and persists', () async {
      final List<HabitRecord> next = await DeleteHabit(
        repository,
      )(current: <HabitRecord>[_habit('a'), _habit('b')], id: 'a');

      expect(next.single.id, 'b');
      expect(repository.saveCount, 1);
    });

    test('an unknown id changes nothing and does not save', () async {
      final List<HabitRecord> current = <HabitRecord>[_habit('a')];
      expect(
        await DeleteHabit(repository)(current: current, id: 'missing'),
        same(current),
      );
      expect(repository.saveCount, 0);
    });
  });

  group('SaveHabits', () {
    test('bulk replaces the stored list', () async {
      final List<HabitRecord> replacement = <HabitRecord>[_habit('x')];
      final List<HabitRecord> next = await SaveHabits(repository)(replacement);

      expect(next, replacement);
      expect(repository.stored, replacement);
      expect(repository.saveCount, 1);
    });
  });
}
