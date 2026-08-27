import 'dart:convert';

import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/data/local/hive_storage.dart';
import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_routine_repository.dart';

class RoutineRepository implements IRoutineRepository {
  RoutineRepository(this._store);

  static const String _key = 'routines_v1';

  final HiveStorage<String> _store;

  @override
  List<HabitEntity> getRoutines() {
    String? raw;
    try {
      raw = _store.get(_key);
    } on StateError {
      return const <HabitEntity>[];
    }
    if (raw == null || raw.trim().isEmpty) {
      return const <HabitEntity>[];
    }
    try {
      final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map(HabitEntity.fromJson)
          .toList(growable: false);
    } catch (error, stackTrace) {
      // Corrupted payload: return the empty/absent value so the app stays
      // usable, but make it observable instead of silently
      // indistinguishable from "user has no routines".
      Logger.errorCategory(
        'StorageCorruption',
        'Failed to decode stored routines; returning empty result.',
        error,
        stackTrace,
      );
      return const <HabitEntity>[];
    }
  }

  @override
  Future<void> saveRoutine(HabitEntity routine) {
    final List<HabitEntity> existing = getRoutines().toList(growable: true);
    final int index = existing.indexWhere(
      (HabitEntity item) => item.id == routine.id,
    );
    if (index >= 0) {
      existing[index] = routine;
    } else {
      existing.insert(0, routine);
    }
    return saveRoutines(existing);
  }

  @override
  Future<void> saveRoutines(List<HabitEntity> routines) {
    return _store.put(
      _key,
      jsonEncode(
        routines.map((HabitEntity routine) => routine.toJson()).toList(),
      ),
    );
  }

  @override
  Future<void> deleteRoutine(String id) {
    final List<HabitEntity> next = getRoutines()
        .where((HabitEntity routine) => routine.id != id)
        .toList(growable: false);
    return saveRoutines(next);
  }
}
