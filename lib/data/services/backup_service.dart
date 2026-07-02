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
    if (backup['tasks'] is List) {
      final list = backup['tasks'] as List;
      final models = list
          .whereType<Map<String, dynamic>>()
          .map(TaskAdapter.fromJson)
          .toList();
      await taskStorage.clear();
      for (final model in models) {
        await taskStorage.put(model.id, model);
      }
    }

    if (backup['user'] is Map<String, dynamic>) {
      final model = UserAdapter.fromJson(
        backup['user'] as Map<String, dynamic>,
      );
      await userStorage.put('user', model);
    }

    if (backup['user_state'] is Map<String, dynamic>) {
      await prefs.setJson(
        'user_state',
        backup['user_state'] as Map<String, dynamic>,
      );
    }

    if (backup['settings'] is Map<String, dynamic>) {
      await prefs.setJson(
        'settings',
        backup['settings'] as Map<String, dynamic>,
      );
    }
  }

  Future<void> restoreTasks(Map<String, dynamic> backup) async {
    if (backup['tasks'] is! List) return;
    final list = backup['tasks'] as List;
    final models = list
        .whereType<Map<String, dynamic>>()
        .map(TaskAdapter.fromJson)
        .toList();
    await taskStorage.clear();
    for (final model in models) {
      await taskStorage.put(model.id, model);
    }
  }

  Future<void> restoreUser(Map<String, dynamic> backup) async {
    if (backup['user'] is! Map<String, dynamic>) return;
    final model = UserAdapter.fromJson(backup['user'] as Map<String, dynamic>);
    await userStorage.put('user', model);
  }

  Future<void> restoreUserState(Map<String, dynamic> backup) async {
    if (backup['user_state'] is! Map<String, dynamic>) return;
    await prefs.setJson(
      'user_state',
      backup['user_state'] as Map<String, dynamic>,
    );
  }

  Future<void> restoreSettings(Map<String, dynamic> backup) async {
    if (backup['settings'] is! Map<String, dynamic>) return;
    await prefs.setJson('settings', backup['settings'] as Map<String, dynamic>);
  }
}
