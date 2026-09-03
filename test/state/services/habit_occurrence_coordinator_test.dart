import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/repositories/habit_occurrence_repository.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/decision_outcome_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_decision_outcome_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_habit_repository.dart';
import 'package:fantastic_guacamole/state/services/habit_occurrence_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'records one idempotent occurrence and outcome per cadence slot',
    () async {
      final _HabitRepository habits = _HabitRepository(<HabitEntity>[
        HabitEntity(
          id: 'habit-1',
          title: 'Evening reset',
          createdAt: DateTime.utc(2026, 8, 1),
          cadence: HabitCadence.daily,
        ),
      ]);
      final _MemoryPrefs prefs = _MemoryPrefs();
      final _OutcomeRepository outcomes = _OutcomeRepository();
      final HabitOccurrenceCoordinator coordinator = HabitOccurrenceCoordinator(
        scope: AccountStorageScope.authenticated('account-a'),
        habitRepository: habits,
        occurrenceRepository: HabitOccurrenceRepository(
          prefs,
          AccountStorageScope.authenticated('account-a'),
        ),
        outcomeRepository: outcomes,
        clock: () => DateTime.utc(2026, 8, 30, 20),
      );

      final HabitOccurrenceResult first = await coordinator.complete('habit-1');
      final HabitOccurrenceResult replay = await coordinator.complete(
        'habit-1',
      );
      final HabitOccurrenceResult conflict = await coordinator.skip('habit-1');

      expect(first.mutation, HabitOccurrenceMutation.applied);
      expect(replay.mutation, HabitOccurrenceMutation.idempotent);
      expect(conflict.mutation, HabitOccurrenceMutation.conflict);
      expect(outcomes.values, hasLength(1));
      expect(outcomes.values.single.kind, DecisionOutcomeKind.completed);
      expect(habits.values.single.active, isTrue);
    },
  );

  test('fails closed without an authenticated account scope', () async {
    final HabitOccurrenceCoordinator coordinator = HabitOccurrenceCoordinator(
      scope: const AccountStorageScope.signedOut(),
      habitRepository: _HabitRepository(const <HabitEntity>[]),
      occurrenceRepository: HabitOccurrenceRepository(
        _MemoryPrefs(),
        const AccountStorageScope.signedOut(),
      ),
      outcomeRepository: _OutcomeRepository(),
    );

    await expectLater(
      () => coordinator.complete('habit-1'),
      throwsA(isA<StateError>()),
    );
  });

  test(
    'learning pause keeps the occurrence but omits learning outcome',
    () async {
      final _OutcomeRepository outcomes = _OutcomeRepository();
      final HabitOccurrenceCoordinator coordinator = HabitOccurrenceCoordinator(
        scope: AccountStorageScope.authenticated('account-a'),
        habitRepository: _HabitRepository(<HabitEntity>[
          HabitEntity(
            id: 'habit-1',
            title: 'Evening reset',
            createdAt: DateTime.utc(2026, 8, 1),
            cadence: HabitCadence.daily,
          ),
        ]),
        occurrenceRepository: HabitOccurrenceRepository(
          _MemoryPrefs(),
          AccountStorageScope.authenticated('account-a'),
        ),
        outcomeRepository: outcomes,
        learningPaused: () async => true,
        clock: () => DateTime.utc(2026, 8, 30, 20),
      );

      final HabitOccurrenceResult result = await coordinator.complete(
        'habit-1',
      );
      expect(result.mutation, HabitOccurrenceMutation.applied);
      expect(outcomes.values, isEmpty);
    },
  );
}

class _HabitRepository implements IHabitRepository {
  _HabitRepository(this.values);

  List<HabitEntity> values;

  @override
  Future<List<HabitEntity>> getHabits() async => List<HabitEntity>.of(values);

  @override
  Future<void> saveHabits(List<HabitEntity> habits) async {
    values = List<HabitEntity>.of(habits);
  }
}

class _OutcomeRepository implements IDecisionOutcomeRepository {
  final List<DecisionOutcomeEntity> values = <DecisionOutcomeEntity>[];

  @override
  Future<List<DecisionOutcomeEntity>> load() async => values;

  @override
  Future<void> record(DecisionOutcomeEntity outcome) async {
    if (!values.any((DecisionOutcomeEntity value) => value.id == outcome.id)) {
      values.add(outcome);
    }
  }
}

class _MemoryPrefs implements SharedPrefsStore {
  final Map<String, String> values = <String, String>{};

  @override
  Future<void> init() async {}

  @override
  String? load(String key) => values[key];

  @override
  Future<void> save(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<void> clear() async => values.clear();
}
