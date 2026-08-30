// CHRONOSPARK-CLASS: SHIPPING | Feature: Daily Rhythm occurrences
import 'package:fantastic_guacamole/domain/entities/habit_occurrence_entity.dart';

abstract interface class IHabitOccurrenceRepository {
  Future<List<HabitOccurrenceEntity>> load();
  Future<void> save(HabitOccurrenceEntity occurrence);
  Future<void> replaceSnapshot(List<HabitOccurrenceEntity> occurrences);
}
