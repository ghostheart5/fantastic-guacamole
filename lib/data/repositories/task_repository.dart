import 'dart:convert';

import 'package:fantastic_guacamole/core/async/account_storage_mutation.dart';
import 'package:fantastic_guacamole/core/async/keyed_mutation_coordinator.dart';
import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/core/errors/app_exception.dart';
import 'package:fantastic_guacamole/data/local/hive_storage.dart';
import 'package:fantastic_guacamole/data/local/task_entity_mapper.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/domain/models/paged_result.dart';

/// ChronoSpark TaskRepository
/// Implements ITaskRepository using `HiveStorage<String>` (JSON-serialised TaskEntity).
class TaskRepository implements ITaskRepository, IExactTaskSnapshotRepository {
  factory TaskRepository({
    required HiveStorage<String> storage,
    KeyedMutationCoordinator? mutationCoordinator,
  }) {
    return TaskRepository._(
      storage,
      mutationCoordinator ?? KeyedMutationCoordinator.shared,
    );
  }

  TaskRepository._(this._storage, this._mutations);

  static const String quarantineKey = 'tasks_quarantine_v1';
  static const String snapshotRecoveryKey = 'tasks_snapshot_recovery_v1';
  static const int _maxQuarantineRecords = 100;

  final HiveStorage<String> _storage;
  final KeyedMutationCoordinator _mutations;

  // ------------------------------------------------------------------
  // ITaskRepository
  // ------------------------------------------------------------------

  @override
  Future<List<TaskEntity>> getAllTasks() async {
    try {
      return await _loadSortedTasks();
    } catch (e) {
      throw StorageException('Failed to load tasks: $e');
    }
  }

  Future<PagedResult<TaskEntity>> getTasksPage({
    String? cursor,
    int limit = 50,
  }) async {
    try {
      final List<TaskEntity> tasks = await _loadSortedTasks();
      return _pageItems<TaskEntity>(
        tasks,
        cursor: cursor,
        limit: limit,
        idFor: (TaskEntity task) => task.id,
      );
    } catch (e) {
      throw StorageException('Failed to load task page: $e');
    }
  }

  @override
  Future<TaskEntity?> getTaskById(String id) async {
    try {
      await _storage.open();
      if (_storage.get(snapshotRecoveryKey) != null) {
        await runAccountStorageMutation(
          _recoverInterruptedSnapshot,
          coordinator: _mutations,
        );
      }
      final String? raw = _storage.get(id);
      if (raw == null) return null;
      final TaskEntity task = TaskEntityMapper.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      return task.isCanceled ? null : task;
    } catch (e) {
      throw StorageException('Failed to get task $id: $e');
    }
  }

  @override
  Future<void> saveTask(TaskEntity task) async {
    return runAccountStorageMutation(() async {
      try {
        await _recoverInterruptedSnapshot();
        await _storage.put(task.id, jsonEncode(TaskEntityMapper.toJson(task)));
      } catch (e) {
        throw StorageException('Failed to save task ${task.id}: $e');
      }
    }, coordinator: _mutations);
  }

  @override
  Future<void> deleteTask(String id) async {
    return runAccountStorageMutation(() async {
      try {
        await _storage.open();
        await _recoverInterruptedSnapshot();
        final String? raw = _storage.get(id);
        if (raw == null) return;
        final TaskEntity task = TaskEntityMapper.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
        if (task.isCanceled) return;
        // A timestamped tombstone is deliberately retained in account-scoped
        // storage. Backup merge can then propagate deletion to another device
        // instead of resurrecting an older cloud copy.
        await _storage.put(
          id,
          jsonEncode(TaskEntityMapper.toJson(task.cancel())),
        );
      } catch (e) {
        throw StorageException('Failed to delete task $id: $e');
      }
    }, coordinator: _mutations);
  }

