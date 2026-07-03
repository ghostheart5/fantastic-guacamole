import 'dart:convert';

import 'package:fantastic_guacamole/core/errors/exceptions.dart';
import 'package:fantastic_guacamole/data/local/hive_storage.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';

/// ChronoSpark TaskRepository
/// Implements ITaskRepository using `HiveStorage<String>` (JSON-serialised TaskEntity).
class TaskRepository implements ITaskRepository {
  TaskRepository({required this._storage});

  final HiveStorage<String> _storage;

  // ------------------------------------------------------------------
  // SERIALISATION
  // ------------------------------------------------------------------

  static TaskEntity _fromJson(Map<String, dynamic> json) {
    final durMs = json['estimatedDurationMs'] as int?;
    return TaskEntity(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      isCompleted: json['isCompleted'] as bool? ?? false,
      priority: json['priority'] as int? ?? 3,
      difficulty: json['difficulty'] as int? ?? 3,
      energyRequired: json['energyRequired'] as int? ?? 3,
      estimatedDuration: durMs != null ? Duration(milliseconds: durMs) : null,
    );
  }

  static Map<String, dynamic> _toJson(TaskEntity e) => {
    'id': e.id,
    'title': e.title,
    'description': e.description,
    'createdAt': e.createdAt.toIso8601String(),
    'isCompleted': e.isCompleted,
    'priority': e.priority,
    'difficulty': e.difficulty,
    'energyRequired': e.energyRequired,
    'estimatedDurationMs': e.estimatedDuration?.inMilliseconds,
  };

  // ------------------------------------------------------------------
  // ITaskRepository
  // ------------------------------------------------------------------

  @override
  Future<List<TaskEntity>> getAllTasks() async {
    try {
      final map = _storage.getAll();
      return map.values
          .map((raw) => _fromJson(jsonDecode(raw) as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw StorageException('Failed to load tasks: $e');
    }
  }

  @override
  Future<TaskEntity?> getTaskById(String id) async {
    try {
      final raw = _storage.get(id);
      if (raw == null) return null;
      return _fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      throw StorageException('Failed to get task $id: $e');
    }
  }

  @override
  Future<void> saveTask(TaskEntity task) async {
    try {
      await _storage.put(task.id, jsonEncode(_toJson(task)));
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
}
