import 'package:fantastic_guacamole/data/adapters/habit_routine_compatibility.dart';
import 'package:fantastic_guacamole/data/repositories/habit_repository.dart';
import 'package:fantastic_guacamole/domain/entities/routine_entity.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/habits_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final routinesProvider =
    NotifierProvider<RoutinesNotifier, List<RoutineEntity>>(
      RoutinesNotifier.new,
    );

// Habit-semantics alias over legacy routines provider.
final habitsFromRoutinesProvider = routinesProvider;

@Deprecated('Use habitsFromRoutinesProvider for habit-semantics access.')
final routineProvider = routinesProvider;

class RoutinesNotifier extends Notifier<List<RoutineEntity>> {
  @override
  List<RoutineEntity> build() {
    final AsyncValue<List<HabitRecord>> habitState = ref.watch(habitsProvider);
    final List<HabitRecord> habits = switch (habitState) {
      AsyncData<List<HabitRecord>>(:final value) => value,
      _ => const <HabitRecord>[],
    };
    return habits.map(routineFromHabitRecord).toList(growable: false);
  }

  Future<void> add(RoutineEntity routine) async {
    await ref.read(createRoutineUseCaseProvider).call(routine);
    await _refreshHabitBackedRead();
  }

  Future<void> update(RoutineEntity routine) async {
    await ref.read(updateRoutineUseCaseProvider).call(routine);
    await _refreshHabitBackedRead();
  }

  Future<void> remove(String id) async {
    await ref.read(deleteRoutineUseCaseProvider).call(id);
  }

  Future<void> saveAll(List<RoutineEntity> routines) async {
    await ref.read(saveRoutinesUseCaseProvider).call(routines);
  }

  Future<void> _refreshHabitBackedRead() async {
    ref.invalidate(habitsProvider);
    await ref.read(habitsProvider.future);
  }

  Future<void> addHabit(RoutineEntity habit) {
    return add(habit);
  }

  Future<void> updateHabit(RoutineEntity habit) {
    return update(habit);
  }

  Future<void> removeHabit(String id) {
    return remove(id);
  }

  Future<void> saveAllHabits(List<RoutineEntity> habits) {
    return saveAll(habits);
  }
}
