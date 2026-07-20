import 'dart:convert';

import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/data/local/hive_storage.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';

class GoalRepository implements IGoalRepository {
  GoalRepository(this._store);

  static const String _key = 'goals_v2';

  final HiveStorage<String> _store;
  bool _corruptedSnapshot = false;
  Future<void> _writeQueue = Future<void>.value();

  @override
  List<GoalEntity> getGoals() {
    String? raw;
    try {
      raw = _store.get(_key);
    } on StateError {
      return const <GoalEntity>[];
    }
    if (raw == null || raw.trim().isEmpty) {
      _corruptedSnapshot = false;
      return const <GoalEntity>[];
    }
    try {
      final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
      _corruptedSnapshot = false;
      return list
          .whereType<Map<String, dynamic>>()
          .map(GoalEntity.fromJson)
          .toList(growable: false);
    } on Object catch (error) {
      _corruptedSnapshot = true;
      Logger.error('Goals snapshot is corrupted; writes are blocked.', error);
      return const <GoalEntity>[];
    }
  }

  @override
  Future<void> saveGoal(GoalEntity goal) {
    return _serializeWrite(() async {
      final List<GoalEntity> existing = getGoals().toList(growable: true);
      _ensureWriteAllowed();
      final int index = existing.indexWhere(
        (GoalEntity item) => item.id == goal.id,
      );
      if (index >= 0) {
        existing[index] = goal;
      } else {
        existing.insert(0, goal);
      }
      await _saveGoalsUnlocked(existing);
    });
  }

  @override
  Future<void> saveGoals(List<GoalEntity> goals) {
    return _serializeWrite(() async {
      getGoals();
      _ensureWriteAllowed();
      await _saveGoalsUnlocked(goals);
    });
  }

  @override
  Future<void> deleteGoal(String id) {
    return _serializeWrite(() async {
      final List<GoalEntity> next = getGoals()
          .where((GoalEntity goal) => goal.id != id)
          .toList(growable: false);
      _ensureWriteAllowed();
      await _saveGoalsUnlocked(next);
    });
  }

  Future<void> _serializeWrite(Future<void> Function() action) {
    final Future<void> next = _writeQueue.then((_) => action());
    _writeQueue = next.catchError((_) {});
    return next;
  }

  Future<void> _saveGoalsUnlocked(List<GoalEntity> goals) {
    return _store.put(
      _key,
      jsonEncode(goals.map((GoalEntity g) => g.toJson()).toList()),
    );
  }

  void _ensureWriteAllowed() {
    if (_corruptedSnapshot) {
      throw StateError(
        'Goals storage is corrupted. Repair data before writing to avoid data loss.',
      );
    }
  }
}
