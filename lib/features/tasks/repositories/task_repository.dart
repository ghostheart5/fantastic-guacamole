import 'dart:convert';

import 'package:fantastic_guacamole/data/local/hive_storage.dart';

class TaskRepository {
  TaskRepository({required this._storage});

  final HiveStorage<String> _storage;

  Future<List<Map<String, dynamic>>> getTasks() async {
    await _storage.open();
    final Map<dynamic, String> values = _storage.getAll();
    return values.values
        .map((String raw) => jsonDecode(raw) as Map<String, dynamic>)
        .toList(growable: false);
  }

  Future<void> saveTask(Map<String, dynamic> task) async {
    await _storage.open();
    final String id = task['id']?.toString().trim() ?? '';
    if (id.isEmpty) {
      return;
    }
    await _storage.put(id, jsonEncode(task));
  }

  Future<void> deleteTask(String id) async {
    await _storage.open();
    await _storage.delete(id);
  }
}
