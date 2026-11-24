import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:fantastic_guacamole/core/async/keyed_mutation_coordinator.dart';
import 'package:fantastic_guacamole/core/data/account_data_registry.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';

class BackupRecoveryKeyRequiredException implements Exception {
  const BackupRecoveryKeyRequiredException();

  @override
  String toString() =>
      'The recovery key for this encrypted cloud backup is required.';
}

/// Encrypts cloud backup payloads before they leave the device.
class BackupCipher {
  BackupCipher(
    this._secureStore, {
    String? accountId,
    KeyedMutationCoordinator? mutationCoordinator,
  }) : _mutations = mutationCoordinator ?? KeyedMutationCoordinator.shared,
       _keyName = _keyNameFor(accountId),
       _accountDigest = _accountDigestFor(accountId);

  static const String _legacyKeyName = 'cloud_backup_encryption_key_v1';
  static const String _legacyOwnerKey =
      'cloud_backup_encryption_key_v1_owner_digest';
  static const String _legacyClaimMutationKey =
      'chronospark-backup-legacy-key-claim';
  static const String _scopedKeyPrefix = 'cloud_backup_encryption_key_v2.';
  static const String _rollbackSuffix = '.rollback';
  static const String _format = 'chronospark_backup_aes256_gcm_v2';
  static const String _legacyFormat = 'chronospark_backup_aes256_v1';

  final SecureStore _secureStore;
  final KeyedMutationCoordinator _mutations;
  final String _keyName;
  final String? _accountDigest;

  String get _rollbackKeyName => '$_keyName$_rollbackSuffix';
  String get _keyMutationKey => 'chronospark-backup-key.$_keyName';

  /// Returns this device's existing recovery key for the account, or null when
  /// the device holds none. Never creates a key: a freshly generated key could
  /// not decrypt any backup made elsewhere.
  ///
  /// Callers must never log this value. UI should present it once, behind an
  /// explicit confirmation, and ask the user to store it in a password manager.
  Future<String?> loadExistingRecoveryKey() async {
    final String? stored = await _readStoredKey();
    if (stored == null || stored.trim().isEmpty) return null;
    return base64Encode(base64Decode(stored));
  }

  /// Returns this device's recovery key for the account, creating one only
  /// when the device holds none. Called only by the explicit "create a new
  /// key" choice when turning on Cloud Backup, so that the key is shown and
  /// saved before anything is encrypted with it. Never log the result.
  Future<String> createRecoveryKeyIfMissing() async {
    return base64Encode((await _loadOrCreateKey()).bytes);
  }

  /// Checks the format of a pasted recovery key and returns its canonical
  /// form. Throws [FormatException] when it is not a base64 256-bit key.
  static String parseRecoveryKey(String recoveryKey) {
    final List<int> decoded;
    try {
      decoded = base64Decode(recoveryKey.trim());
    } on FormatException {
      throw const FormatException('Backup recovery key is not valid base64.');
    }
    if (decoded.length != 32) {
      throw const FormatException(
        'Backup recovery key must contain a 256-bit key.',
      );
    }
    return base64Encode(decoded);
  }

  /// Whether [payload] is an encrypted backup that a recovery key can be
  /// tested against.
  bool isEncryptedBackup(Map<String, dynamic> payload) {
    final Object? format = payload['format'];
    return (format == _format || format == _legacyFormat) &&
        payload['iv'] is String &&
        payload['ciphertext'] is String;
  }

  /// Whether [payload] is a backup envelope in a format this build does not
  /// know, as a newer app version could write. It cannot be judged here.
  bool hasUnknownFormat(Map<String, dynamic> payload) {
    final Object? format = payload['format'];
    return format is String &&
        format.trim().isNotEmpty &&
        format != _format &&
        format != _legacyFormat;
  }

  /// Decrypts [payload] with [recoveryKey] without reading or changing the
  /// key stored on this device. Throws when the key does not open it.
  Future<Map<String, dynamic>> decryptPayloadWithRecoveryKey(
    Map<String, dynamic> payload,
    String recoveryKey,
  ) async {
    if (!isEncryptedBackup(payload)) {
      throw const FormatException('Cloud backup is not encrypted.');
    }
    return _decryptWith(
      encrypt.Key(base64Decode(parseRecoveryKey(recoveryKey))),
      payload,
    );
  }

