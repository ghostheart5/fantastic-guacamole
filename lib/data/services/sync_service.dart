import 'dart:convert';

import 'package:fantastic_guacamole/config/launch_containment.dart';
import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/data/local/shared_prefs_storage.dart';
import 'package:fantastic_guacamole/data/services/backup_service.dart';
import 'package:fantastic_guacamole/data/services/backup_cipher.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

enum CloudBackupReadStatus {
  found,
  notFound,
  unavailable,
  malformed,
  ownerMismatch,
}

class CloudBackupReadResult {
  const CloudBackupReadResult._(this.status, this.payload);

  const CloudBackupReadResult.found(Map<String, dynamic> payload)
    : this._(CloudBackupReadStatus.found, payload);
  const CloudBackupReadResult.notFound()
    : this._(CloudBackupReadStatus.notFound, null);
  const CloudBackupReadResult.unavailable()
    : this._(CloudBackupReadStatus.unavailable, null);
  const CloudBackupReadResult.malformed()
    : this._(CloudBackupReadStatus.malformed, null);
  const CloudBackupReadResult.ownerMismatch()
    : this._(CloudBackupReadStatus.ownerMismatch, null);

  final CloudBackupReadStatus status;
  final Map<String, dynamic>? payload;
}

enum CloudRestoreOutcome {
  restored,
  notFound,
  unavailable,
  malformed,
  ownerMismatch,
  accountChanged,
  migrationFailed,
  disabled,
}

abstract class CloudBackupGateway {
  Future<bool> uploadBackup(Map<String, dynamic> backup);
  Future<CloudBackupReadResult> downloadBackup();
  Future<bool> uploadTasks(Map<String, dynamic> backup);
  Future<CloudBackupReadResult> downloadTasks();
}

class LocalTestCloudBackupGateway implements CloudBackupGateway {
  LocalTestCloudBackupGateway(this._preferences);

  static const String _backupKey = 'local_test_cloud_backup';
  static const String _tasksKey = 'local_test_cloud_tasks';

  final SharedPrefsStorage _preferences;

  @override
  Future<CloudBackupReadResult> downloadBackup() async {
    return _download(_backupKey);
  }

  @override
  Future<CloudBackupReadResult> downloadTasks() async {
    return _download(_tasksKey);
  }

  CloudBackupReadResult _download(String key) {
    if (!_preferences.contains(key)) {
      return const CloudBackupReadResult.notFound();
    }
    final String? raw = _preferences.getString(key);
    if (raw == null) return const CloudBackupReadResult.malformed();
    try {
      final Object? decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic>
          ? CloudBackupReadResult.found(decoded)
          : const CloudBackupReadResult.malformed();
    } on FormatException {
      return const CloudBackupReadResult.malformed();
    }
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
  Future<CloudBackupReadResult> downloadBackup() async =>
      const CloudBackupReadResult.unavailable();

  @override
  Future<CloudBackupReadResult> downloadTasks() async =>
      const CloudBackupReadResult.unavailable();

  @override
  Future<bool> uploadBackup(Map<String, dynamic> backup) async => false;

  @override
  Future<bool> uploadTasks(Map<String, dynamic> backup) async => false;
}

class SupabaseStorageCloudBackupGateway implements CloudBackupGateway {
  SupabaseStorageCloudBackupGateway({
    required this._client,
    required this.expectedUserId,
    this.bucket = _defaultBucket,
  });

  static const String _defaultBucket = 'chronospark-sync';
  static const String _backupObject = 'backup/full_backup.json';
  static const String _tasksObject = 'backup/tasks_backup.json';

  final sb.SupabaseClient _client;
  final String expectedUserId;
  final String bucket;

  @override
  Future<CloudBackupReadResult> downloadBackup() async {
    return _downloadObject(_backupObject);
  }

  @override
  Future<CloudBackupReadResult> downloadTasks() async {
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

  Future<CloudBackupReadResult> _downloadObject(String baseObjectPath) async {
    if (!_hasExpectedUser) {
      return const CloudBackupReadResult.ownerMismatch();
    }
    final String objectPath = _scopedPath(baseObjectPath);
    try {
      final List<int> bytes = await _client.storage
          .from(bucket)
          .download(objectPath);
      final Object? decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is Map<String, dynamic>) {
        return CloudBackupReadResult.found(decoded);
      }
      Logger.warn('Supabase cloud backup payload is not a JSON object.');
      return const CloudBackupReadResult.malformed();
    } on sb.StorageException catch (error) {
      if ((error.statusCode ?? '').contains('404')) {
        return const CloudBackupReadResult.notFound();
      }
      Logger.errorCategory(
        'Sync Errors',
        'Supabase cloud backup download failed',
        error,
      );
      return const CloudBackupReadResult.unavailable();
    } on FormatException {
      Logger.warn('Supabase cloud backup payload contains malformed JSON.');
      return const CloudBackupReadResult.malformed();
    } on Object catch (error) {
      Logger.errorCategory(
        'Sync Errors',
        'Supabase cloud backup download failed',
        error,
      );
      return const CloudBackupReadResult.unavailable();
    }
  }

  Future<bool> _uploadObject(
    String baseObjectPath,
    Map<String, dynamic> payload,
  ) async {
    if (!_hasExpectedUser) {
      return false;
    }
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
    return '$expectedUserId/$objectPath';
  }

