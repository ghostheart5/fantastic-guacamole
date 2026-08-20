import 'dart:convert';

import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/core/errors/app_exception.dart';
import 'package:fantastic_guacamole/data/local/hive_storage.dart';
import 'package:fantastic_guacamole/data/local/task_entity_mapper.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/domain/models/paged_result.dart';

/// ChronoSpark TaskRepository
/// Implements ITaskRepository using `HiveStorage<String>` (JSON-serialised TaskEntity).
class TaskRepository implements ITaskRepository {
  TaskRepository({required this._storage});

  static const String quarantineKey = 'tasks_quarantine_v1';
  static const int _maxQuarantineRecords = 100;

  final HiveStorage<String> _storage;

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
    try {
      await _storage.put(task.id, jsonEncode(TaskEntityMapper.toJson(task)));
    } catch (e) {
      throw StorageException('Failed to save task ${task.id}: $e');
    }
  }

  @override
  Future<void> deleteTask(String id) async {
    try {
      await _storage.open();
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
  }

  Future<List<TaskEntity>> _loadSortedTasks() async {
    await _storage.open();
    final Map<dynamic, String> map = _storage.getAll();
    final List<TaskEntity> tasks = <TaskEntity>[];
    final List<Map<String, dynamic>> malformed = <Map<String, dynamic>>[];
    for (final MapEntry<dynamic, String> entry in map.entries) {
      if (entry.key == quarantineKey) {
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
      await _quarantineMalformed(malformed);
      Logger.warn(
        'Quarantined ${malformed.length} malformed task record(s) while '
        'preserving valid tasks.',
      );
    }
    tasks.sort(
      (TaskEntity a, TaskEntity b) => b.createdAt.compareTo(a.createdAt),
    );
    return tasks;
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
