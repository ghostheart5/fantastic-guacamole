import 'package:fantastic_guacamole/data/repositories/habit_repository.dart';
import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/entities/routine_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_routine_repository.dart';

/// Read-only compatibility projection for legacy Routine consumers.
///
/// Routines no longer have an independent current-account read authority.
/// `stepTaskIds` deliberately projects to an empty list because canonical
/// Habits have no equivalent task-link field.
RoutineEntity routineFromHabitRecord(HabitRecord habit) {
  return RoutineEntity(
    id: habit.id,
    name: habit.title,
    createdAt: habit.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
    updatedAt: habit.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
    userId: habit.userId,
    description: habit.description,
    cadence: switch (habit.cadence) {
      HabitCadence.daily => RoutineCadence.daily,
      HabitCadence.weekly => RoutineCadence.weekly,
      HabitCadence.monthly => RoutineCadence.monthly,
    },
    targetCount: habit.targetCount,
    status: switch (habit.status) {
      HabitStatus.active => RoutineStatus.active,
      HabitStatus.paused => RoutineStatus.paused,
      HabitStatus.archived => RoutineStatus.archived,
    },
  );
}

/// Converts only lossless Routine compatibility fields back to the canonical
/// Habit definition. Task links have no Habit equivalent and must be rejected.
HabitRecord habitRecordFromRoutine(RoutineEntity routine) {
  if (routine.stepTaskIds.isNotEmpty) {
    throw UnsupportedError(
      'Routine compatibility cannot write stepTaskIds because Habits have no '
      'task-link equivalent.',
    );
  }
  return HabitRecord(
    id: routine.id,
    title: routine.name,
    createdAt: routine.createdAt,
    updatedAt: routine.updatedAt,
    userId: routine.userId,
    description: routine.description,
    cadence: switch (routine.cadence) {
      RoutineCadence.daily => HabitCadence.daily,
      RoutineCadence.weekly => HabitCadence.weekly,
      RoutineCadence.monthly => HabitCadence.monthly,
    },
    targetCount: routine.targetCount,
    status: switch (routine.status) {
      RoutineStatus.active => HabitStatus.active,
      RoutineStatus.paused => HabitStatus.paused,
      RoutineStatus.archived => HabitStatus.archived,
    },
  );
}

/// Supplies only the legacy read contract from canonical Habit snapshots.
/// Legacy Routine writes remain owned by the existing repository until B-4B.
class HabitBackedRoutineReadRepository implements IRoutineRepository {
  const HabitBackedRoutineReadRepository(this._habits);

  final List<HabitRecord> _habits;

  @override
  List<RoutineEntity> getRoutines() => _habits
      .map(routineFromHabitRecord)
      .toList(growable: false);

  @override
  Future<void> deleteRoutine(String id) => _readOnlyWrite();

  @override
  Future<void> saveRoutine(RoutineEntity routine) => _readOnlyWrite();

  @override
  Future<void> saveRoutines(List<RoutineEntity> routines) => _readOnlyWrite();

  Future<void> _readOnlyWrite() {
    return Future<void>.error(
      UnsupportedError(
        'Habit-backed Routine compatibility is read-only; use the legacy '
        'Routine write contract until B-4B.',
      ),
    );
  }
}

/// Compatibility write adapter. Only lossless create/update operations may
/// reach the canonical scoped Habit repository; delete and bulk replacement
/// remain intentionally unsupported until their Habit semantics are chosen.
class HabitBackedRoutineWriteRepository implements IRoutineRepository {
  HabitBackedRoutineWriteRepository(this._habits);

  final HabitRepository _habits;

  @override
  List<RoutineEntity> getRoutines() {
    throw UnsupportedError(
      'Use the Habit-backed getRoutines compatibility provider for reads.',
    );
  }

  @override
  Future<void> saveRoutine(RoutineEntity routine) async {
    final HabitRecord next = habitRecordFromRoutine(routine);
    final List<HabitRecord> current = await _habits.getHabits();
    final int existing = current.indexWhere(
      (HabitRecord habit) => habit.id == next.id,
    );
    final List<HabitRecord> updated = current.toList(growable: true);
    if (existing < 0) {
      updated.insert(0, next);
    } else {
      updated[existing] = next;
    }
    await _habits.saveHabits(updated);
  }

  @override
  Future<void> deleteRoutine(String id) => _unsupported('deleteRoutine');

  @override
  Future<void> saveRoutines(List<RoutineEntity> routines) =>
      _unsupported('saveRoutines');

  Future<void> _unsupported(String operation) {
    return Future<void>.error(
      UnsupportedError(
        '$operation is unsupported for Routine compatibility until canonical '
        'Habit deletion and collection-replacement semantics are selected.',
      ),
    );
  }
}