  bool get _hasExpectedUser =>
      expectedUserId.isNotEmpty &&
      _client.auth.currentUser?.id == expectedUserId;
}

class SyncService {
  SyncService({
    required this.backup,
    required this.gateway,
    SecureStore? secureStore,
    this.expectedAccountId,
    this.currentAccountId,
    this.syncEnabled = LaunchContainment.cloudSyncEnabled,
    this.restoreEnabled = LaunchContainment.cloudRestoreEnabled,
  }) : _cipher = secureStore == null ? null : BackupCipher(secureStore);

  final BackupService backup;
  final CloudBackupGateway gateway;
  final BackupCipher? _cipher;
  final String? expectedAccountId;
  final String? Function()? currentAccountId;
  final bool syncEnabled;
  final bool restoreEnabled;

  Future<bool> syncToCloud() async {
    if (!syncEnabled || !_accountStillCurrent) return false;
    final Map<String, dynamic> fullBackup = await backup.createFullBackup();
    final Map<String, dynamic> protectedBackup = _cipher == null
        ? fullBackup
        : await _cipher.encryptPayload(fullBackup);
    return gateway.uploadBackup(protectedBackup);
  }

  Future<CloudRestoreOutcome> restoreFromCloud() async {
    if (!restoreEnabled) return CloudRestoreOutcome.disabled;
    if (!_accountStillCurrent) return CloudRestoreOutcome.accountChanged;
    final CloudBackupReadResult read = await gateway.downloadBackup();
    final CloudRestoreOutcome? readFailure = _restoreFailureFor(read.status);
    if (readFailure != null) return readFailure;
    final Map<String, dynamic> cloudData = read.payload!;
    final bool migrateLegacyPlaintext =
        _cipher != null && _cipher.isLegacyPlaintextBackup(cloudData);
    final Map<String, dynamic> restored = _cipher == null
        ? cloudData
        : await _cipher.decryptPayload(cloudData);
    if (migrateLegacyPlaintext) {
      final Map<String, dynamic> encrypted = await _cipher.encryptPayload(
        restored,
      );
      if (!await gateway.uploadBackup(encrypted)) {
        Logger.warn(
          'Refused to restore legacy plaintext backup before migration.',
        );
        return CloudRestoreOutcome.migrationFailed;
      }
    }
    if (!_accountStillCurrent) return CloudRestoreOutcome.accountChanged;
    await backup.restoreFullBackup(restored);
    return CloudRestoreOutcome.restored;
  }

  Future<bool> syncDelta() async {
    if (!syncEnabled || !_accountStillCurrent) return false;
    final Map<String, dynamic> localBackup = await backup.createFullBackup();
    final CloudBackupReadResult read = await gateway.downloadBackup();
    if (read.status == CloudBackupReadStatus.notFound) {
      final Map<String, dynamic> protectedLocal = _cipher == null
          ? localBackup
          : await _cipher.encryptPayload(localBackup);
      return gateway.uploadBackup(protectedLocal);
    }
    if (read.status != CloudBackupReadStatus.found) {
      return false;
    }
    final Map<String, dynamic> downloaded = read.payload!;
    final Map<String, dynamic> cloudBackup = _cipher == null
        ? downloaded
        : await _cipher.decryptPayload(downloaded);

    final Map<String, dynamic> merged = _mergeBackups(localBackup, cloudBackup);
    final Map<String, dynamic> protectedMerged = _cipher == null
        ? merged
        : await _cipher.encryptPayload(merged);
    if (!await gateway.uploadBackup(protectedMerged)) {
      return false;
    }
    if (!_accountStillCurrent) return false;
    await backup.restoreFullBackup(merged);
    return true;
  }

  Future<bool> syncTasksOnly() async {
    if (!syncEnabled || !_accountStillCurrent) return false;
    final Map<String, dynamic> tasks = await backup.backupTasks();
    return gateway.uploadTasks(
      _cipher == null ? tasks : await _cipher.encryptPayload(tasks),
    );
  }

  Future<bool> restoreTasksOnly() async {
    if (!restoreEnabled) return false;
    if (!_accountStillCurrent) return false;
    final CloudBackupReadResult read = await gateway.downloadTasks();
    if (read.status != CloudBackupReadStatus.found) {
      return false;
    }
    final Map<String, dynamic> cloudTasks = read.payload!;
    if (!_accountStillCurrent) return false;
    await backup.restoreTasks(
      _cipher == null ? cloudTasks : await _cipher.decryptPayload(cloudTasks),
    );
    return true;
  }

  Map<String, dynamic> _mergeBackups(
    Map<String, dynamic> local,
    Map<String, dynamic> cloud,
  ) {
    final Map<String, dynamic> merged = <String, dynamic>{
      'version': local['version'] ?? cloud['version'],
      'manifest': local['manifest'] ?? cloud['manifest'],
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

  CloudRestoreOutcome? _restoreFailureFor(CloudBackupReadStatus status) {
    return switch (status) {
      CloudBackupReadStatus.found => null,
      CloudBackupReadStatus.notFound => CloudRestoreOutcome.notFound,
      CloudBackupReadStatus.unavailable => CloudRestoreOutcome.unavailable,
      CloudBackupReadStatus.malformed => CloudRestoreOutcome.malformed,
      CloudBackupReadStatus.ownerMismatch => CloudRestoreOutcome.ownerMismatch,
    };
  }

  bool get _accountStillCurrent {
    final String expected = expectedAccountId?.trim() ?? '';
    final String? Function()? current = currentAccountId;
    if (expected.isEmpty && current == null) return true;
    return expected.isNotEmpty && current?.call() == expected;
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
