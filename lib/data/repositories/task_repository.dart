import 'dart:convert';

import 'package:fantastic_guacamole/core/errors/app_exception.dart';
import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/data/local/hive_storage.dart';
import 'package:fantastic_guacamole/data/local/task_entity_mapper.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/domain/models/paged_result.dart';

/// ChronoSpark TaskRepository
/// Implements ITaskRepository using `HiveStorage<String>` (JSON-serialised TaskEntity).
class TaskRepository implements ITaskRepository {
  TaskRepository({required this._storage});

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
      return _decodeTaskPayload(raw, logMalformed: true);
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
      await _storage.delete(id);
    } catch (e) {
      throw StorageException('Failed to delete task $id: $e');
    }
  }

  Future<List<TaskEntity>> _loadSortedTasks() async {
    await _storage.open();
    final Map<dynamic, String> map = _storage.getAll();

    final List<TaskEntity> tasks = <TaskEntity>[];
    int malformedCount = 0;
    for (final String raw in map.values) {
      final TaskEntity? task = _decodeTaskPayload(raw);
      if (task == null) {
        malformedCount++;
        if (malformedCount == 1) {
          Logger.warn('Skipping malformed task payload.');
        }
        continue;
      }
      tasks.add(task);
    }
    if (malformedCount > 1) {
      Logger.warn('Skipped $malformedCount malformed task payloads.');
    }
    if (malformedCount > 0) {
      throw const FormatException(
        'Task storage contains malformed payloads. Repair is required.',
      );
    }
    tasks.sort(
      (TaskEntity a, TaskEntity b) => b.createdAt.compareTo(a.createdAt),
    );
    return tasks;
  }

  TaskEntity? _decodeTaskPayload(String raw, {bool logMalformed = false}) {
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Task payload is not a JSON object.');
      }
      return TaskEntityMapper.fromJson(decoded);
    } on Object catch (error) {
      if (logMalformed) {
        Logger.warn('Task payload is corrupted and cannot be read: $error');
      }
      return null;
    }
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
