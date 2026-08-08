import 'package:fantastic_guacamole/domain/entities/routine_entity.dart';

/// CHRONOSPARK-CLASS: SHIPPING | Feature: Future automation
///
/// Bound to RoutineRepository.
abstract class IRoutineRepository {
  List<RoutineEntity> getRoutines();
  Future<void> saveRoutine(RoutineEntity routine);
  Future<void> saveRoutines(List<RoutineEntity> routines);
  Future<void> deleteRoutine(String id);
}
