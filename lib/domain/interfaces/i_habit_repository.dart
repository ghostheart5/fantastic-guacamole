import 'package:fantastic_guacamole/data/repositories/habit_repository.dart'
    show HabitRecord;

/// Contract for habit persistence.
///
/// Deliberately expressed in [HabitRecord], the shape habits are actually
/// stored in today. `HabitEntity` is the richer PLANNED domain type; migrating
/// storage onto it would change the persisted format, so it stays out of scope
/// here. This interface exists so habit use cases are testable and so Habits
/// stops being a provider-to-repository bypass.
abstract class IHabitRepository {
  Future<List<HabitRecord>> getHabits();

  Future<void> saveHabits(List<HabitRecord> habits);
}
