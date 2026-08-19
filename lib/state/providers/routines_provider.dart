import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final routinesProvider = NotifierProvider<RoutinesNotifier, List<HabitEntity>>(
  RoutinesNotifier.new,
);

final routineProvider = routinesProvider;

class RoutinesNotifier extends Notifier<List<HabitEntity>> {
  @override
  List<HabitEntity> build() {
    return ref.read(getRoutinesUseCaseProvider).call();
  }

  Future<void> add(HabitEntity routine) async {
    await ref.read(createRoutineUseCaseProvider).call(routine);
    state = [
      routine,
      ...state.where((HabitEntity item) => item.id != routine.id),
    ];
  }

  Future<void> update(HabitEntity routine) async {
    await ref.read(updateRoutineUseCaseProvider).call(routine);
    state = state
        .map((HabitEntity item) => item.id == routine.id ? routine : item)
        .toList(growable: false);
  }

  Future<void> remove(String id) async {
    await ref.read(deleteRoutineUseCaseProvider).call(id);
    state = state
        .where((HabitEntity item) => item.id != id)
        .toList(growable: false);
  }

  Future<void> saveAll(List<HabitEntity> routines) async {
    await ref.read(saveRoutinesUseCaseProvider).call(routines);
    state = routines;
  }
}
