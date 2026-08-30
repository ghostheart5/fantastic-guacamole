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
  const CloudBackupReadResult._(this.status, this.payload, this.revision);

  const CloudBackupReadResult.found(this.payload, {this.revision = 1})
    : assert(payload != null),
      status = CloudBackupReadStatus.found;
  const CloudBackupReadResult.notFound()
    : this._(CloudBackupReadStatus.notFound, null, null);
  const CloudBackupReadResult.unavailable()
    : this._(CloudBackupReadStatus.unavailable, null, null);
  const CloudBackupReadResult.malformed()
    : this._(CloudBackupReadStatus.malformed, null, null);
  const CloudBackupReadResult.ownerMismatch()
    : this._(CloudBackupReadStatus.ownerMismatch, null, null);

  final CloudBackupReadStatus status;
  final Map<String, dynamic>? payload;
  final int? revision;
}

enum CloudBackupWriteStatus {
  written,
  conflict,
  unavailable,
  ownerMismatch,
  malformed,
}

class CloudBackupWriteResult {
  const CloudBackupWriteResult._(this.status, this.revision);

  const CloudBackupWriteResult.written(int revision)
    : this._(CloudBackupWriteStatus.written, revision);
  const CloudBackupWriteResult.conflict([int? revision])
    : this._(CloudBackupWriteStatus.conflict, revision);
  const CloudBackupWriteResult.unavailable()
    : this._(CloudBackupWriteStatus.unavailable, null);
  const CloudBackupWriteResult.ownerMismatch()
    : this._(CloudBackupWriteStatus.ownerMismatch, null);
  const CloudBackupWriteResult.malformed()
    : this._(CloudBackupWriteStatus.malformed, null);

  final CloudBackupWriteStatus status;
  final int? revision;
}

enum LegacyFullBackupCleanupStatus {
  removedOrAbsent,
  unavailable,
  ownerMismatch,
}

abstract interface class LegacyFullBackupCleanup {
  Future<LegacyFullBackupCleanupStatus> deleteLegacyFullBackup();
}

enum CloudRestoreOutcome {
  restored,
  restoredLegacyCleanupPending,
  notFound,
  unavailable,
  recoveryKeyRequired,
  conflict,
  malformed,
  ownerMismatch,
  accountChanged,
  migrationFailed,
  disabled,
}

enum CloudSyncOutcome {
  synced,
  disabled,
  accountChanged,
  unavailable,
  recoveryKeyRequired,
  conflict,
  malformed,
  ownerMismatch,
  uploadFailed,
}

abstract class CloudBackupGateway {
  Future<bool> uploadBackup(Map<String, dynamic> backup);
  Future<CloudBackupReadResult> downloadBackup();
  Future<bool> uploadTasks(Map<String, dynamic> backup);
  Future<CloudBackupReadResult> downloadTasks();

  Future<CloudBackupWriteResult> compareAndSwapBackup(
    Map<String, dynamic> backup, {
    required int expectedRevision,
  }) async {
    return const CloudBackupWriteResult.unavailable();
  }
}

class LocalTestCloudBackupGateway implements CloudBackupGateway {
  LocalTestCloudBackupGateway(this._preferences);

  static const String _backupKey = 'local_test_cloud_backup';
  static const String _backupRevisionKey = 'local_test_cloud_backup_revision';
  static const String _tasksKey = 'local_test_cloud_tasks';

  final SharedPrefsStorage _preferences;

  @override
  Future<CloudBackupReadResult> downloadBackup() async {
    final CloudBackupReadResult read = _download(_backupKey);
    if (read.status != CloudBackupReadStatus.found) return read;
    return CloudBackupReadResult.found(
      read.payload,
      revision: _preferences.getIntOrDefault(_backupRevisionKey, 1),
    );
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
    final int revision = _preferences.contains(_backupKey)
        ? _preferences.getIntOrDefault(_backupRevisionKey, 1)
        : 0;
    return (await compareAndSwapBackup(
          backup,
          expectedRevision: revision,
        )).status ==
        CloudBackupWriteStatus.written;
  }

