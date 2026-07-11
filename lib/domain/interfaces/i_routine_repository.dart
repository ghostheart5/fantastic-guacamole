import 'package:fantastic_guacamole/domain/entities/routine_entity.dart';

abstract class IRoutineRepository {
  List<RoutineEntity> getRoutines();
  Future<void> saveRoutine(RoutineEntity routine);
  Future<void> saveRoutines(List<RoutineEntity> routines);
  Future<void> deleteRoutine(String id);
}
