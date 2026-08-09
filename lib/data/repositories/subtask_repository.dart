import 'dart:convert';

import 'package:fantastic_guacamole/core/errors/app_exception.dart';
import 'package:fantastic_guacamole/data/local/hive_storage.dart';
import 'package:fantastic_guacamole/domain/entities/subtask_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_subtask_repository.dart';

class SubtaskRepository implements ISubtaskRepository {
  SubtaskRepository(this._store);

  static const String _key = 'subtasks_v1';

  final HiveStorage<String> _store;

  @override
  List<SubtaskEntity> getSubtasks() {
    String? raw;
    try {
      raw = _store.get(_key);
    } on StateError catch (error) {
      throw StorageException('Subtask storage is unavailable: $error');
    }
    if (raw == null || raw.trim().isEmpty) {
      return const <SubtaskEntity>[];
    }
    try {
      final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map(SubtaskEntity.fromJson)
          .toList(growable: false);
    } on Object catch (error) {
      throw StorageException('Subtask storage is corrupted: $error');
    }
  }

  @override
  Future<void> saveSubtask(SubtaskEntity subtask) {
    final List<SubtaskEntity> existing = getSubtasks().toList(growable: true);
    final int index = existing.indexWhere(
      (SubtaskEntity item) => item.id == subtask.id,
    );
    if (index >= 0) {
      existing[index] = subtask;
    } else {
      existing.insert(0, subtask);
    }
    return saveSubtasks(existing);
  }

  @override
  Future<void> saveSubtasks(List<SubtaskEntity> subtasks) {
    return _store.put(
      _key,
      jsonEncode(
        subtasks.map((SubtaskEntity subtask) => subtask.toJson()).toList(),
      ),
    );
  }

  @override
  Future<void> deleteSubtask(String id) {
    final List<SubtaskEntity> next = getSubtasks()
        .where((SubtaskEntity subtask) => subtask.id != id)
        .toList(growable: false);
    return saveSubtasks(next);
  }
}