  /// Installs a recovery key that has already been proven to decrypt the
  /// account's current cloud backup. Any rollback key is no longer needed.
  Future<void> installVerifiedRecoveryKey(String recoveryKey) async {
    final String key = parseRecoveryKey(recoveryKey);
    await _mutations.runExclusive(_keyMutationKey, () async {
      await _secureStore.writeString(_keyName, key);
      await _secureStore.delete(_rollbackKeyName);
    });
  }

  /// Installs a recovery key that could not be tested because there was no
  /// encrypted cloud backup. The key it replaces is kept under a rollback name
  /// and comes back automatically if a later backup only opens with it.
  Future<void> installUnverifiedRecoveryKey(String recoveryKey) async {
    final String key = parseRecoveryKey(recoveryKey);
    await _mutations.runExclusive(_keyMutationKey, () async {
      // Read the key being replaced under the same lock that creates a first
      // key, so a key made by a concurrent backup is never lost.
      final String? previous = await loadExistingRecoveryKey();
      final String? heldRollback = await _secureStore.readString(
        _rollbackKeyName,
      );
      // Keep the oldest unproven key: it is the one most likely to open an
      // existing backup.
      if (previous != null &&
          previous != key &&
          (heldRollback == null || heldRollback.trim().isEmpty)) {
        await _secureStore.writeString(_rollbackKeyName, previous);
      }
      await _secureStore.writeString(_keyName, key);
    });
  }

  Future<Map<String, dynamic>> encryptPayload(
    Map<String, dynamic> payload,
  ) async {
    final encrypt.Key key = await _loadOrCreateKey();
    final Uint8List ivBytes = Uint8List.fromList(
      List<int>.generate(12, (_) => Random.secure().nextInt(256)),
    );
    final encrypt.Encrypter encrypter = encrypt.Encrypter(
      encrypt.AES(key, mode: encrypt.AESMode.gcm),
    );
    final encrypt.Encrypted encrypted = encrypter.encrypt(
      jsonEncode(payload),
      iv: encrypt.IV(ivBytes),
    );
    return <String, dynamic>{
      'format': _format,
      'iv': base64Encode(ivBytes),
      'ciphertext': encrypted.base64,
    };
  }

  Future<Map<String, dynamic>> decryptPayload(
    Map<String, dynamic> payload,
  ) async {
    if (payload.isEmpty || isLegacyPlaintextBackup(payload)) {
      return payload;
    }
    if (!isEncryptedBackup(payload)) {
      throw const FormatException(
        'Cloud backup is neither encrypted nor a supported legacy backup.',
      );
    }
    final encrypt.Key key = await _loadKeyForDecryption();
    final String usedKey = base64Encode(key.bytes);
    final String? rollback = await _secureStore.readString(_rollbackKeyName);
    if (rollback == null || rollback.trim().isEmpty) {
      return _decryptWith(key, payload);
    }
    final Map<String, dynamic> decrypted;
    try {
      decrypted = _decryptWith(key, payload);
    } on Object catch (error, stackTrace) {
      // The installed key was never proven. If the key it replaced opens this
      // backup, put that key back; otherwise report the original failure.
      final Map<String, dynamic> restored;
      try {
        restored = _decryptWith(encrypt.Key(base64Decode(rollback)), payload);
      } on Object {
        Error.throwWithStackTrace(error, stackTrace);
      }
      await _whileKeyUnchanged(usedKey, () async {
        await _secureStore.writeString(_keyName, rollback);
        await _secureStore.delete(_rollbackKeyName);
      });
      return restored;
    }
    await _whileKeyUnchanged(usedKey, () async {
      await _secureStore.delete(_rollbackKeyName);
    });
    return decrypted;
  }

