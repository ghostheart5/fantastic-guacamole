import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';

/// CHRONOSPARK-CLASS: SHIPPING | Feature: Future automation
///
/// Bound to RoutineRepository.
abstract class IRoutineRepository {
  List<HabitEntity> getRoutines();
  Future<void> saveRoutine(HabitEntity routine);
  Future<void> saveRoutines(List<HabitEntity> routines);
  Future<void> deleteRoutine(String id);
}
