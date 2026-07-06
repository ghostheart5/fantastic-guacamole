import 'dart:convert';

import 'package:fantastic_guacamole/data/local/hive_storage.dart';
import 'package:fantastic_guacamole/data/local/shared_prefs_storage.dart';
import 'package:fantastic_guacamole/data/local/task_entity_mapper.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';

class BackupService {
  BackupService({
    required this.taskRepository,
    required this.profileStorage,
    required this.prefs,
    this.secureProfileStore,
  });

  static const String _profileStateKey = 'profile_state';

  final ITaskRepository taskRepository;
  final HiveStorage<String> profileStorage;
  final SharedPrefsStorage prefs;
  final SecureStore? secureProfileStore;
  static const String _secureProfileStateKey = 'profile_state_v2';

  Future<Map<String, dynamic>> createFullBackup() async {
    final List<TaskEntity> tasks = await taskRepository.getAllTasks();
    final Map<String, dynamic>? profile = _decodeProfile(await _readProfile());
    final Map<String, dynamic> settings = prefs.getJson('settings');

    return <String, dynamic>{
      'version': '3.0.0',
      'timestamp': DateTime.now().toIso8601String(),
      'tasks': tasks.map(TaskEntityMapper.toJson).toList(),
      'profile': profile,
      'settings': settings,
    };
  }

  Future<Map<String, dynamic>> backupTasks() async {
    final List<TaskEntity> tasks = await taskRepository.getAllTasks();
    return <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'tasks': tasks.map(TaskEntityMapper.toJson).toList(),
    };
  }

  Future<Map<String, dynamic>> backupProfile() async {
    return <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'profile': _decodeProfile(await _readProfile()),
    };
  }

  Future<Map<String, dynamic>> backupSettings() async {
    return <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'settings': prefs.getJson('settings'),
    };
  }

  Future<String> exportFullBackupString() async {
    return jsonEncode(await createFullBackup());
  }

  Future<String> exportTasksString() async {
    return jsonEncode(await backupTasks());
  }

  Future<void> restoreFullBackup(Map<String, dynamic> backup) async {
    await restoreTasks(backup);

    final Map<String, dynamic>? profile =
        _asStringKeyMap(backup['profile']) ??
        _profileFromLegacyUser(backup['user']);
    if (profile != null) {
      await _writeProfile(jsonEncode(profile));
    }

    final Map<String, dynamic>? settings = _asStringKeyMap(backup['settings']);
    if (settings != null) {
      await prefs.setJson('settings', settings);
    }
  }

  Future<void> restoreTasks(Map<String, dynamic> backup) async {
    final List<TaskEntity>? restoredTasks = _taskEntitiesFromRaw(
      backup['tasks'],
    );
    if (restoredTasks == null) {
      return;
    }

    final List<TaskEntity> existing = await taskRepository.getAllTasks();
    for (final TaskEntity task in existing) {
      await taskRepository.deleteTask(task.id);
    }
    for (final TaskEntity task in restoredTasks) {
      await taskRepository.saveTask(task);
    }
  }

  Future<void> restoreProfile(Map<String, dynamic> backup) async {
    final Map<String, dynamic>? profile =
        _asStringKeyMap(backup['profile']) ??
        _profileFromLegacyUser(backup['user']);
    if (profile == null) {
      return;
    }
    await _writeProfile(jsonEncode(profile));
  }

  Future<void> restoreSettings(Map<String, dynamic> backup) async {
    final Map<String, dynamic>? settings = _asStringKeyMap(backup['settings']);
    if (settings == null) {
      return;
    }
    await prefs.setJson('settings', settings);
  }

  Map<String, dynamic>? _decodeProfile(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    try {
      return _asStringKeyMap(jsonDecode(raw));
    } on FormatException {
      return null;
    }
  }

  Future<String?> _readProfile() async {
    final SecureStore? secure = secureProfileStore;
    if (secure != null) {
      final String? secured = await secure.readString(_secureProfileStateKey);
      if (secured != null) return secured;
    }
    await profileStorage.open();
    final String? legacy = profileStorage.get(_profileStateKey);
    if (legacy != null && secure != null) {
      await secure.writeString(_secureProfileStateKey, legacy);
      await profileStorage.delete(_profileStateKey);
    }
    return legacy;
  }

  Future<void> _writeProfile(String value) async {
    final SecureStore? secure = secureProfileStore;
    if (secure != null) {
      await secure.writeString(_secureProfileStateKey, value);
      return;
    }
    await profileStorage.put(_profileStateKey, value);
  }

  Map<String, dynamic>? _profileFromLegacyUser(dynamic rawUser) {
    final Map<String, dynamic>? user = _asStringKeyMap(rawUser);
    final String name = user?['name']?.toString().trim() ?? '';
    if (name.isEmpty) {
      return null;
    }
    return <String, dynamic>{
      'xp': 0,
      'level': 1,
      'streak': 0,
      'longestStreak': 0,
      'name': name,
      'soundEnabled': true,
      'lastActiveDate': null,
    };
  }

  List<TaskEntity>? _taskEntitiesFromRaw(dynamic rawTasks) {
    if (rawTasks is! List) {
      return null;
    }

    final List<TaskEntity> tasks = <TaskEntity>[];
    for (final Map<dynamic, dynamic> item
        in rawTasks.whereType<Map<dynamic, dynamic>>()) {
      try {
        final TaskEntity task = TaskEntityMapper.fromJson(
          item.map(
            (dynamic key, dynamic value) => MapEntry(key.toString(), value),
          ),
        );
        if (task.id.trim().isNotEmpty) {
          tasks.add(task);
        }
      } catch (_) {
        // Ignore individual malformed legacy records when other records remain
        // recoverable.
      }
    }
    if (rawTasks.isNotEmpty && tasks.isEmpty) {
      throw const FormatException('Backup contains no valid task records.');
    }
    return tasks;
  }

  Map<String, dynamic>? _asStringKeyMap(dynamic value) {
    if (value is! Map) {
      return null;
    }
    return value.map(
      (dynamic key, dynamic mapValue) => MapEntry(key.toString(), mapValue),
    );
  }
}