  @override
  Future<CloudBackupWriteResult> compareAndSwapBackup(
    Map<String, dynamic> backup, {
    required int expectedRevision,
  }) async {
    final int currentRevision = _preferences.contains(_backupKey)
        ? _preferences.getIntOrDefault(_backupRevisionKey, 1)
        : 0;
    if (currentRevision != expectedRevision) {
      return CloudBackupWriteResult.conflict(currentRevision);
    }
    final int nextRevision = expectedRevision + 1;
    await _preferences.setJson(_backupKey, backup);
    await _preferences.setInt(_backupRevisionKey, nextRevision);
    return CloudBackupWriteResult.written(nextRevision);
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

  @override
  Future<CloudBackupWriteResult> compareAndSwapBackup(
    Map<String, dynamic> backup, {
    required int expectedRevision,
  }) async => const CloudBackupWriteResult.unavailable();
}

class SupabaseStorageCloudBackupGateway
    implements CloudBackupGateway, LegacyFullBackupCleanup {
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

  @override
  Future<LegacyFullBackupCleanupStatus> deleteLegacyFullBackup() async {
    if (!_hasExpectedUser) {
      return LegacyFullBackupCleanupStatus.ownerMismatch;
    }
    try {
      await _client.storage.from(bucket).remove(<String>[
        _scopedPath(_backupObject),
      ]);
      return LegacyFullBackupCleanupStatus.removedOrAbsent;
    } on Object {
      Logger.errorCategory(
        'Sync Errors',
        'Supabase legacy cloud backup cleanup failed',
      );
      return LegacyFullBackupCleanupStatus.unavailable;
    }
  }

  @override
  Future<CloudBackupWriteResult> compareAndSwapBackup(
    Map<String, dynamic> backup, {
    required int expectedRevision,
  }) async => const CloudBackupWriteResult.unavailable();

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
      );
      return const CloudBackupReadResult.unavailable();
    } on FormatException {
      Logger.warn('Supabase cloud backup payload contains malformed JSON.');
      return const CloudBackupReadResult.malformed();
    } on Object {
      Logger.errorCategory(
        'Sync Errors',
        'Supabase cloud backup download failed',
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
    } catch (_) {
      Logger.errorCategory(
        'Sync Errors',
        'Supabase cloud backup upload failed',
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

class SupabaseCasCloudBackupGateway
    implements CloudBackupGateway, LegacyFullBackupCleanup {
  SupabaseCasCloudBackupGateway({
    required sb.SupabaseClient client,
    required this.expectedUserId,
    String legacyBucket = 'chronospark-sync',
  }) : _client = client,
       _legacy = SupabaseStorageCloudBackupGateway(
         client: client,
         expectedUserId: expectedUserId,
         bucket: legacyBucket,
       );

  static const String _table = 'cloud_backup_snapshots';
  static const int maxPayloadBytes = 5 * 1024 * 1024;

  final sb.SupabaseClient _client;
  final String expectedUserId;
  final SupabaseStorageCloudBackupGateway _legacy;

  @override
  Future<CloudBackupReadResult> downloadBackup() async {
    if (!_hasExpectedUser) {
      return const CloudBackupReadResult.ownerMismatch();
    }
    try {
      final List<dynamic> rows = await _client
          .from(_table)
          .select('revision,payload')
          .eq('user_id', expectedUserId)
          .limit(1);
      if (rows.isEmpty) {
        final CloudBackupReadResult legacy = await _legacy.downloadBackup();
        if (legacy.status != CloudBackupReadStatus.found) return legacy;
        return CloudBackupReadResult.found(legacy.payload, revision: 0);
      }
      final Map<String, dynamic>? row = _stringKeyMap(rows.single);
      final int? revision = (row?['revision'] as num?)?.toInt();
      final Map<String, dynamic>? payload = _stringKeyMap(row?['payload']);
      if (revision == null || revision < 1 || payload == null) {
        return const CloudBackupReadResult.malformed();
      }
      return CloudBackupReadResult.found(payload, revision: revision);
    } on Object {
      Logger.errorCategory(
        'Sync Errors',
        'Supabase versioned cloud backup download failed',
      );
      return const CloudBackupReadResult.unavailable();
    }
  }

  @override
  Future<CloudBackupWriteResult> compareAndSwapBackup(
    Map<String, dynamic> backup, {
    required int expectedRevision,
  }) async {
    if (!_hasExpectedUser) {
      return const CloudBackupWriteResult.ownerMismatch();
    }
    if (expectedRevision < 0) {
      return const CloudBackupWriteResult.malformed();
    }
    try {
      if (utf8.encode(jsonEncode(backup)).length > maxPayloadBytes) {
        return const CloudBackupWriteResult.malformed();
      }
    } on Object {
      return const CloudBackupWriteResult.malformed();
    }
    try {
      final List<dynamic> rows;
      if (expectedRevision == 0) {
        rows = await _client
            .from(_table)
            .insert(<String, dynamic>{
              'user_id': expectedUserId,
              'revision': 1,
              'payload': backup,
            })
            .select('revision');
      } else {
        rows = await _client
            .from(_table)
            .update(<String, dynamic>{
              'revision': expectedRevision + 1,
              'payload': backup,
            })
            .eq('user_id', expectedUserId)
            .eq('revision', expectedRevision)
            .select('revision');
      }
      if (rows.length == 1) {
        final Map<String, dynamic>? row = _stringKeyMap(rows.single);
        final int? revision = (row?['revision'] as num?)?.toInt();
        if (revision == expectedRevision + 1) {
          return CloudBackupWriteResult.written(revision!);
        }
        return const CloudBackupWriteResult.malformed();
      }
      return _classifyWriteMiss();
    } on sb.PostgrestException {
      return _classifyWriteMiss();
    } on Object {
      Logger.errorCategory(
        'Sync Errors',
        'Supabase versioned cloud backup write failed',
      );
      return const CloudBackupWriteResult.unavailable();
    }
  }

  Future<CloudBackupWriteResult> _classifyWriteMiss() async {
    final CloudBackupReadResult current = await downloadBackup();
    return switch (current.status) {
      CloudBackupReadStatus.found => CloudBackupWriteResult.conflict(
        current.revision,
      ),
      CloudBackupReadStatus.ownerMismatch =>
        const CloudBackupWriteResult.ownerMismatch(),
      CloudBackupReadStatus.malformed =>
        const CloudBackupWriteResult.malformed(),
      CloudBackupReadStatus.notFound || CloudBackupReadStatus.unavailable =>
        const CloudBackupWriteResult.unavailable(),
    };
  }

  @override
  Future<bool> uploadBackup(Map<String, dynamic> backup) async => false;

  @override
  Future<CloudBackupReadResult> downloadTasks() => _legacy.downloadTasks();

  @override
  Future<bool> uploadTasks(Map<String, dynamic> backup) =>
      _legacy.uploadTasks(backup);

  @override
  Future<LegacyFullBackupCleanupStatus> deleteLegacyFullBackup() =>
      _legacy.deleteLegacyFullBackup();

  bool get _hasExpectedUser =>
      expectedUserId.isNotEmpty &&
      _client.auth.currentUser?.id == expectedUserId;

  Map<String, dynamic>? _stringKeyMap(Object? value) {
    if (value is! Map) return null;
    return value.map<String, dynamic>(
      (dynamic key, dynamic item) => MapEntry(key.toString(), item),
    );
  }
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
  }) : _cipher = secureStore == null
           ? null
           : BackupCipher(secureStore, accountId: expectedAccountId);

  final BackupService backup;
  final CloudBackupGateway gateway;
  final BackupCipher? _cipher;
  final String? expectedAccountId;
  final String? Function()? currentAccountId;
  final bool syncEnabled;
  final bool restoreEnabled;

  Future<bool> syncToCloud() async {
    return syncDelta();
  }

  Future<CloudRestoreOutcome> restoreFromCloud() async {
    if (!restoreEnabled) return CloudRestoreOutcome.disabled;
    if (!_accountStillCurrent) return CloudRestoreOutcome.accountChanged;
    final int localGeneration = backup.localGeneration;
    final CloudBackupReadResult read = await gateway.downloadBackup();
    final CloudRestoreOutcome? readFailure = _restoreFailureFor(read.status);
    if (readFailure != null) return readFailure;
    final Map<String, dynamic> cloudData = read.payload!;
    final bool migrateLegacyPlaintext =
        _cipher != null && _cipher.isLegacyPlaintextBackup(cloudData);
    final Map<String, dynamic> restored;
    try {
      restored = _cipher == null
          ? cloudData
          : await _cipher.decryptPayload(cloudData);
      backup.validateFullBackup(restored);
    } on BackupRecoveryKeyRequiredException {
      return CloudRestoreOutcome.recoveryKeyRequired;
    } on Object {
      return CloudRestoreOutcome.malformed;
    }
    bool legacyCleanupPending = false;
    if (migrateLegacyPlaintext) {
      if (!_accountStillCurrent) return CloudRestoreOutcome.accountChanged;
      final int? expectedRevision = read.revision;
      if (expectedRevision == null || expectedRevision < 0) {
        return CloudRestoreOutcome.malformed;
      }
      final Map<String, dynamic> encrypted = await _cipher.encryptPayload(
        restored,
      );
      if (!_accountStillCurrent) return CloudRestoreOutcome.accountChanged;
      final CloudBackupWriteResult migration = await gateway
          .compareAndSwapBackup(encrypted, expectedRevision: expectedRevision);
      if (!_accountStillCurrent) return CloudRestoreOutcome.accountChanged;
      if (migration.status == CloudBackupWriteStatus.conflict) {
        return CloudRestoreOutcome.conflict;
      }
      if (migration.status != CloudBackupWriteStatus.written) {
        Logger.warn(
          'Refused to restore legacy plaintext backup before migration.',
        );
        return CloudRestoreOutcome.migrationFailed;
      }
      final CloudBackupReadResult verified = await gateway.downloadBackup();
      if (!_accountStillCurrent) return CloudRestoreOutcome.accountChanged;
      if (!await _isVerifiedLegacyMigration(
        verified,
        expectedRevision: migration.revision,
        expectedPlaintext: restored,
      )) {
        Logger.warn(
          'Refused to restore legacy plaintext backup before verified migration.',
        );
        return CloudRestoreOutcome.migrationFailed;
      }
      if (expectedRevision == 0) {
        final LegacyFullBackupCleanupStatus? cleanup =
            await _deleteLegacyFullBackup();
        if (!_accountStillCurrent) return CloudRestoreOutcome.accountChanged;
        if (cleanup == LegacyFullBackupCleanupStatus.ownerMismatch) {
          return CloudRestoreOutcome.ownerMismatch;
        }
        legacyCleanupPending =
            cleanup != LegacyFullBackupCleanupStatus.removedOrAbsent;
      }
    } else if (_cipher != null &&
        read.revision != null &&
        read.revision! >= 1 &&
        gateway is LegacyFullBackupCleanup) {
      final LegacyFullBackupCleanupStatus? cleanup =
          await _deleteLegacyFullBackup();
      if (!_accountStillCurrent) return CloudRestoreOutcome.accountChanged;
      if (cleanup == LegacyFullBackupCleanupStatus.ownerMismatch) {
        return CloudRestoreOutcome.ownerMismatch;
      }
      legacyCleanupPending =
          cleanup != LegacyFullBackupCleanupStatus.removedOrAbsent;
    }
    if (!_accountStillCurrent) return CloudRestoreOutcome.accountChanged;
    try {
      await backup.restoreFullBackup(
        restored,
        canContinue: () => _accountStillCurrent,
        expectedLocalGeneration: localGeneration,
      );
      return legacyCleanupPending
          ? CloudRestoreOutcome.restoredLegacyCleanupPending
          : CloudRestoreOutcome.restored;
    } on BackupRestoreCancelledException {
      return CloudRestoreOutcome.accountChanged;
    } on BackupConcurrentMutationException {
      return CloudRestoreOutcome.conflict;
    }
  }

  Future<bool> syncDelta() async {
    return await syncDeltaOutcome() == CloudSyncOutcome.synced;
  }

  Future<CloudSyncOutcome> syncDeltaOutcome() async {
    if (!syncEnabled) return CloudSyncOutcome.disabled;
    if (!_accountStillCurrent) return CloudSyncOutcome.accountChanged;
    final VersionedBackupSnapshot localSnapshot = await backup
        .createVersionedFullBackup();
    final Map<String, dynamic> localBackup = localSnapshot.payload;
    final CloudBackupReadResult read = await gateway.downloadBackup();
    if (read.status == CloudBackupReadStatus.notFound) {
      final Map<String, dynamic> protectedLocal = _cipher == null
          ? localBackup
          : await _cipher.encryptPayload(localBackup);
      if (!_accountStillCurrent) return CloudSyncOutcome.accountChanged;
      if (!backup.isLocalGenerationCurrent(localSnapshot.localGeneration)) {
        return CloudSyncOutcome.conflict;
      }
      final CloudBackupWriteResult uploaded = await gateway
          .compareAndSwapBackup(protectedLocal, expectedRevision: 0);
      if (!_accountStillCurrent) return CloudSyncOutcome.accountChanged;
      if (!backup.isLocalGenerationCurrent(localSnapshot.localGeneration)) {
        return CloudSyncOutcome.conflict;
      }
      return _syncOutcomeForWrite(uploaded);
    }
    if (read.status != CloudBackupReadStatus.found) {
      return _syncFailureFor(read.status);
    }
    final Map<String, dynamic> downloaded = read.payload!;
    final int? expectedRevision = read.revision;
    if (expectedRevision == null || expectedRevision < 0) {
      return CloudSyncOutcome.malformed;
    }
    final Map<String, dynamic> cloudBackup;
    try {
      cloudBackup = _cipher == null
          ? downloaded
          : await _cipher.decryptPayload(downloaded);
      backup.validateFullBackup(cloudBackup);
    } on BackupRecoveryKeyRequiredException {
      return CloudSyncOutcome.recoveryKeyRequired;
    } on Object {
      return CloudSyncOutcome.malformed;
    }

    final Map<String, dynamic> merged = _mergeBackups(localBackup, cloudBackup);
    final Map<String, dynamic> protectedMerged = _cipher == null
        ? merged
        : await _cipher.encryptPayload(merged);
    if (!_accountStillCurrent) return CloudSyncOutcome.accountChanged;
    if (!backup.isLocalGenerationCurrent(localSnapshot.localGeneration)) {
      return CloudSyncOutcome.conflict;
    }
    final CloudBackupWriteResult uploaded = await gateway.compareAndSwapBackup(
      protectedMerged,
      expectedRevision: expectedRevision,
    );
    if (!_accountStillCurrent) return CloudSyncOutcome.accountChanged;
    final CloudSyncOutcome writeOutcome = _syncOutcomeForWrite(uploaded);
    if (writeOutcome != CloudSyncOutcome.synced) return writeOutcome;
    try {
      await backup.restoreFullBackup(
        merged,
        canContinue: () => _accountStillCurrent,
        expectedLocalGeneration: localSnapshot.localGeneration,
      );
      return CloudSyncOutcome.synced;
    } on BackupRestoreCancelledException {
      return CloudSyncOutcome.accountChanged;
    } on BackupConcurrentMutationException {
      return CloudSyncOutcome.conflict;
    }
  }

  Future<bool> syncTasksOnly() async {
    if (!syncEnabled || !_accountStillCurrent) return false;
    final Map<String, dynamic> tasks = await backup.backupTasks();
    final CloudBackupReadResult read = await gateway.downloadTasks();
    if (read.status != CloudBackupReadStatus.notFound ||
        !_accountStillCurrent) {
      return false;
    }
    final Map<String, dynamic> protectedTasks = _cipher == null
        ? tasks
        : await _cipher.encryptPayload(tasks);
    if (!_accountStillCurrent) return false;
    final bool uploaded = await gateway.uploadTasks(protectedTasks);
    return _accountStillCurrent && uploaded;
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
    try {
      await backup.restoreTasks(
        _cipher == null ? cloudTasks : await _cipher.decryptPayload(cloudTasks),
        canContinue: () => _accountStillCurrent,
      );
      return true;
    } on BackupRestoreCancelledException {
      return false;
    }
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

  CloudSyncOutcome _syncFailureFor(CloudBackupReadStatus status) {
    return switch (status) {
      CloudBackupReadStatus.found => CloudSyncOutcome.malformed,
      CloudBackupReadStatus.notFound => CloudSyncOutcome.uploadFailed,
      CloudBackupReadStatus.unavailable => CloudSyncOutcome.unavailable,
      CloudBackupReadStatus.malformed => CloudSyncOutcome.malformed,
      CloudBackupReadStatus.ownerMismatch => CloudSyncOutcome.ownerMismatch,
    };
  }

  CloudSyncOutcome _syncOutcomeForWrite(CloudBackupWriteResult result) {
    return switch (result.status) {
      CloudBackupWriteStatus.written => CloudSyncOutcome.synced,
      CloudBackupWriteStatus.conflict => CloudSyncOutcome.conflict,
      CloudBackupWriteStatus.unavailable => CloudSyncOutcome.uploadFailed,
      CloudBackupWriteStatus.ownerMismatch => CloudSyncOutcome.ownerMismatch,
      CloudBackupWriteStatus.malformed => CloudSyncOutcome.malformed,
    };
  }

  Future<LegacyFullBackupCleanupStatus?> _deleteLegacyFullBackup() async {
    final CloudBackupGateway activeGateway = gateway;
    if (activeGateway is! LegacyFullBackupCleanup) return null;
    return (activeGateway as LegacyFullBackupCleanup).deleteLegacyFullBackup();
  }

  Future<bool> _isVerifiedLegacyMigration(
    CloudBackupReadResult read, {
    required int? expectedRevision,
    required Map<String, dynamic> expectedPlaintext,
  }) async {
    final BackupCipher? cipher = _cipher;
    final Map<String, dynamic>? payload = read.payload;
    if (cipher == null ||
        expectedRevision == null ||
        read.status != CloudBackupReadStatus.found ||
        read.revision != expectedRevision ||
        payload == null ||
        cipher.isLegacyPlaintextBackup(payload)) {
      return false;
    }
    try {
      final Map<String, dynamic> decrypted = await cipher.decryptPayload(
        payload,
      );
      backup.validateFullBackup(decrypted);
      return _jsonValuesEqual(decrypted, expectedPlaintext);
    } on Object {
      return false;
    }
  }

  bool _jsonValuesEqual(Object? left, Object? right) {
    if (identical(left, right)) return true;
    if (left is Map && right is Map) {
      if (left.length != right.length) return false;
      for (final Object? key in left.keys) {
        if (!right.containsKey(key) ||
            !_jsonValuesEqual(left[key], right[key])) {
          return false;
        }
      }
      return true;
    }
    if (left is List && right is List) {
      if (left.length != right.length) return false;
      for (int index = 0; index < left.length; index += 1) {
        if (!_jsonValuesEqual(left[index], right[index])) return false;
      }
      return true;
    }
    return left == right;
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
