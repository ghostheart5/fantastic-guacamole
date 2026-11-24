import 'package:fantastic_guacamole/data/local/shared_prefs_storage.dart';

/// The cloud backup revision this device last wrote, restored or found equal
/// to its own data, and when that backup was made.
class CloudBackupStatus {
  const CloudBackupStatus({required this.revision, this.backedUpAt});

  final int revision;
  final DateTime? backedUpAt;
}

/// Per-account record of the last cloud backup this device knows about. The
/// storage passed in must already be scoped to the account, so the record is
/// removed with the rest of the account's local data.
class CloudBackupStatusStore {
  CloudBackupStatusStore(this._prefs);

  static const String storageKey = 'cloud_backup_status_v1';

  final SharedPrefsStorage _prefs;

  /// Returns null when nothing is stored or the stored value is unreadable.
  CloudBackupStatus? read() {
    final Map<String, dynamic> raw = _prefs.getJson(storageKey);
    final Object? revision = raw['revision'];
    if (revision is! int || revision < 1) return null;
    final Object? at = raw['backedUpAt'];
    return CloudBackupStatus(
      revision: revision,
      backedUpAt: at is String ? DateTime.tryParse(at) : null,
    );
  }

  Future<void> write(CloudBackupStatus status) {
    return _prefs.setJson(storageKey, <String, dynamic>{
      'revision': status.revision,
      if (status.backedUpAt != null)
        'backedUpAt': status.backedUpAt!.toUtc().toIso8601String(),
    });
  }
}
