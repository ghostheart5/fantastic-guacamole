import 'package:fantastic_guacamole/domain/entities/habit_record.dart';

/// Contract for habit persistence.
///
/// Deliberately expressed in [HabitRecord], the shape habits are actually
/// stored in today. `HabitEntity` is the richer planned domain type; migrating
/// storage onto it would change the persisted format. This interface keeps
/// domain use cases independent from the concrete data repository.
abstract class IHabitRepository {
  Future<List<HabitRecord>> getHabits();

  Future<void> saveHabits(List<HabitRecord> habits);
}
