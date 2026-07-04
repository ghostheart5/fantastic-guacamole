import 'dart:convert';

import 'package:fantastic_guacamole/data/local/hive_storage.dart';
import 'package:fantastic_guacamole/data/local/shared_prefs_storage.dart';
import 'package:fantastic_guacamole/features/tasks/models/tasks_models.dart';
import 'package:fantastic_guacamole/data/local/task_adapter.dart';
import 'package:fantastic_guacamole/features/user/models/user_model.dart';
import 'package:fantastic_guacamole/features/user/adapters/user_adapter.dart';

/// ChronoSpark BackupService
class BackupService {
  final HiveStorage<TaskModel> taskStorage;
  final HiveStorage<UserModel> userStorage;
  final SharedPrefsStorage prefs;

  BackupService({
    required this.taskStorage,
    required this.userStorage,
    required this.prefs,
  });

  Future<Map<String, dynamic>> createFullBackup() async {
    final tasks = taskStorage.getAll().values.toList();
    final user = userStorage.get('user');
    final userStateJson = prefs.getJson('user_state');
    final settingsJson = prefs.getJson('settings');

    return {
      'version': '1.0.0',
      'timestamp': DateTime.now().toIso8601String(),
      'tasks': tasks.map(TaskAdapter.toJson).toList(),
      'user': user != null ? UserAdapter.toJson(user) : null,
      'user_state': userStateJson,
      'settings': settingsJson,
    };
  }

  Future<Map<String, dynamic>> backupTasks() async {
    final tasks = taskStorage.getAll().values.toList();
    return {
      'timestamp': DateTime.now().toIso8601String(),
      'tasks': tasks.map(TaskAdapter.toJson).toList(),
    };
  }

  Future<Map<String, dynamic>> backupUser() async {
    final user = userStorage.get('user');
    return {
      'timestamp': DateTime.now().toIso8601String(),
      'user': user != null ? UserAdapter.toJson(user) : null,
    };
  }

  Future<Map<String, dynamic>> backupUserState() async {
    final stateJson = prefs.getJson('user_state');
    return {
      'timestamp': DateTime.now().toIso8601String(),
      'user_state': stateJson,
    };
  }

  Future<Map<String, dynamic>> backupSettings() async {
    final settingsJson = prefs.getJson('settings');
    return {
      'timestamp': DateTime.now().toIso8601String(),
      'settings': settingsJson,
    };
  }

  Future<String> exportFullBackupString() async {
    final backup = await createFullBackup();
    return json.encode(backup);
  }

  Future<String> exportTasksString() async {
    final backup = await backupTasks();
    return json.encode(backup);
  }

  Future<void> restoreFullBackup(Map<String, dynamic> backup) async {
    final List<TaskModel> models = _taskModelsFromRaw(backup['tasks']);
    if (models.isNotEmpty) {
      await taskStorage.clear();
      for (final model in models) {
        await taskStorage.put(model.id, model);
      }
    }

    final Map<String, dynamic>? userJson = _asStringKeyMap(backup['user']);
    if (userJson != null) {
      final model = UserAdapter.fromJson(userJson);
      await userStorage.put('user', model);
    }

    final Map<String, dynamic>? userStateJson = _asStringKeyMap(
      backup['user_state'],
    );
    if (userStateJson != null) {
      await prefs.setJson('user_state', userStateJson);
    }

    final Map<String, dynamic>? settingsJson = _asStringKeyMap(
      backup['settings'],
    );
    if (settingsJson != null) {
      await prefs.setJson('settings', settingsJson);
    }
  }

  Future<void> restoreTasks(Map<String, dynamic> backup) async {
    final List<TaskModel> models = _taskModelsFromRaw(backup['tasks']);
    if (models.isEmpty) return;
    await taskStorage.clear();
    for (final model in models) {
      await taskStorage.put(model.id, model);
    }
  }

  Future<void> restoreUser(Map<String, dynamic> backup) async {
    final Map<String, dynamic>? userJson = _asStringKeyMap(backup['user']);
    if (userJson == null) return;
    final model = UserAdapter.fromJson(userJson);
    await userStorage.put('user', model);
  }

  Future<void> restoreUserState(Map<String, dynamic> backup) async {
    final Map<String, dynamic>? userStateJson = _asStringKeyMap(
      backup['user_state'],
    );
    if (userStateJson == null) return;
    await prefs.setJson('user_state', userStateJson);
  }

  Future<void> restoreSettings(Map<String, dynamic> backup) async {
    final Map<String, dynamic>? settingsJson = _asStringKeyMap(
      backup['settings'],
    );
    if (settingsJson == null) return;
    await prefs.setJson('settings', settingsJson);
  }

  List<TaskModel> _taskModelsFromRaw(dynamic rawTasks) {
    if (rawTasks is! List) return const <TaskModel>[];
    return rawTasks
        .whereType<Map<dynamic, dynamic>>()
        .map(
          (Map<dynamic, dynamic> item) => item.map(
            (dynamic key, dynamic value) => MapEntry(key.toString(), value),
          ),
        )
        .map(TaskAdapter.fromJson)
        .toList();
  }

  Map<String, dynamic>? _asStringKeyMap(dynamic value) {
    if (value is! Map) return null;
    return value.map(
      (dynamic key, dynamic mapValue) => MapEntry(key.toString(), mapValue),
    );
  }
}
