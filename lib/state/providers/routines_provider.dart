import 'package:fantastic_guacamole/domain/entities/routine_entity.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final routinesProvider =
    NotifierProvider<RoutinesNotifier, List<RoutineEntity>>(
      RoutinesNotifier.new,
    );

final routineProvider = routinesProvider;

class RoutinesNotifier extends Notifier<List<RoutineEntity>> {
  @override
  List<RoutineEntity> build() {
    return ref.read(getRoutinesUseCaseProvider).call();
  }

  Future<void> add(RoutineEntity routine) async {
    await ref.read(createRoutineUseCaseProvider).call(routine);
    state = [
      routine,
      ...state.where((RoutineEntity item) => item.id != routine.id),
    ];
  }

  Future<void> update(RoutineEntity routine) async {
    await ref.read(updateRoutineUseCaseProvider).call(routine);
    state = state
        .map((RoutineEntity item) => item.id == routine.id ? routine : item)
        .toList(growable: false);
  }

  Future<void> remove(String id) async {
    await ref.read(deleteRoutineUseCaseProvider).call(id);
    state = state
        .where((RoutineEntity item) => item.id != id)
        .toList(growable: false);
  }

  Future<void> saveAll(List<RoutineEntity> routines) async {
    await ref.read(saveRoutinesUseCaseProvider).call(routines);
    state = routines;
  }
}
