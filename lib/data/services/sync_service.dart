import 'package:fantastic_guacamole/data/services/backup_service.dart';
import 'package:fantastic_guacamole/data/local/shared_prefs_storage.dart';
import 'package:fantastic_guacamole/data/local/hive_storage.dart';
import 'package:fantastic_guacamole/features/tasks/models/tasks_models.dart';
import 'package:fantastic_guacamole/features/user/models/user_model.dart';

/// ChronoSpark SyncService
class SyncService {
  final BackupService backup;
  final SharedPrefsStorage prefs;
  final HiveStorage<TaskModel> taskStorage;
  final HiveStorage<UserModel> userStorage;

  SyncService({
    required this.backup,
    required this.prefs,
    required this.taskStorage,
    required this.userStorage,
  });

  Future<Map<String, dynamic>> _uploadToCloud(
    Map<String, dynamic> payload,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return {'status': 'ok', 'echo': payload};
  }

  Future<Map<String, dynamic>> _downloadFromCloud() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return prefs.getJson('cloud_backup_mock');
  }

  Future<bool> syncToCloud() async {
    final fullBackup = await backup.createFullBackup();
    final response = await _uploadToCloud(fullBackup);

    if (response['status'] == 'ok') {
      await prefs.setJson('cloud_backup_mock', fullBackup);
      return true;
    }

    return false;
  }

  Future<bool> restoreFromCloud() async {
    final cloudData = await _downloadFromCloud();
    if (cloudData.isEmpty) return false;

    await backup.restoreFullBackup(cloudData);
    return true;
  }

  Future<bool> syncDelta() async {
    final localBackup = await backup.createFullBackup();
    final cloudBackup = await _downloadFromCloud();

    if (cloudBackup.isEmpty) {
      return syncToCloud();
    }

    final merged = _mergeBackups(localBackup, cloudBackup);
    await prefs.setJson('cloud_backup_mock', merged);
    await backup.restoreFullBackup(merged);

    return true;
  }

  Map<String, dynamic> _mergeBackups(
    Map<String, dynamic> local,
    Map<String, dynamic> cloud,
  ) {
    final merged = <String, dynamic>{};

    merged['version'] = local['version'] ?? cloud['version'];
    merged['timestamp'] = DateTime.now().toIso8601String();

    final localTasks = (local['tasks'] ?? <dynamic>[]) as List<dynamic>;
    final cloudTasks = (cloud['tasks'] ?? <dynamic>[]) as List<dynamic>;

    final taskMap = <String, Map<String, dynamic>>{};

    for (final t in cloudTasks.whereType<Map<String, dynamic>>()) {
      taskMap[t['id'] as String] = t;
    }

    for (final t in localTasks.whereType<Map<String, dynamic>>()) {
      final id = t['id'] as String;
      if (!taskMap.containsKey(id)) {
        taskMap[id] = t;
      } else {
        final localUpdated =
            DateTime.tryParse(t['updatedAt'] as String? ?? '') ??
            DateTime.now();
        final cloudUpdated =
            DateTime.tryParse(taskMap[id]!['updatedAt'] as String? ?? '') ??
            DateTime.now();
        taskMap[id] = localUpdated.isAfter(cloudUpdated) ? t : taskMap[id]!;
      }
    }

    merged['tasks'] = taskMap.values.toList();
    merged['user'] = local['user'] ?? cloud['user'];
    merged['user_state'] = local['user_state'] ?? cloud['user_state'];
    merged['settings'] = local['settings'] ?? cloud['settings'];

    return merged;
  }

  Future<bool> syncTasksOnly() async {
    final backupTasks = await backup.backupTasks();
    final response = await _uploadToCloud(backupTasks);

    if (response['status'] == 'ok') {
      await prefs.setJson('cloud_tasks_mock', backupTasks);
      return true;
    }

    return false;
  }

  Future<bool> restoreTasksOnly() async {
    final cloudTasks = prefs.getJson('cloud_tasks_mock');
    if (cloudTasks.isEmpty) return false;
    await backup.restoreTasks(cloudTasks);
    return true;
  }
}
