import 'package:fantastic_guacamole/data/local/shared_prefs_storage.dart';
import 'package:fantastic_guacamole/data/services/backup_service.dart';

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
