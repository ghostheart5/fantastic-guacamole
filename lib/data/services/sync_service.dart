import 'dart:convert';

import 'package:fantastic_guacamole/config/launch_containment.dart';
import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/data/local/shared_prefs_storage.dart';
import 'package:fantastic_guacamole/data/services/backup_service.dart';
import 'package:fantastic_guacamole/data/services/backup_cipher.dart';
import 'package:fantastic_guacamole/data/services/cloud_backup_status_store.dart';
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

  /// A full cloud backup exists that this device has no record of making,
  /// restoring or matching, and local data differs from it. Nothing was
  /// uploaded: the device cannot tell its own older backup from a newer one
  /// made elsewhere. One confirmed full backup links them again.
  fullBackupNotLinked,
}

/// Whether a recovery key opens the account's current cloud backup.
enum CloudBackupKeyCheck {
  /// The key decrypts the current cloud backup and it is a valid backup.
  matches,

  /// There is an encrypted cloud backup and the key does not open it.
  doesNotMatch,

  /// The key opens the encrypted cloud backup, but what is inside is not a
  /// valid backup: it is damaged and cannot be restored.
  unreadable,

  /// The backup was made by a newer app version (an unknown backup version or
  /// encryption format). It is not damaged; this build cannot judge it.
  newerVersion,

  /// There is no encrypted cloud backup to test the key against.
  noEncryptedCloudBackup,

  /// No key was given and this device holds none for the account.
  noKeyOnDevice,

  /// The cloud backup could not be read, so nothing was proven.
  unavailable,

  /// The cloud returned a backup row it could not parse. Not a connection
  /// problem, and not something that can be discarded safely.
  cloudBackupUnreadable,
  ownerMismatch,
  malformed,
  accountChanged,
}

/// Result of installing a pasted recovery key.
enum RecoveryKeyImportOutcome {
  /// The key opened the current cloud backup and is now this device's key.
  installed,

  /// There was no encrypted cloud backup to test against. The key is now this
  /// device's key and any previous key is kept until a backup opens.
  installedUnverified,

  /// The key does not open the current cloud backup. Nothing was changed.
  doesNotMatch,

  /// The pasted text is not a recovery key. Nothing was changed.
  invalidFormat,

  /// The key opens the cloud backup, but the backup is damaged. Nothing was
  /// changed.
  backupUnreadable,

  /// The backup was made by a newer app version. Nothing was changed.
  newerVersion,

  /// The cloud backup could not be checked. Nothing was changed.
  cloudUnavailable,

  /// The cloud returned a backup row it could not parse. Nothing was changed.
  cloudBackupUnreadable,

  /// Cloud Backup is turned off, so there is nothing to check the key
  /// against. Nothing was changed.
  cloudBackupOff,

  /// The account signed in to the cloud is not the account this device's
  /// data belongs to. Nothing was changed.
  ownerMismatch,

  /// The signed-in account changed. Nothing was changed.
  accountChanged,
}

/// Result of deleting the account's cloud backup at a given revision.
enum CloudBackupDeleteStatus {
  /// The backup at that revision was deleted.
  deleted,

  /// Nothing was deleted: the backup changed, or the server refused.
  notDeleted,
  unavailable,
  ownerMismatch,
}

/// Whether the account has an encrypted cloud backup, found without any key.
enum CloudBackupPresence {
  /// An encrypted backup (or one in a newer format) exists. Only the key it
  /// was made with can open it.
  encryptedBackup,

  /// No backup, or only one that needs no key (an older plaintext backup, or
  /// content no key could open).
  noEncryptedBackup,

  /// The cloud could not be reached, so nothing is known.
  unknown,

  /// The cloud returned a backup row it could not parse.
  cloudBackupUnreadable,
}

/// A gateway that can delete the account's own cloud backup.
abstract interface class CloudBackupDiscard {
  /// Deletes this account's cloud backup only while it is still at
  /// [expectedRevision]. Revision 0 is the older storage-object backup.
  Future<CloudBackupDeleteStatus> deleteBackup({required int expectedRevision});
}

