// CHRONOSPARK-CLASS: SHIPPING | Feature: Daily Rhythm
import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';

/// Contract for habit persistence.
///
/// Existing `habit_records_v1` payloads remain readable through
/// [HabitEntity.fromJson].
abstract class IHabitRepository {
  Future<List<HabitEntity>> getHabits();

  Future<void> saveHabits(List<HabitEntity> habits);
}
