import 'dart:convert';

import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/data/local/shared_prefs_storage.dart';
import 'package:fantastic_guacamole/data/services/backup_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

abstract class CloudBackupGateway {
  Future<bool> uploadBackup(Map<String, dynamic> backup);
  Future<Map<String, dynamic>> downloadBackup();
  Future<bool> uploadTasks(Map<String, dynamic> backup);
  Future<Map<String, dynamic>> downloadTasks();
}

class LocalTestCloudBackupGateway implements CloudBackupGateway {
  LocalTestCloudBackupGateway(this._preferences);

  static const String _backupKey = 'local_test_cloud_backup';
  static const String _tasksKey = 'local_test_cloud_tasks';

  final SharedPrefsStorage _preferences;

  @override
  Future<Map<String, dynamic>> downloadBackup() async {
    return _preferences.getJson(_backupKey);
  }

  @override
  Future<Map<String, dynamic>> downloadTasks() async {
    return _preferences.getJson(_tasksKey);
  }

  @override
  Future<bool> uploadBackup(Map<String, dynamic> backup) async {
    await _preferences.setJson(_backupKey, backup);
    return true;
  }

  @override
  Future<bool> uploadTasks(Map<String, dynamic> backup) async {
    await _preferences.setJson(_tasksKey, backup);
    return true;
  }
}

class UnavailableCloudBackupGateway implements CloudBackupGateway {
  const UnavailableCloudBackupGateway();

  @override
  Future<Map<String, dynamic>> downloadBackup() async =>
      const <String, dynamic>{};

  @override
  Future<Map<String, dynamic>> downloadTasks() async =>
      const <String, dynamic>{};

  @override
  Future<bool> uploadBackup(Map<String, dynamic> backup) async => false;

  @override
  Future<bool> uploadTasks(Map<String, dynamic> backup) async => false;
}

class SupabaseStorageCloudBackupGateway implements CloudBackupGateway {
  SupabaseStorageCloudBackupGateway({
    required this._client,
    this.bucket = _defaultBucket,
  });

  static const String _defaultBucket = 'chronospark-sync';
  static const String _backupObject = 'backup/full_backup.json';
  static const String _tasksObject = 'backup/tasks_backup.json';

  final sb.SupabaseClient _client;
  final String bucket;

  @override
  Future<Map<String, dynamic>> downloadBackup() async {
    return _downloadObject(_backupObject);
  }

  @override
  Future<Map<String, dynamic>> downloadTasks() async {
    return _downloadObject(_tasksObject);
  }

  @override
  Future<bool> uploadBackup(Map<String, dynamic> backup) async {
    return _uploadObject(_backupObject, backup);
  }

  @override
  Future<bool> uploadTasks(Map<String, dynamic> backup) async {
    return _uploadObject(_tasksObject, backup);
  }

  Future<Map<String, dynamic>> _downloadObject(String baseObjectPath) async {
    final String objectPath = _scopedPath(baseObjectPath);
    try {
      final List<int> bytes = await _client.storage
          .from(bucket)
          .download(objectPath);
      final Object? decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      Logger.warn(
        'Supabase cloud backup payload is not a map at path: $objectPath',
      );
      return const <String, dynamic>{};
    } on sb.StorageException catch (error) {
      if ((error.statusCode ?? '').contains('404')) {
        return const <String, dynamic>{};
      }
      Logger.errorCategory(
        'Sync Errors',
        'Supabase download failed for $objectPath',
        error,
      );
      return const <String, dynamic>{};
    } catch (error) {
      Logger.errorCategory(
        'Sync Errors',
        'Supabase download failed for $objectPath',
        error,
      );
      return const <String, dynamic>{};
    }
  }

