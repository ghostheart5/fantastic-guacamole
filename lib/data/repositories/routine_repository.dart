import 'dart:convert';

import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/data/local/hive_storage.dart';
import 'package:fantastic_guacamole/domain/entities/routine_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_routine_repository.dart';

class RoutineRepository implements IRoutineRepository {
  RoutineRepository(this._store);

  static const String _key = 'routines_v1';

  final HiveStorage<String> _store;
  bool _corruptedSnapshot = false;
  Future<void> _writeQueue = Future<void>.value();

  @override
  List<RoutineEntity> getRoutines() {
    String? raw;
    try {
      raw = _store.get(_key);
    } on StateError {
      return const <RoutineEntity>[];
    }
    if (raw == null || raw.trim().isEmpty) {
      _corruptedSnapshot = false;
      return const <RoutineEntity>[];
    }
    try {
      final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
      _corruptedSnapshot = false;
      return list
          .whereType<Map<String, dynamic>>()
          .map(RoutineEntity.fromJson)
          .toList(growable: false);
    } on Object catch (error) {
      _corruptedSnapshot = true;
      Logger.error(
        'Routines snapshot is corrupted; writes are blocked.',
        error,
      );
      return const <RoutineEntity>[];
    }
  }

  @override
  Future<void> saveRoutine(RoutineEntity routine) {
    return _serializeWrite(() async {
      final List<RoutineEntity> existing = getRoutines().toList(growable: true);
      _ensureWriteAllowed();
      final int index = existing.indexWhere(
        (RoutineEntity item) => item.id == routine.id,
      );
      if (index >= 0) {
        existing[index] = routine;
      } else {
        existing.insert(0, routine);
      }
      await _saveRoutinesUnlocked(existing);
    });
  }

  @override
  Future<void> saveRoutines(List<RoutineEntity> routines) {
    return _serializeWrite(() async {
      getRoutines();
      _ensureWriteAllowed();
      await _saveRoutinesUnlocked(routines);
    });
  }

  @override
  Future<void> deleteRoutine(String id) {
    return _serializeWrite(() async {
      final List<RoutineEntity> next = getRoutines()
          .where((RoutineEntity routine) => routine.id != id)
          .toList(growable: false);
      _ensureWriteAllowed();
      await _saveRoutinesUnlocked(next);
    });
  }

  Future<void> _serializeWrite(Future<void> Function() action) {
    final Future<void> next = _writeQueue.then((_) => action());
    _writeQueue = next.catchError((_) {});
    return next;
  }

  Future<void> _saveRoutinesUnlocked(List<RoutineEntity> routines) {
    return _store.put(
      _key,
      jsonEncode(
        routines.map((RoutineEntity routine) => routine.toJson()).toList(),
      ),
    );
  }

  void _ensureWriteAllowed() {
    if (_corruptedSnapshot) {
      throw StateError(
        'Routines storage is corrupted. Repair data before writing to avoid data loss.',
      );
    }
  }
}
