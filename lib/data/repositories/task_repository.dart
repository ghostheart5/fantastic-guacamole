import 'dart:convert';

import 'package:fantastic_guacamole/core/errors/app_exception.dart';
import 'package:fantastic_guacamole/data/local/hive_storage.dart';
import 'package:fantastic_guacamole/data/local/task_entity_mapper.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/domain/models/paged_result.dart';

/// ChronoSpark TaskRepository
/// Implements ITaskRepository using `HiveStorage<String>` (JSON-serialised TaskEntity).
class TaskRepository implements ITaskRepository {
  TaskRepository({required HiveStorage<String> storage})
    // Public constructor keeps the established `storage` parameter.
    // ignore: prefer_initializing_formals
    : _storage = storage,
      _secureStore = null;

  TaskRepository.secure(SecureStore secureStore, {HiveStorage<String>? legacyStorage})
    : _storage = legacyStorage,
      _secureStore = secureStore;

  static const String _secureKey = 'task_entries_v2';
  final HiveStorage<String>? _storage;
  final SecureStore? _secureStore;

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

  Future<PagedResult<TaskEntity>> getTasksPage({String? cursor, int limit = 50}) async {
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
      final String? raw;
      if (_secureStore != null) {
        raw = (await _readSecureMap())[id];
      } else {
        final HiveStorage<String> storage = _storage!;
        await storage.open();
        raw = storage.get(id);
      }
      if (raw == null) return null;
      return TaskEntityMapper.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      throw StorageException('Failed to get task $id: $e');
    }
  }

  @override
  Future<void> saveTask(TaskEntity task) async {
    try {
      final String encoded = jsonEncode(TaskEntityMapper.toJson(task));
      if (_secureStore != null) {
        final Map<dynamic, String> entries = await _readSecureMap();
        entries[task.id] = encoded;
        await _writeSecureMap(entries);
      } else {
        await _storage!.put(task.id, encoded);
      }
    } catch (e) {
      throw StorageException('Failed to save task ${task.id}: $e');
    }
  }

  @override
  Future<void> deleteTask(String id) async {
    try {
      if (_secureStore != null) {
        final Map<dynamic, String> entries = await _readSecureMap();
        entries.remove(id);
        await _writeSecureMap(entries);
      } else {
        await _storage!.delete(id);
      }
    } catch (e) {
      throw StorageException('Failed to delete task $id: $e');
    }
  }

  Future<Map<dynamic, String>> _readSecureMap() async {
    final String? raw = await _secureStore!.readString(_secureKey);
    if (raw != null && raw.trim().isNotEmpty) {
      final Object? decoded = jsonDecode(raw);
      if (decoded is Map) {
        return decoded.map(
          (dynamic key, dynamic value) => MapEntry(key.toString(), value.toString()),
        );
      }
    }
    final HiveStorage<String>? legacy = _storage;
    if (legacy == null) return <dynamic, String>{};
    await legacy.open();
    final Map<dynamic, String> migrated = legacy.getAll();
    if (migrated.isNotEmpty) {
      await _writeSecureMap(migrated);
      await legacy.clear();
    }
    return migrated;
  }

  Future<void> _writeSecureMap(Map<dynamic, String> entries) {
    return _secureStore!.writeString(_secureKey, jsonEncode(entries));
  }

  Future<List<TaskEntity>> _loadSortedTasks() async {
    final Map<dynamic, String> map;
    if (_secureStore != null) {
      map = await _readSecureMap();
    } else {
      final HiveStorage<String> storage = _storage!;
      await storage.open();
      map = storage.getAll();
    }

    final List<TaskEntity> tasks = map.values
        .map((raw) => TaskEntityMapper.fromJson(jsonDecode(raw) as Map<String, dynamic>))
        .toList(growable: false);
    tasks.sort((TaskEntity a, TaskEntity b) => b.createdAt.compareTo(a.createdAt));
    return tasks;
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
      final String? nextCursor = page.length == safeLimit && page.length < items.length
          ? idFor(page.last)
          : null;
      return PagedResult<T>(items: page, nextCursor: nextCursor);
    }
    final List<T> page = items.skip(startIndex).take(safeLimit).toList(growable: false);
    final int nextIndex = startIndex + page.length;
    final String? nextCursor = nextIndex < items.length && page.isNotEmpty
        ? idFor(page.last)
        : null;
    return PagedResult<T>(items: page, nextCursor: nextCursor);
  }
}