  @override
  Future<void> replaceTaskSnapshot(List<TaskEntity> tasks) {
    return runAccountStorageMutation(() async {
      try {
        await _storage.open();
        await _recoverInterruptedSnapshot();
        final Map<String, String> original = _stringKeyedRawSnapshot();
        await _storage.put(
          snapshotRecoveryKey,
          jsonEncode(<String, dynamic>{
            'schemaVersion': 1,
            'original': original,
          }),
        );
        final Map<String, String> replacement = <String, String>{
          for (final TaskEntity task in tasks)
            task.id: jsonEncode(TaskEntityMapper.toJson(task)),
        };
        final String? quarantine = original[quarantineKey];
        if (quarantine != null) replacement[quarantineKey] = quarantine;
        await _storage.putAll(replacement);
        final Set<String> replacementKeys = replacement.keys.toSet();
        for (final Object? rawKey in _storage.getAll().keys.toList()) {
          final String key = rawKey.toString();
          if (key != snapshotRecoveryKey && !replacementKeys.contains(key)) {
            await _storage.delete(key);
          }
        }
        await _storage.delete(snapshotRecoveryKey);
      } catch (e) {
        try {
          await _recoverInterruptedSnapshot();
        } on Object {
          // Keep the durable recovery marker for the next repository access.
        }
        throw StorageException('Failed to replace the task snapshot: $e');
      }
    }, coordinator: _mutations);
  }

  Future<List<TaskEntity>> _loadSortedTasks() async {
    await _storage.open();
    if (_storage.get(snapshotRecoveryKey) != null) {
      return runAccountStorageMutation(() async {
        await _recoverInterruptedSnapshot();
        return _loadSortedTasks();
      }, coordinator: _mutations);
    }
    final Map<dynamic, String> map = _storage.getAll();
    final List<TaskEntity> tasks = <TaskEntity>[];
    final List<Map<String, dynamic>> malformed = <Map<String, dynamic>>[];
    for (final MapEntry<dynamic, String> entry in map.entries) {
      if (entry.key == quarantineKey || entry.key == snapshotRecoveryKey) {
        continue;
      }
      try {
        tasks.add(
          TaskEntityMapper.fromJson(
            jsonDecode(entry.value) as Map<String, dynamic>,
          ),
        );
      } on Object {
        malformed.add(<String, dynamic>{
          'key': entry.key.toString(),
          'raw': entry.value,
          'quarantinedAt': DateTime.now().toUtc().toIso8601String(),
        });
      }
    }
    if (malformed.isNotEmpty) {
      return runAccountStorageMutation(() async {
        final List<TaskEntity> freshTasks =
            await _loadSortedTasksWithoutRepair();
        final List<Map<String, dynamic>> freshMalformed =
            _malformedRecordsFromStorage();
        if (freshMalformed.isNotEmpty) {
          await _quarantineMalformed(freshMalformed);
          Logger.warn(
            'Quarantined ${freshMalformed.length} malformed task record(s) '
            'while preserving valid tasks.',
          );
        }
        return freshTasks;
      }, coordinator: _mutations);
    }
    tasks.sort(
      (TaskEntity a, TaskEntity b) => b.createdAt.compareTo(a.createdAt),
    );
    return tasks;
  }

  Future<List<TaskEntity>> _loadSortedTasksWithoutRepair() async {
    await _storage.open();
    final List<TaskEntity> tasks = <TaskEntity>[];
    for (final MapEntry<dynamic, String> entry in _storage.getAll().entries) {
      if (entry.key == quarantineKey || entry.key == snapshotRecoveryKey) {
        continue;
      }
      try {
        tasks.add(
          TaskEntityMapper.fromJson(
            jsonDecode(entry.value) as Map<String, dynamic>,
          ),
        );
      } on Object {
        // The raw value remains in place and is quarantined by the caller.
      }
    }
    tasks.sort(
      (TaskEntity a, TaskEntity b) => b.createdAt.compareTo(a.createdAt),
    );
    return tasks;
  }

  List<Map<String, dynamic>> _malformedRecordsFromStorage() {
    final List<Map<String, dynamic>> malformed = <Map<String, dynamic>>[];
    for (final MapEntry<dynamic, String> entry in _storage.getAll().entries) {
      if (entry.key == quarantineKey || entry.key == snapshotRecoveryKey) {
        continue;
      }
      try {
        TaskEntityMapper.fromJson(
          jsonDecode(entry.value) as Map<String, dynamic>,
        );
      } on Object {
        malformed.add(<String, dynamic>{
          'key': entry.key.toString(),
          'raw': entry.value,
          'quarantinedAt': DateTime.now().toUtc().toIso8601String(),
        });
      }
    }
    return malformed;
  }