  Map<String, dynamic> _decryptWith(
    encrypt.Key key,
    Map<String, dynamic> payload,
  ) {
    final bool legacy = payload['format'] == _legacyFormat;
    final encrypt.Encrypter encrypter = encrypt.Encrypter(
      encrypt.AES(
        key,
        mode: legacy ? encrypt.AESMode.cbc : encrypt.AESMode.gcm,
      ),
    );
    final String json = encrypter.decrypt64(
      payload['ciphertext'] as String,
      iv: encrypt.IV.fromBase64(payload['iv'] as String),
    );
    final Object? decoded = jsonDecode(json);
    if (decoded is! Map) {
      throw const FormatException('Encrypted backup payload is not an object.');
    }
    return decoded.map(
      (dynamic key, dynamic value) => MapEntry(key.toString(), value),
    );
  }

  /// Legacy clients uploaded full backups as plaintext. Accept only the
  /// bounded full-backup shape so arbitrary storage content cannot be treated
  /// as a restoreable backup. Callers must replace accepted payloads with an
  /// encrypted version before applying them locally.
  bool isLegacyPlaintextBackup(Map<String, dynamic> payload) {
    if (payload['format'] != null || payload['version'] is! String) {
      return false;
    }
    final Object? tasks = payload['tasks'];
    return tasks is List && tasks.every((Object? task) => task is Map);
  }

  /// Runs [change] under the key lock only if the main key is still [usedKey],
  /// so a key installed meanwhile is never overwritten or stripped of its
  /// rollback by a decrypt that started earlier.
  Future<void> _whileKeyUnchanged(
    String usedKey,
    Future<void> Function() change,
  ) {
    return _mutations.runExclusive(_keyMutationKey, () async {
      final String? current = await _secureStore.readString(_keyName);
      if (current == null || current.trim().isEmpty) return;
      if (base64Encode(base64Decode(current)) != usedKey) return;
      await change();
    });
  }

  Future<encrypt.Key> _loadOrCreateKey() async {
    final String? stored = await _readStoredKey();
    if (stored != null && stored.trim().isNotEmpty) {
      return encrypt.Key(base64Decode(stored));
    }
    // Create a first key under the same lock as key imports, re-checking in
    // case an import or another backup installed one meanwhile.
    return _mutations.runExclusive(_keyMutationKey, () async {
      final String? installed = await _readStoredKey();
      if (installed != null && installed.trim().isNotEmpty) {
        return encrypt.Key(base64Decode(installed));
      }
      final Uint8List bytes = Uint8List.fromList(
        List<int>.generate(32, (_) => Random.secure().nextInt(256)),
      );
      await _secureStore.writeString(_keyName, base64Encode(bytes));
      return encrypt.Key(bytes);
    });
  }

  Future<encrypt.Key> _loadKeyForDecryption() async {
    final String? stored = await _readStoredKey();
    if (stored == null || stored.trim().isEmpty) {
      throw const BackupRecoveryKeyRequiredException();
    }
    return encrypt.Key(base64Decode(stored));
  }

  Future<String?> _readStoredKey() async {
    final String? scoped = await _secureStore.readString(_keyName);
    if (scoped != null && scoped.trim().isNotEmpty) return scoped;
    if (_keyName == _legacyKeyName) return scoped;

    final String? accountDigest = _accountDigest;
    if (accountDigest == null) return null;
    return _mutations.runExclusive(_legacyClaimMutationKey, () async {
      final String? existing = await _secureStore.readString(_keyName);
      if (existing != null && existing.trim().isNotEmpty) return existing;
      final String? legacy = await _secureStore.readString(_legacyKeyName);
      if (legacy == null || legacy.trim().isEmpty) return null;
      final String? legacyOwner = await _secureStore.readString(
        _legacyOwnerKey,
      );
      if (legacyOwner != null && legacyOwner != accountDigest) return null;
      if (legacyOwner == null) {
        await _secureStore.writeString(_legacyOwnerKey, accountDigest);
      }
      await _secureStore.writeString(_keyName, legacy);
      return legacy;
    });
  }

  static String _keyNameFor(String? accountId) {
    final String normalized = accountId?.trim() ?? '';
    if (normalized.isEmpty) return _legacyKeyName;
    return '$_scopedKeyPrefix${AccountDataRegistry.accountDigest(normalized)}';
  }

  static String? _accountDigestFor(String? accountId) {
    final String normalized = accountId?.trim() ?? '';
    return normalized.isEmpty
        ? null
        : AccountDataRegistry.accountDigest(normalized);
  }
}
