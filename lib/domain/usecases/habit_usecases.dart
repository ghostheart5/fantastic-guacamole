import 'package:fantastic_guacamole/domain/entities/habit_record.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_habit_repository.dart';

/// CHRONOSPARK-CLASS: SHIPPING | Feature: Habits
///
/// Reads the stored habits. Resolved by habitsProvider.
class GetHabits {
  const GetHabits(this._repository);

  final IHabitRepository _repository;

  Future<List<HabitRecord>> call() => _repository.getHabits();
}

/// CHRONOSPARK-CLASS: SHIPPING | Feature: Habits
///
/// Adds a habit to the front of the list. Blank titles are rejected, matching
/// the behaviour the provider previously implemented inline.
class CreateHabit {
  const CreateHabit(this._repository);

  final IHabitRepository _repository;

  /// Returns the updated list, or [current] unchanged when [title] is blank.
  ///
  /// [id] is injectable so callers and tests control identity generation.
  Future<List<HabitRecord>> call({
    required List<HabitRecord> current,
    required String title,
    String? id,
  }) async {
    final String trimmed = title.trim();
    if (trimmed.isEmpty) {
      return current;
    }

    final List<HabitRecord> next = <HabitRecord>[
      HabitRecord(
        id: id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        title: trimmed,
      ),
      ...current,
    ];
    await _repository.saveHabits(next);
    return next;
  }
}

/// CHRONOSPARK-CLASS: SHIPPING | Feature: Habits
///
/// Flips a habit's active flag. This is what habit completion means in the
/// current data model — [HabitRecord] carries no streak or frequency, so no
/// streak evaluation is implied here.
class ToggleHabit {
  const ToggleHabit(this._repository);

  final IHabitRepository _repository;

  Future<List<HabitRecord>> call({
    required List<HabitRecord> current,
    required String id,
  }) async {
    if (!current.any((HabitRecord item) => item.id == id)) {
      return current;
    }
    final List<HabitRecord> next = current
        .map(
          (HabitRecord item) => item.id == id
              ? HabitRecord(
                  id: item.id,
                  title: item.title,
                  active: !item.active,
                )
              : item,
        )
        .toList(growable: false);
    await _repository.saveHabits(next);
    return next;
  }
}

/// CHRONOSPARK-CLASS: SHIPPING | Feature: Habits
///
/// Renames a habit. Blank titles and unknown ids leave the list untouched.
class UpdateHabit {
  const UpdateHabit(this._repository);

  final IHabitRepository _repository;

  Future<List<HabitRecord>> call({
    required List<HabitRecord> current,
    required String id,
    required String title,
  }) async {
    final String trimmed = title.trim();
    if (trimmed.isEmpty || !current.any((HabitRecord item) => item.id == id)) {
      return current;
    }
    final List<HabitRecord> next = current
        .map(
          (HabitRecord item) => item.id == id
              ? HabitRecord(id: item.id, title: trimmed, active: item.active)
              : item,
        )
        .toList(growable: false);
    await _repository.saveHabits(next);
    return next;
  }
}

/// CHRONOSPARK-CLASS: SHIPPING | Feature: Habits
///
/// Removes a habit by id.
class DeleteHabit {
  const DeleteHabit(this._repository);

  final IHabitRepository _repository;

  Future<List<HabitRecord>> call({
    required List<HabitRecord> current,
    required String id,
  }) async {
    final List<HabitRecord> next = current
        .where((HabitRecord item) => item.id != id)
        .toList(growable: false);
    if (next.length == current.length) {
      return current;
    }
    await _repository.saveHabits(next);
    return next;
  }
}

/// CHRONOSPARK-CLASS: SHIPPING | Feature: Habits
///
/// Bulk replace, for import/restore paths.
class SaveHabits {
  const SaveHabits(this._repository);

  final IHabitRepository _repository;

  Future<List<HabitRecord>> call(List<HabitRecord> habits) async {
    await _repository.saveHabits(habits);
    return habits;
  }
}