  Map<String, String> _stringKeyedRawSnapshot() {
    return <String, String>{
      for (final MapEntry<dynamic, String> entry in _storage.getAll().entries)
        if (entry.key.toString() != snapshotRecoveryKey)
          entry.key.toString(): entry.value,
    };
  }

  Future<void> _recoverInterruptedSnapshot() async {
    await _storage.open();
    final String? rawMarker = _storage.get(snapshotRecoveryKey);
    if (rawMarker == null) return;
    final Object? decoded = jsonDecode(rawMarker);
    if (decoded is! Map || decoded['schemaVersion'] != 1) {
      throw const FormatException('Task snapshot recovery marker is invalid.');
    }
    final Object? rawOriginal = decoded['original'];
    if (rawOriginal is! Map) {
      throw const FormatException('Task snapshot recovery data is invalid.');
    }
    final Map<String, String> original = <String, String>{};
    for (final MapEntry<dynamic, dynamic> entry in rawOriginal.entries) {
      if (entry.value is! String) {
        throw const FormatException('Task snapshot recovery data is invalid.');
      }
      original[entry.key.toString()] = entry.value as String;
    }
    await _storage.putAll(original);
    final Set<String> originalKeys = original.keys.toSet();
    for (final Object? rawKey in _storage.getAll().keys.toList()) {
      final String key = rawKey.toString();
      if (key != snapshotRecoveryKey && !originalKeys.contains(key)) {
        await _storage.delete(key);
      }
    }
    await _storage.delete(snapshotRecoveryKey);
  }

  Future<void> _quarantineMalformed(
    List<Map<String, dynamic>> malformed,
  ) async {
    final List<dynamic> records = <dynamic>[];
    final String? existingRaw = _storage.get(quarantineKey);
    if (existingRaw != null) {
      try {
        final Object? decoded = jsonDecode(existingRaw);
        if (decoded is List<dynamic>) {
          records.addAll(decoded.whereType<Map<String, dynamic>>());
        }
      } on Object {
        records.add(<String, dynamic>{
          'key': quarantineKey,
          'raw': existingRaw,
          'quarantinedAt': DateTime.now().toUtc().toIso8601String(),
        });
      }
    }
    for (final Map<String, dynamic> candidate in malformed) {
      final bool alreadyCaptured = records
          .whereType<Map<dynamic, dynamic>>()
          .any(
            (Map<dynamic, dynamic> record) =>
                record['key'] == candidate['key'] &&
                record['raw'] == candidate['raw'],
          );
      if (!alreadyCaptured) {
        records.add(candidate);
      }
    }
    final int start = records.length > _maxQuarantineRecords
        ? records.length - _maxQuarantineRecords
        : 0;
    await _storage.put(quarantineKey, jsonEncode(records.sublist(start)));
  }

  PagedResult<T> _pageItems<T>(
    List<T> items, {
    required String? cursor,
    required int limit,
    required String Function(T item) idFor,
  }) {
    final int safeLimit = limit < 1 ? 1 : limit;
    final int startIndex = cursor == null
        ? 0
        : items.indexWhere((T item) => idFor(item) == cursor) + 1;
    if (startIndex <= 0 || startIndex >= items.length) {
      final List<T> page = startIndex >= items.length
          ? <T>[]
          : items.take(safeLimit).toList(growable: false);
      final String? nextCursor =
          page.length == safeLimit && page.length < items.length
          ? idFor(page.last)
          : null;
      return PagedResult<T>(items: page, nextCursor: nextCursor);
    }
    final List<T> page = items
        .skip(startIndex)
        .take(safeLimit)
        .toList(growable: false);
    final int nextIndex = startIndex + page.length;
    final String? nextCursor = nextIndex < items.length && page.isNotEmpty
        ? idFor(page.last)
        : null;
    return PagedResult<T>(items: page, nextCursor: nextCursor);
  }
}
