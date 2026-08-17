import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:fantastic_guacamole/data/storage/secure_store.dart';

/// Encrypts cloud backup payloads before they leave the device.
class BackupCipher {
  BackupCipher(this._secureStore);

  static const String _keyName = 'cloud_backup_encryption_key_v1';
  static const String _format = 'chronospark_backup_aes256_gcm_v2';
  static const String _legacyFormat = 'chronospark_backup_aes256_v1';

  final SecureStore _secureStore;

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
    if ((format != _format && format != _legacyFormat) ||
        payload['iv'] is! String ||
        payload['ciphertext'] is! String) {
      return payload;
    }
    final encrypt.Key key = await _loadOrCreateKey();
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

  Future<encrypt.Key> _loadOrCreateKey() async {
    final String? stored = await _secureStore.readString(_keyName);
    if (stored != null && stored.trim().isNotEmpty) {
      return encrypt.Key(base64Decode(stored));
    }
    final Uint8List bytes = Uint8List.fromList(
      List<int>.generate(32, (_) => Random.secure().nextInt(256)),
    );
    await _secureStore.writeString(_keyName, base64Encode(bytes));
    return encrypt.Key(bytes);
  }
}