  Future<bool> _uploadObject(
    String baseObjectPath,
    Map<String, dynamic> payload,
  ) async {
    final String objectPath = _scopedPath(baseObjectPath);
    try {
      final String json = jsonEncode(payload);
      await _client.storage
          .from(bucket)
          .uploadBinary(
            objectPath,
            utf8.encode(json),
            fileOptions: const sb.FileOptions(
              cacheControl: '0',
              contentType: 'application/json',
              upsert: true,
            ),
          );
      return true;
    } catch (error) {
      Logger.errorCategory(
        'Sync Errors',
        'Supabase upload failed for $objectPath',
        error,
      );
      return false;
    }
  }

  String _scopedPath(String objectPath) {
    final String uid = _client.auth.currentUser?.id ?? 'anonymous';
    return '$uid/$objectPath';
  }
}

class SyncService {
  SyncService({required this.backup, required this.gateway});

  final BackupService backup;
  final CloudBackupGateway gateway;

  Future<bool> syncToCloud() async {
    final Map<String, dynamic> fullBackup = await backup.createFullBackup();
    return gateway.uploadBackup(fullBackup);
  }

  Future<bool> restoreFromCloud() async {
    final Map<String, dynamic> cloudData = await gateway.downloadBackup();
    if (cloudData.isEmpty) {
      return false;
    }
    await backup.restoreFullBackup(cloudData);
    return true;
  }

  Future<bool> syncDelta() async {
    final Map<String, dynamic> localBackup = await backup.createFullBackup();
    final Map<String, dynamic> cloudBackup = await gateway.downloadBackup();
    if (cloudBackup.isEmpty) {
      return gateway.uploadBackup(localBackup);
    }

    final Map<String, dynamic> merged = _mergeBackups(localBackup, cloudBackup);
    if (!await gateway.uploadBackup(merged)) {
      return false;
    }
    await backup.restoreFullBackup(merged);
    return true;
  }

  Future<bool> syncTasksOnly() async {
    return gateway.uploadTasks(await backup.backupTasks());
  }

  Future<bool> restoreTasksOnly() async {
    final Map<String, dynamic> cloudTasks = await gateway.downloadTasks();
    if (cloudTasks.isEmpty) {
      return false;
    }
    await backup.restoreTasks(cloudTasks);
    return true;
  }

  Map<String, dynamic> _mergeBackups(
    Map<String, dynamic> local,
    Map<String, dynamic> cloud,
  ) {
    final Map<String, dynamic> merged = <String, dynamic>{
      'version': local['version'] ?? cloud['version'],
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    };

    final List<dynamic> localTasks =
        local['tasks'] as List<dynamic>? ?? const <dynamic>[];
    final List<dynamic> cloudTasks =
        cloud['tasks'] as List<dynamic>? ?? const <dynamic>[];
    final Map<String, Map<String, dynamic>> taskMap =
        <String, Map<String, dynamic>>{};

    for (final Map<String, dynamic> task
        in cloudTasks.whereType<Map<String, dynamic>>()) {
      final String id = task['id']?.toString() ?? '';
      if (id.isNotEmpty) {
        taskMap[id] = task;
      }
    }

    for (final Map<String, dynamic> task
        in localTasks.whereType<Map<String, dynamic>>()) {
      final String id = task['id']?.toString() ?? '';
      if (id.isEmpty) {
        continue;
      }
      final Map<String, dynamic>? cloudTask = taskMap[id];
      if (cloudTask == null ||
          !_taskTimestamp(task).isBefore(_taskTimestamp(cloudTask))) {
        taskMap[id] = task;
      }
    }

    merged['tasks'] = taskMap.values.toList(growable: false);
    merged['profile'] = local['profile'] ?? cloud['profile'] ?? cloud['user'];
    merged['settings'] = local['settings'] ?? cloud['settings'];
    return merged;
  }

  DateTime _taskTimestamp(Map<String, dynamic> task) {
    for (final String key in <String>[
      'updatedAt',
      'completedAt',
      'createdAt',
    ]) {
      final DateTime? parsed = DateTime.tryParse(task[key]?.toString() ?? '');
      if (parsed != null) {
        return parsed;
      }
    }
    return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }
}
