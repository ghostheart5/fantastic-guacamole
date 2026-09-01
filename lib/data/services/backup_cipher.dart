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
  static const String _format = 'chronospark_backup_aes256_gcm_v2';
  static const String _legacyFormat = 'chronospark_backup_aes256_v1';

  final SecureStore _secureStore;
  final KeyedMutationCoordinator _mutations;
  final String _keyName;
  final String? _accountDigest;

  /// Returns a user-held recovery key that can be stored outside this device
  /// and imported on a replacement device before restoring encrypted backups.
  ///
  /// Callers must never log this value. UI should present it once, behind an
  /// explicit confirmation, and ask the user to store it in a password manager.
  Future<String> exportRecoveryKey() async {
    final encrypt.Key key = await _loadOrCreateKey();
    return base64Encode(key.bytes);
  }

  /// Installs a user-held recovery key on this device. This enables decrypting
  /// cloud backups created elsewhere without generating a new incompatible key.
  Future<void> importRecoveryKey(String recoveryKey) async {
    final String normalized = recoveryKey.trim();
    final List<int> decoded;
    try {
      decoded = base64Decode(normalized);
    } on FormatException {
      throw const FormatException('Backup recovery key is not valid base64.');
    }
    if (decoded.length != 32) {
      throw const FormatException(
        'Backup recovery key must contain a 256-bit key.',
      );
    }
    await _secureStore.writeString(_keyName, base64Encode(decoded));
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
    final String? format = payload['format'] as String?;
    if (payload.isEmpty || isLegacyPlaintextBackup(payload)) {
      return payload;
    }
    if ((format != _format && format != _legacyFormat) ||
        payload['iv'] is! String ||
        payload['ciphertext'] is! String) {
      throw const FormatException(
        'Cloud backup is neither encrypted nor a supported legacy backup.',
      );
    }
    final encrypt.Key key = await _loadKeyForDecryption();
    final bool legacy = format == _legacyFormat;
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

  Future<encrypt.Key> _loadOrCreateKey() async {
    final String? stored = await _readStoredKey();
    if (stored != null && stored.trim().isNotEmpty) {
      return encrypt.Key(base64Decode(stored));
    }
    final Uint8List bytes = Uint8List.fromList(
      List<int>.generate(32, (_) => Random.secure().nextInt(256)),
    );
    await _secureStore.writeString(_keyName, base64Encode(bytes));
    return encrypt.Key(bytes);
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
