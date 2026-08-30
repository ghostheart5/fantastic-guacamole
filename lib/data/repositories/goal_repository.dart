import 'dart:convert';

import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/local/hive_storage.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';

class GoalRepository implements IGoalRepository {
  GoalRepository(this._store, {this.scope});

  static const String _key = 'goals_v2';

  /// Where an unreadable payload is quarantined before it would be overwritten.
  static const String _corruptBackupKey = 'goals_v2_corrupt_backup';

  final HiveStorage<String> _store;
  final AccountStorageScope? scope;
  Future<void> _writeTail = Future<void>.value();

  bool _lastReadCorrupted = false;

  /// True when the most recent [getGoals] could not decode stored data.
  ///
  /// A corrupted read returns an empty list so the app stays usable, but that
  /// empty list is NOT a valid "user has no goals" state — callers that treat
  /// it as one and then save would destroy recoverable data. [saveGoals]
  /// quarantines the raw payload first; this flag lets callers and tests tell
  /// the two situations apart.
  bool get lastReadCorrupted => _lastReadCorrupted;

  @override
  List<GoalEntity> getGoals() {
    _requireWritableScope();
    String? raw;
    try {
      raw = _store.get(_key);
    } on StateError {
      _lastReadCorrupted = false;
      return const <GoalEntity>[];
    }
    if (raw == null || raw.trim().isEmpty) {
      _lastReadCorrupted = false;
      return const <GoalEntity>[];
    }
    try {
      final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
      final List<GoalEntity> goals = list
          .whereType<Map<String, dynamic>>()
          .map(GoalEntity.fromJson)
          .toList(growable: false);
      _lastReadCorrupted = false;
      return goals;
    } catch (error, stackTrace) {
      _lastReadCorrupted = true;
      Logger.errorCategory(
        'StorageCorruption',
        'Failed to decode stored goals; returning empty list without '
            'discarding the raw payload.',
        error,
        stackTrace,
      );
      return const <GoalEntity>[];
    }
  }

  @override
  Future<void> saveGoal(GoalEntity goal) {
    _requireWritableScope();
    return _enqueueWrite(() async {
      final List<GoalEntity> existing = getGoals().toList(growable: true);
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
    _requireWritableScope();
    final List<GoalEntity> snapshot = List<GoalEntity>.unmodifiable(goals);
    return _enqueueWrite(() => _saveGoalsUnlocked(snapshot));
  }

  Future<void> _saveGoalsUnlocked(List<GoalEntity> goals) async {
    await _quarantineCorruptPayloadIfNeeded();
    await _store.put(
      _key,
      jsonEncode(goals.map((GoalEntity g) => g.toJson()).toList()),
    );
  }

  @override
  Future<void> deleteGoal(String id) {
    _requireWritableScope();
    return _enqueueWrite(() async {
      final List<GoalEntity> next = getGoals()
          .where((GoalEntity goal) => goal.id != id)
          .toList(growable: false);
      await _saveGoalsUnlocked(next);
    });
  }

  Future<void> _enqueueWrite(Future<void> Function() operation) {
    final Future<void> next = _writeTail.then<void>(
      (_) => operation(),
      onError: (Object _, StackTrace _) => operation(),
    );
    _writeTail = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  /// Copies an undecodable payload to [_corruptBackupKey] before it is
  /// overwritten, so a decode bug never becomes permanent data loss.
  Future<void> _quarantineCorruptPayloadIfNeeded() async {
    if (!_lastReadCorrupted) {
      return;
    }
    try {
      final String? raw = _store.get(_key);
      if (raw != null && raw.trim().isNotEmpty) {
        await _store.put(_corruptBackupKey, raw);
        Logger.errorCategory(
          'StorageCorruption',
          'Quarantined unreadable goals payload to "$_corruptBackupKey" '
              'before overwrite.',
        );
      }
    } catch (error, stackTrace) {
      Logger.errorCategory(
        'StorageCorruption',
        'Failed to quarantine unreadable goals payload.',
        error,
        stackTrace,
      );
    }
    _lastReadCorrupted = false;
  }

  void _requireWritableScope() {
    final AccountStorageScope? activeScope = scope;
    if (activeScope != null && !activeScope.isWritable) {
      throw StateError('Goals require authenticated account storage.');
    }
  }
}
