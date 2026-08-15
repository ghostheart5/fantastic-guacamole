import 'package:fantastic_guacamole/data/adapters/habit_routine_compatibility.dart';
import 'package:fantastic_guacamole/data/repositories/habit_repository.dart';
import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/entities/routine_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_routine_repository.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/habits_provider.dart';
import 'package:fantastic_guacamole/state/providers/routines_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _accountProvider = NotifierProvider<_AccountNotifier, String?>(
  _AccountNotifier.new,
);

void main() {
  group('Habit-backed Routine compatibility', () {
    test('projects every lossless field with exhaustive cadence and status', () {
      final DateTime createdAt = DateTime.utc(2026, 1, 2, 3, 4);
      final DateTime updatedAt = DateTime.utc(2026, 2, 3, 4, 5);
      final List<(HabitCadence, RoutineCadence)> cadences =
          <(HabitCadence, RoutineCadence)>[
            (HabitCadence.daily, RoutineCadence.daily),
            (HabitCadence.weekly, RoutineCadence.weekly),
            (HabitCadence.monthly, RoutineCadence.monthly),
          ];
      final List<(HabitStatus, RoutineStatus)> statuses =
          <(HabitStatus, RoutineStatus)>[
            (HabitStatus.active, RoutineStatus.active),
            (HabitStatus.paused, RoutineStatus.paused),
            (HabitStatus.archived, RoutineStatus.archived),
          ];

      for (final (HabitCadence habitCadence, RoutineCadence routineCadence)
          in cadences) {
        for (final (HabitStatus habitStatus, RoutineStatus routineStatus)
            in statuses) {
          final RoutineEntity routine = routineFromHabitRecord(
            HabitRecord(
              id: 'habit-${habitCadence.name}-${habitStatus.name}',
              title: 'CANONICAL_HABIT',
              createdAt: createdAt,
              updatedAt: updatedAt,
              userId: 'account-a',
              description: 'canonical description',
              cadence: habitCadence,
              targetCount: 3,
              status: habitStatus,
            ),
          );

          expect(routine.id, 'habit-${habitCadence.name}-${habitStatus.name}');
          expect(routine.name, 'CANONICAL_HABIT');
          expect(routine.createdAt, createdAt);
          expect(routine.updatedAt, updatedAt);
          expect(routine.userId, 'account-a');
          expect(routine.description, 'canonical description');
          expect(routine.cadence, routineCadence);
          expect(routine.targetCount, 3);
          expect(routine.status, routineStatus);
          expect(routine.stepTaskIds, isEmpty);
        }
      }
    });

    test('current Routine reads are canonical, scoped, and never legacy',
        () async {
      final _ThrowingLegacyRoutineRepository legacy =
          _ThrowingLegacyRoutineRepository();
      final ProviderContainer container = ProviderContainer(
        overrides: [
          habitsProvider.overrideWith(_ScopedHabitsNotifier.new),
          domainRoutineRepositoryProvider.overrideWithValue(legacy),
        ],
      );
      addTearDown(container.dispose);

      final ProviderSubscription<AsyncValue<List<HabitRecord>>> listener =
          container.listen(habitsProvider, (_, _) {}, fireImmediately: true);
      addTearDown(listener.close);

      await _settle(container);
      expect(_routineTitles(container), <String>['A_CANONICAL_HABIT']);
      expect(
        container.read(getRoutinesUseCaseProvider).call().single.name,
        'A_CANONICAL_HABIT',
      );

      final getRoutinesForA = container.read(getRoutinesUseCaseProvider);
      container.read(_accountProvider.notifier).set('B');
      await _settle(container);
      expect(_routineTitles(container), <String>['B_CANONICAL_HABIT']);
      expect(
        container.read(getRoutinesUseCaseProvider).call().single.name,
        'B_CANONICAL_HABIT',
      );
      expect(getRoutinesForA.call().single.name, 'A_CANONICAL_HABIT');

      container.read(_accountProvider.notifier).set(null);
      await _settle(container);
      expect(_routineTitles(container), isEmpty);
      expect(container.read(getRoutinesUseCaseProvider).call(), isEmpty);

      container.read(_accountProvider.notifier).set('A');
      await _settle(container);
      expect(_routineTitles(container), <String>['A_CANONICAL_HABIT']);
      expect(legacy.reads, 0);
      expect(legacy.writes, 0);
    });
  });
}

Future<void> _settle(ProviderContainer container) async {
  await container.read(habitsProvider.future);
  await Future<void>.delayed(Duration.zero);
}

List<String> _routineTitles(ProviderContainer container) => container
    .read(routinesProvider)
    .map((RoutineEntity routine) => routine.name)
    .toList(growable: false);

class _ScopedHabitsNotifier extends HabitsNotifier {
  @override
  Future<List<HabitRecord>> build() async {
    final String? account = ref.watch(_accountProvider);
    if (account == null) return const <HabitRecord>[];
    return <HabitRecord>[
      HabitRecord(
        id: 'same-logical-habit',
        title: '${account}_CANONICAL_HABIT',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 2),
        userId: account,
        description: '${account}_DESCRIPTION',
        cadence: HabitCadence.weekly,
        targetCount: 2,
      ),
    ];
  }
}

class _AccountNotifier extends Notifier<String?> {
  @override
  String? build() => 'A';

  void set(String? account) {
    state = account;
  }
}

class _ThrowingLegacyRoutineRepository implements IRoutineRepository {
  int reads = 0;
  int writes = 0;

  @override
  List<RoutineEntity> getRoutines() {
    reads += 1;
    throw StateError('LEGACY_PRIVATE_ROUTINE must remain unread');
  }

  @override
  Future<void> deleteRoutine(String id) => _write();

  @override
  Future<void> saveRoutine(RoutineEntity routine) => _write();

  @override
  Future<void> saveRoutines(List<RoutineEntity> routines) => _write();

  Future<void> _write() async {
    writes += 1;
  }
}
