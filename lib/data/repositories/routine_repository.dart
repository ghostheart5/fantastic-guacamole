import 'dart:convert';

import 'package:fantastic_guacamole/data/local/hive_storage.dart';
import 'package:fantastic_guacamole/domain/entities/routine_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_routine_repository.dart';

class RoutineRepository implements IRoutineRepository {
  RoutineRepository(this._store);

  static const String _key = 'routines_v1';

  final HiveStorage<String> _store;

  @override
  List<RoutineEntity> getRoutines() {
    String? raw;
    try {
      raw = _store.get(_key);
    } on StateError {
      return const <RoutineEntity>[];
    }
    if (raw == null || raw.trim().isEmpty) {
      return const <RoutineEntity>[];
    }
    try {
      final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map(RoutineEntity.fromJson)
          .toList(growable: false);
    } catch (_) {
      return const <RoutineEntity>[];
    }
  }

  @override
  Future<void> saveRoutine(RoutineEntity routine) {
    final List<RoutineEntity> existing = getRoutines().toList(growable: true);
    final int index = existing.indexWhere(
      (RoutineEntity item) => item.id == routine.id,
    );
    if (index >= 0) {
      existing[index] = routine;
    } else {
      existing.insert(0, routine);
    }
    return saveRoutines(existing);
  }

  @override
  Future<void> saveRoutines(List<RoutineEntity> routines) {
    return _store.put(
      _key,
      jsonEncode(
        routines.map((RoutineEntity routine) => routine.toJson()).toList(),
      ),
    );
  }

  @override
  Future<void> deleteRoutine(String id) {
    final List<RoutineEntity> next = getRoutines()
        .where((RoutineEntity routine) => routine.id != id)
        .toList(growable: false);
    return saveRoutines(next);
  }
}