/// Result of discarding a cloud backup this device cannot read.
enum CloudBackupDiscardOutcome {
  /// The unreadable cloud backup was deleted. The next backup starts over
  /// with this device's key.
  discarded,

  /// This device can read the cloud backup, so it was not deleted.
  readable,

  /// The backup was made by a newer app version, so this build cannot tell
  /// whether it is readable. Nothing was deleted.
  newerVersion,

  /// There is no cloud backup to discard.
  nothingToDiscard,

  /// This device holds no recovery key, so starting over would leave the
  /// next backup without a saved key. Nothing was deleted.
  noKeyOnDevice,

  /// The cloud backup changed after it was checked. Nothing was deleted.
  changed,

  /// The server did not allow the delete. Nothing was deleted.
  refused,
  unavailable,

  /// The cloud returned a backup row it could not parse. Nothing was deleted.
  cloudBackupUnreadable,
  ownerMismatch,
  accountChanged,
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

class LocalTestCloudBackupGateway
    implements CloudBackupGateway, CloudBackupDiscard {
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
  Future<CloudBackupDeleteStatus> deleteBackup({
    required int expectedRevision,
  }) async {
    if (!_preferences.contains(_backupKey) ||
        _preferences.getIntOrDefault(_backupRevisionKey, 1) !=
            expectedRevision) {
      return CloudBackupDeleteStatus.notDeleted;
    }
    await _preferences.remove(_backupKey);
    await _preferences.remove(_backupRevisionKey);
    return CloudBackupDeleteStatus.deleted;
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
      if (_isMissingObject(error)) {
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

  static bool _isMissingObject(sb.StorageException error) {
    if (error.statusCode == '404') return true;
    // Binary downloads in storage_client preserve the raw error response in
    // message. Legacy Storage reports a missing object as HTTP 400 with a
    // structured 404 body. Do not classify other bad requests or outages as
    // empty backups: sync would otherwise attempt to initialize cloud state.
    if (error.statusCode != '400' || error.message.length > 4096) return false;
    try {
      final Object? body = jsonDecode(error.message);
      return body is Map<String, dynamic> &&
          body['statusCode']?.toString() == '404' &&
          body['error'] == 'not_found';
    } on FormatException {
      return false;
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
    implements CloudBackupGateway, LegacyFullBackupCleanup, CloudBackupDiscard {
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

  /// Deletes the caller's own snapshot row only at [expectedRevision]. The
  /// server allows this only for the row's owner and refuses it while an
  /// account deletion is in progress (migration
  /// 20261123090000_cloud_backup_discard_own.sql). A refusal or a changed
  /// revision deletes nothing and is reported as [CloudBackupDeleteStatus.notDeleted].
  @override
  Future<CloudBackupDeleteStatus> deleteBackup({
    required int expectedRevision,
  }) async {
    if (!_hasExpectedUser) return CloudBackupDeleteStatus.ownerMismatch;
    if (expectedRevision < 0) return CloudBackupDeleteStatus.notDeleted;
    if (expectedRevision == 0) {
      return switch (await _legacy.deleteLegacyFullBackup()) {
        LegacyFullBackupCleanupStatus.removedOrAbsent =>
          CloudBackupDeleteStatus.deleted,
        LegacyFullBackupCleanupStatus.unavailable =>
          CloudBackupDeleteStatus.unavailable,
        LegacyFullBackupCleanupStatus.ownerMismatch =>
          CloudBackupDeleteStatus.ownerMismatch,
      };
    }
    try {
      final List<dynamic> rows = await _client
          .from(_table)
          .delete()
          .eq('user_id', expectedUserId)
          .eq('revision', expectedRevision)
          .select('revision');
      return rows.length == 1
          ? CloudBackupDeleteStatus.deleted
          : CloudBackupDeleteStatus.notDeleted;
    } on sb.PostgrestException {
      // Includes "permission denied" before the delete policy is deployed.
      return CloudBackupDeleteStatus.notDeleted;
    } on Object {
      Logger.errorCategory(
        'Sync Errors',
        'Supabase versioned cloud backup delete failed',
      );
      return CloudBackupDeleteStatus.unavailable;
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
    this.statusStore,
    this.expectedAccountId,
    this.currentAccountId,
    this.syncEnabled = LaunchContainment.publicCloudSyncEnabled,
    this.restoreEnabled = LaunchContainment.publicCloudRestoreEnabled,
  }) : _cipher = secureStore == null
           ? null
           : BackupCipher(secureStore, accountId: expectedAccountId);

  final BackupService backup;
  final CloudBackupGateway gateway;
  final BackupCipher? _cipher;

  /// Records the cloud revision this device last wrote, restored or matched.
  /// Without it a full (v6) cloud backup is never replaced automatically.
  final CloudBackupStatusStore? statusStore;
  final String? expectedAccountId;
  final String? Function()? currentAccountId;
  final bool syncEnabled;
  final bool restoreEnabled;

  Future<bool> syncToCloud() async {
    return syncDelta();
  }

  /// Explicit replacement of the account's encrypted device snapshot, after
  /// the UI has confirmed its expanded scope and the overwrite consequence.
  Future<CloudSyncOutcome> backupPlanningToCloud({
    bool Function()? shouldContinue,
  }) async {
    bool permitted() => syncEnabled && (shouldContinue?.call() ?? true);
    if (!permitted()) return CloudSyncOutcome.disabled;
    if (!_accountStillCurrent) return CloudSyncOutcome.accountChanged;
    final cipher = _cipher;
    if (cipher == null) return CloudSyncOutcome.unavailable;
    final snapshot = await backup.createPlanningCloudBackup();
    if (!_accountStillCurrent) return CloudSyncOutcome.accountChanged;
    if (!permitted()) return CloudSyncOutcome.disabled;
    final read = await gateway.downloadBackup();
    if (!_accountStillCurrent) return CloudSyncOutcome.accountChanged;
    if (!permitted()) return CloudSyncOutcome.disabled;
    if (read.status != CloudBackupReadStatus.notFound &&
        read.status != CloudBackupReadStatus.found) {
      return _syncFailureFor(read.status);
    }
    final revision = read.status == CloudBackupReadStatus.notFound
        ? 0
        : read.revision;
    if (revision == null || revision < 0) return CloudSyncOutcome.malformed;
    if (read.status == CloudBackupReadStatus.found) {
      // Do not replace an unreadable or foreign-account backup, even after the
      // user confirmed replacing the snapshot for their current account.
      try {
        final previous = await cipher.decryptPayload(read.payload!);
        backup.validateFullBackup(previous);
      } on BackupRecoveryKeyRequiredException {
        return CloudSyncOutcome.recoveryKeyRequired;
      } on Object {
        return CloudSyncOutcome.malformed;
      }
    }
    final encrypted = await cipher.encryptPayload(snapshot.payload);
    if (!_accountStillCurrent) return CloudSyncOutcome.accountChanged;
    if (!permitted()) return CloudSyncOutcome.disabled;
    if (!backup.isLocalGenerationCurrent(snapshot.localGeneration)) {
      return CloudSyncOutcome.conflict;
    }
    final written = await gateway.compareAndSwapBackup(
      encrypted,
      expectedRevision: revision,
    );
    if (!_accountStillCurrent) return CloudSyncOutcome.accountChanged;
    if (!permitted()) return CloudSyncOutcome.disabled;
    final outcome = _syncOutcomeForWrite(written);
    if (outcome != CloudSyncOutcome.synced) return outcome;
    // The server accepted this snapshot at this revision, so automatic backup
    // may keep it current even if the readback below fails.
    await _recordBackup(written.revision, DateTime.now());
    final verified = await gateway.downloadBackup();
    if (!_accountStillCurrent) return CloudSyncOutcome.accountChanged;
    if (!permitted()) return CloudSyncOutcome.disabled;
    if (!await _isVerifiedLegacyMigration(
      verified,
      expectedRevision: written.revision,
      expectedPlaintext: snapshot.payload,
    )) {
      return CloudSyncOutcome.uploadFailed;
    }
    if (!permitted()) return CloudSyncOutcome.disabled;
    return backup.isLocalGenerationCurrent(snapshot.localGeneration)
        ? CloudSyncOutcome.synced
        : CloudSyncOutcome.conflict;
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
    int? restoredRevision = read.revision;
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
      restoredRevision = migration.revision;
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
      // Local data now matches this cloud revision.
      await _recordBackup(restoredRevision, _snapshotTime(restored));
      return legacyCleanupPending
          ? CloudRestoreOutcome.restoredLegacyCleanupPending
          : CloudRestoreOutcome.restored;
    } on BackupRestoreCancelledException {
      return CloudRestoreOutcome.accountChanged;
    } on BackupConcurrentMutationException {
      return CloudRestoreOutcome.conflict;
    }
  }

  /// Downloads the current cloud backup and tests whether [recoveryKey] opens
  /// it. Without [recoveryKey] it tests the key already on this device. Never
  /// writes the key store, so it is safe to call for status displays.
  Future<CloudBackupKeyCheck> checkCloudBackupKey({String? recoveryKey}) async {
    final BackupCipher? cipher = _cipher;
    if (cipher == null) return CloudBackupKeyCheck.unavailable;
    if (!_accountStillCurrent) return CloudBackupKeyCheck.accountChanged;
    final String? key = recoveryKey ?? await cipher.loadExistingRecoveryKey();
    if (key == null) return CloudBackupKeyCheck.noKeyOnDevice;
    final CloudBackupReadResult read = await gateway.downloadBackup();
    if (!_accountStillCurrent) return CloudBackupKeyCheck.accountChanged;
    switch (read.status) {
      case CloudBackupReadStatus.found:
        break;
      case CloudBackupReadStatus.notFound:
        return CloudBackupKeyCheck.noEncryptedCloudBackup;
      case CloudBackupReadStatus.unavailable:
        return CloudBackupKeyCheck.unavailable;
      case CloudBackupReadStatus.ownerMismatch:
        return CloudBackupKeyCheck.ownerMismatch;
      case CloudBackupReadStatus.malformed:
        // The row itself could not be parsed: nothing about the key or the
        // backup is known, and it could not be discarded safely either.
        return CloudBackupKeyCheck.cloudBackupUnreadable;
    }
    final Map<String, dynamic> payload = read.payload!;
    if (cipher.isLegacyPlaintextBackup(payload)) {
      return backup.hasUnsupportedVersion(payload)
          ? CloudBackupKeyCheck.newerVersion
          : CloudBackupKeyCheck.noEncryptedCloudBackup;
    }
    if (cipher.hasUnknownFormat(payload)) {
      return CloudBackupKeyCheck.newerVersion;
    }
    if (!cipher.isEncryptedBackup(payload)) {
      return CloudBackupKeyCheck.malformed;
    }
    final Map<String, dynamic> decrypted;
    try {
      decrypted = await cipher.decryptPayloadWithRecoveryKey(payload, key);
    } on Object {
      return CloudBackupKeyCheck.doesNotMatch;
    }
    // The key is right. An unknown version inside was written by a newer
    // app; any other validation failure means the backup is damaged.
    if (backup.hasUnsupportedVersion(decrypted)) {
      return CloudBackupKeyCheck.newerVersion;
    }
    try {
      backup.validateFullBackup(decrypted);
      return CloudBackupKeyCheck.matches;
    } on Object {
      return CloudBackupKeyCheck.unreadable;
    }
  }

  /// Installs a pasted recovery key only when it is safe: after it opens the
  /// current cloud backup, or, when there is no encrypted backup to test,
  /// while keeping the previous key recoverable. A key that does not open the
  /// backup, or a backup that cannot be checked, leaves the stored key as is.
  Future<RecoveryKeyImportOutcome> importRecoveryKey(String recoveryKey) async {
    final BackupCipher? cipher = _cipher;
    if (cipher == null) return RecoveryKeyImportOutcome.cloudUnavailable;
    final String key;
    try {
      key = BackupCipher.parseRecoveryKey(recoveryKey);
    } on FormatException {
      return RecoveryKeyImportOutcome.invalidFormat;
    }
    final CloudBackupKeyCheck check = await checkCloudBackupKey(
      recoveryKey: key,
    );
    if (!_accountStillCurrent) return RecoveryKeyImportOutcome.accountChanged;
    switch (check) {
      case CloudBackupKeyCheck.matches:
        await cipher.installVerifiedRecoveryKey(key);
        return RecoveryKeyImportOutcome.installed;
      case CloudBackupKeyCheck.noEncryptedCloudBackup:
        await cipher.installUnverifiedRecoveryKey(key);
        return RecoveryKeyImportOutcome.installedUnverified;
      case CloudBackupKeyCheck.doesNotMatch:
        return RecoveryKeyImportOutcome.doesNotMatch;
      case CloudBackupKeyCheck.unreadable:
        return RecoveryKeyImportOutcome.backupUnreadable;
      case CloudBackupKeyCheck.newerVersion:
        return RecoveryKeyImportOutcome.newerVersion;
      case CloudBackupKeyCheck.ownerMismatch:
        return RecoveryKeyImportOutcome.ownerMismatch;
      case CloudBackupKeyCheck.accountChanged:
        return RecoveryKeyImportOutcome.accountChanged;
      case CloudBackupKeyCheck.cloudBackupUnreadable:
        return RecoveryKeyImportOutcome.cloudBackupUnreadable;
      case CloudBackupKeyCheck.unavailable:
      case CloudBackupKeyCheck.malformed:
      case CloudBackupKeyCheck.noKeyOnDevice:
        return RecoveryKeyImportOutcome.cloudUnavailable;
    }
  }

  /// Read-only: whether the account already has an encrypted cloud backup,
  /// without needing or touching any key. Used before creating a new key, which
  /// could never open such a backup.
  Future<CloudBackupPresence> findCloudBackup() async {
    final BackupCipher? cipher = _cipher;
    if (cipher == null || !_accountStillCurrent) {
      return CloudBackupPresence.unknown;
    }
    final CloudBackupReadResult read = await gateway.downloadBackup();
    if (!_accountStillCurrent) return CloudBackupPresence.unknown;
    switch (read.status) {
      case CloudBackupReadStatus.notFound:
        return CloudBackupPresence.noEncryptedBackup;
      case CloudBackupReadStatus.malformed:
        return CloudBackupPresence.cloudBackupUnreadable;
      case CloudBackupReadStatus.unavailable:
      case CloudBackupReadStatus.ownerMismatch:
        return CloudBackupPresence.unknown;
      case CloudBackupReadStatus.found:
        break;
    }
    final Map<String, dynamic> payload = read.payload!;
    return cipher.isEncryptedBackup(payload) || cipher.hasUnknownFormat(payload)
        ? CloudBackupPresence.encryptedBackup
        : CloudBackupPresence.noEncryptedBackup;
  }

  /// Deletes the account's cloud backup so backup can start over, but only
  /// when this device holds a key and cannot read the backup with it (or with
  /// a key kept for rollback). The delete is tied to the revision that was
  /// checked, so a backup replaced meanwhile is never deleted. Afterwards the
  /// record of the last backup is cleared so automatic backup starts cleanly.
  Future<CloudBackupDiscardOutcome> discardUnreadableCloudBackup() async {
    final BackupCipher? cipher = _cipher;
    final CloudBackupGateway activeGateway = gateway;
    if (cipher == null || activeGateway is! CloudBackupDiscard) {
      return CloudBackupDiscardOutcome.unavailable;
    }
    if (!_accountStillCurrent) return CloudBackupDiscardOutcome.accountChanged;
    if (await cipher.loadExistingRecoveryKey() == null) {
      return CloudBackupDiscardOutcome.noKeyOnDevice;
    }
    final CloudBackupReadResult read = await activeGateway.downloadBackup();
    if (!_accountStillCurrent) return CloudBackupDiscardOutcome.accountChanged;
    final CloudBackupDiscardOutcome? readRefusal = _discardRefusalForRead(read);
    if (readRefusal != null) return readRefusal;
    final int revision = read.revision!;
    final Map<String, dynamic> payload = read.payload!;
    // A newer app version's backup is never judged unreadable here.
    if (cipher.hasUnknownFormat(payload)) {
      return CloudBackupDiscardOutcome.newerVersion;
    }
    final CloudBackupDiscardOutcome? openRefusal = await _refusalIfOpens(
      cipher,
      payload,
      damagedMayBeDiscarded: true,
    );
    if (openRefusal != null) return openRefusal;
    // Otherwise unreadable by this device: the only case that may be
    // discarded.
    return _deleteAtCheckedRevision(activeGateway, revision);
  }

  /// For a user who says the saved key is lost: deletes the account's
  /// encrypted cloud backup even though this device holds no key, so backup
  /// can start over with a new key. Kept separate from
  /// [discardUnreadableCloudBackup], whose refusals are unchanged. Only a
  /// recognised encrypted backup qualifies: never one in a newer app's format,
  /// an older plaintext backup, unrecognised content, or when the cloud
  /// cannot be read. If a key on this device opens the backup, the key is not
  /// lost and nothing is deleted. Never creates a key itself.
  Future<CloudBackupDiscardOutcome> discardCloudBackupForLostKey() async {
    final BackupCipher? cipher = _cipher;
    final CloudBackupGateway activeGateway = gateway;
    if (cipher == null || activeGateway is! CloudBackupDiscard) {
      return CloudBackupDiscardOutcome.unavailable;
    }
    if (!_accountStillCurrent) return CloudBackupDiscardOutcome.accountChanged;
    final CloudBackupReadResult read = await activeGateway.downloadBackup();
    if (!_accountStillCurrent) return CloudBackupDiscardOutcome.accountChanged;
    final CloudBackupDiscardOutcome? readRefusal = _discardRefusalForRead(read);
    if (readRefusal != null) return readRefusal;
    final int revision = read.revision!;
    final Map<String, dynamic> payload = read.payload!;
    if (cipher.hasUnknownFormat(payload)) {
      return CloudBackupDiscardOutcome.newerVersion;
    }
    if (cipher.isLegacyPlaintextBackup(payload)) {
      return CloudBackupDiscardOutcome.readable;
    }
    if (!cipher.isEncryptedBackup(payload)) {
      // Not what the user was shown (an encrypted backup): check again.
      return CloudBackupDiscardOutcome.changed;
    }
    if (await cipher.loadExistingRecoveryKey() != null) {
      final CloudBackupDiscardOutcome? openRefusal = await _refusalIfOpens(
        cipher,
        payload,
        damagedMayBeDiscarded: false,
      );
      if (openRefusal != null) return openRefusal;
    }
    if (!_accountStillCurrent) return CloudBackupDiscardOutcome.accountChanged;
    return _deleteAtCheckedRevision(activeGateway, revision);
  }

  /// Null when [read] found a backup with a trustworthy revision.
  CloudBackupDiscardOutcome? _discardRefusalForRead(
    CloudBackupReadResult read,
  ) {
    switch (read.status) {
      case CloudBackupReadStatus.found:
        final int? revision = read.revision;
        return revision == null || revision < 0
            ? CloudBackupDiscardOutcome.cloudBackupUnreadable
            : null;
      case CloudBackupReadStatus.notFound:
        return CloudBackupDiscardOutcome.nothingToDiscard;
      case CloudBackupReadStatus.ownerMismatch:
        return CloudBackupDiscardOutcome.ownerMismatch;
      case CloudBackupReadStatus.unavailable:
        return CloudBackupDiscardOutcome.unavailable;
      case CloudBackupReadStatus.malformed:
        // Without a trustworthy revision the delete could not be tied to
        // what was checked.
        return CloudBackupDiscardOutcome.cloudBackupUnreadable;
    }
  }

  /// A refusal when a key on this device (or kept for rollback) opens
  /// [payload]: readable, or made by a newer version. A backup that opens but
  /// fails validation is refused too unless [damagedMayBeDiscarded].
  Future<CloudBackupDiscardOutcome?> _refusalIfOpens(
    BackupCipher cipher,
    Map<String, dynamic> payload, {
    required bool damagedMayBeDiscarded,
  }) async {
    final Map<String, dynamic> opened;
    try {
      // decryptPayload also tries a key kept for rollback.
      opened = await cipher.decryptPayload(payload);
    } on Object {
      return null;
    }
    if (backup.hasUnsupportedVersion(opened)) {
      return CloudBackupDiscardOutcome.newerVersion;
    }
    try {
      backup.validateFullBackup(opened);
      return CloudBackupDiscardOutcome.readable;
    } on Object {
      // Opens but is damaged.
      return damagedMayBeDiscarded ? null : CloudBackupDiscardOutcome.readable;
    }
  }

  /// Deletes at [revision] and decides success by reading again.
  Future<CloudBackupDiscardOutcome> _deleteAtCheckedRevision(
    CloudBackupGateway activeGateway,
    int revision,
  ) async {
    if (!_accountStillCurrent) return CloudBackupDiscardOutcome.accountChanged;
    final CloudBackupDeleteStatus deleted =
        await (activeGateway as CloudBackupDiscard).deleteBackup(
          expectedRevision: revision,
        );
    if (!_accountStillCurrent) return CloudBackupDiscardOutcome.accountChanged;
    switch (deleted) {
      case CloudBackupDeleteStatus.deleted:
      case CloudBackupDeleteStatus.notDeleted:
        break;
      case CloudBackupDeleteStatus.unavailable:
        return CloudBackupDiscardOutcome.unavailable;
      case CloudBackupDeleteStatus.ownerMismatch:
        return CloudBackupDiscardOutcome.ownerMismatch;
    }
    // Read again rather than trust the delete: a server can report success
    // for a delete its policy filtered out.
    final CloudBackupReadResult after = await activeGateway.downloadBackup();
    if (!_accountStillCurrent) return CloudBackupDiscardOutcome.accountChanged;
    final bool gone =
        after.status == CloudBackupReadStatus.notFound ||
        (deleted == CloudBackupDeleteStatus.deleted &&
            after.status == CloudBackupReadStatus.found &&
            after.revision != revision);
    if (gone) {
      await statusStore?.clear();
      return CloudBackupDiscardOutcome.discarded;
    }
    return switch (after.status) {
      CloudBackupReadStatus.found =>
        after.revision == revision
            ? CloudBackupDiscardOutcome.refused
            : CloudBackupDiscardOutcome.changed,
      CloudBackupReadStatus.ownerMismatch =>
        CloudBackupDiscardOutcome.ownerMismatch,
      CloudBackupReadStatus.malformed =>
        CloudBackupDiscardOutcome.cloudBackupUnreadable,
      _ => CloudBackupDiscardOutcome.unavailable,
    };
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
      if (uploaded.status == CloudBackupWriteStatus.written) {
        await _recordBackup(uploaded.revision, DateTime.now());
      }
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

    // Legacy replay must never replace a full planning snapshot with a partial
    // task merge. A full snapshot is only ever replaced by a full snapshot.
    if (cloudBackup['version'] == '6.0.0') {
      return _keepFullSnapshotCurrent(cloudBackup, expectedRevision);
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
    await _recordBackup(uploaded.revision, DateTime.now());
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

  /// Keeps a full (v6) cloud snapshot current. [cloudBackup] has already been
  /// decrypted with this device's key and validated. Uploads a new full
  /// snapshot only when local data differs from it and the cloud copy is
  /// still the revision this device last wrote, restored or matched. A cloud
  /// copy changed by another device is never replaced automatically.
  Future<CloudSyncOutcome> _keepFullSnapshotCurrent(
    Map<String, dynamic> cloudBackup,
    int revision,
  ) async {
    final BackupCipher? cipher = _cipher;
    final CloudBackupStatusStore? status = statusStore;
    if (cipher == null || status == null) return CloudSyncOutcome.conflict;
    final VersionedBackupSnapshot snapshot = await backup
        .createPlanningCloudBackup();
    if (!_accountStillCurrent) return CloudSyncOutcome.accountChanged;
    final CloudBackupStatus? known = status.read();
    if (_sameSnapshotContent(snapshot.payload, cloudBackup)) {
      if (known?.revision != revision) {
        await _recordBackup(revision, _snapshotTime(cloudBackup));
      }
      return CloudSyncOutcome.synced;
    }
    if (known == null) return CloudSyncOutcome.fullBackupNotLinked;
    // Another device replaced the backup since this device last saw it.
    if (known.revision != revision) return CloudSyncOutcome.conflict;
    final Map<String, dynamic> encrypted = await cipher.encryptPayload(
      snapshot.payload,
    );
    if (!_accountStillCurrent) return CloudSyncOutcome.accountChanged;
    if (!syncEnabled) return CloudSyncOutcome.disabled;
    if (!backup.isLocalGenerationCurrent(snapshot.localGeneration)) {
      return CloudSyncOutcome.conflict;
    }
    final CloudBackupWriteResult written = await gateway.compareAndSwapBackup(
      encrypted,
      expectedRevision: revision,
    );
    if (!_accountStillCurrent) return CloudSyncOutcome.accountChanged;
    final CloudSyncOutcome outcome = _syncOutcomeForWrite(written);
    if (outcome != CloudSyncOutcome.synced) return outcome;
    await _recordBackup(written.revision, DateTime.now());
    return CloudSyncOutcome.synced;
  }

  /// Whether two full snapshots hold the same data, ignoring when each was
  /// made.
  bool _sameSnapshotContent(
    Map<String, dynamic> local,
    Map<String, dynamic> cloud,
  ) {
    final Object? normalizedLocal = jsonDecode(jsonEncode(local));
    if (normalizedLocal is! Map<String, dynamic>) return false;
    return _jsonValuesEqual(
      <String, dynamic>{...normalizedLocal}..remove('timestamp'),
      <String, dynamic>{...cloud}..remove('timestamp'),
    );
  }

  DateTime? _snapshotTime(Map<String, dynamic> snapshot) {
    final Object? timestamp = snapshot['timestamp'];
    return timestamp is String ? DateTime.tryParse(timestamp) : null;
  }

  Future<void> _recordBackup(int? revision, DateTime? backedUpAt) async {
    final CloudBackupStatusStore? status = statusStore;
    if (status == null || revision == null || revision < 1) return;
    if (!_accountStillCurrent) return;
    await status.write(
      CloudBackupStatus(revision: revision, backedUpAt: backedUpAt),
    );
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
    final List<dynamic> mergedTasks = merged['tasks'] as List<dynamic>;
    final Map<String, dynamic> mergedSettings =
        merged['settings'] as Map<String, dynamic>? ?? <String, dynamic>{};
    merged['recordCounts'] = <String, int>{
      'tasks': mergedTasks.length,
      'profile': merged['profile'] == null ? 0 : 1,
      'settings': mergedSettings.length,
    };
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
