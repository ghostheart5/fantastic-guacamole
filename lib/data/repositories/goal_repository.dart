import 'dart:convert';

import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/core/errors/app_exception.dart';
import 'package:fantastic_guacamole/data/local/hive_storage.dart';
import 'package:fantastic_guacamole/data/sync/sync_mutation_dispatcher.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';

class GoalRepository implements IGoalRepository {
  GoalRepository(this._store, {this._syncDispatcher});

  static const String _key = 'goals_v2';

  final HiveStorage<String> _store;
  final SyncMutationDispatcher? _syncDispatcher;
  bool _corruptedSnapshot = false;
  Future<void> _writeQueue = Future<void>.value();

  @override
  List<GoalEntity> getGoals() {
    String? raw;
    try {
      raw = _store.get(_key);
    } on StateError catch (error) {
      throw StorageException('Goal storage is unavailable: $error');
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
      throw StorageException('Goal storage is corrupted: $error');
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
      await _syncDispatcher?.enqueueUpsert(
        tableName: 'goals',
        recordId: goal.id,
        payload: _goalSyncPayload(goal),
      );
    });
  }

  @override
  Future<void> saveGoals(List<GoalEntity> goals) {
    return _serializeWrite(() async {
      getGoals();
      _ensureWriteAllowed();
      await _saveGoalsUnlocked(goals);
      for (final GoalEntity goal in goals) {
        await _syncDispatcher?.enqueueUpsert(
          tableName: 'goals',
          recordId: goal.id,
          payload: _goalSyncPayload(goal),
        );
      }
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
      await _syncDispatcher?.enqueueDelete(tableName: 'goals', recordId: id);
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

  Map<String, dynamic> _goalSyncPayload(GoalEntity goal) {
    return <String, dynamic>{
      'id': goal.id,
      'title': goal.title,
      'description': goal.description,
      'target_date': goal.targetDate?.toIso8601String(),
      'color_hex': goal.colorHex,
      'status': goal.status.name,
      'completed_at': goal.completedAt?.toIso8601String(),
      'archived_at': goal.archivedAt?.toIso8601String(),
      'created_at': goal.createdAt.toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      'deleted_at': null,
    };
  }
}
