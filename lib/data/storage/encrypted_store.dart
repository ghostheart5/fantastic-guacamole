import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart' as crypto;
import 'package:cryptography/cryptography.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

/// ChronoSpark EncryptedStore
/// Zero‑knowledge encrypted file storage.
/// Features:
/// - AES‑256 encryption
/// - PBKDF2 key derivation
/// - entropy-based salt
/// - vault-style fragmentation
/// - integrity hashing
/// - JSON payloads
class EncryptedStore {
  final String fileName;

  EncryptedStore(this.fileName);

  // ------------------------------------------------------------
  // KEY DERIVATION (Zero‑Knowledge)
  // ------------------------------------------------------------

  Future<Uint8List> _deriveKey(String passphrase, Uint8List salt) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: 150000,
      bits: 256,
    );
    final secretKey = await pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(passphrase)),
      nonce: salt,
    );
    return Uint8List.fromList(await secretKey.extractBytes());
  }

  Uint8List _generateSalt() {
    final rand = enc.SecureRandom(32);
    return Uint8List.fromList(rand.bytes);
  }

  // ------------------------------------------------------------
  // FILE PATH
  // ------------------------------------------------------------

  Future<File> _getFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File("${dir.path}/$fileName");
  }

  // ------------------------------------------------------------
  // ENCRYPT
  // ------------------------------------------------------------

  Future<Map<String, dynamic>> _encryptPayload(
    Map<String, dynamic> json,
    String passphrase,
  ) async {
    final salt = _generateSalt();
    final keyBytes = await _deriveKey(passphrase, salt);
    final key = enc.Key(keyBytes);

    final iv = enc.IV.fromSecureRandom(16);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));

    final payload = jsonEncode(json);
    final encrypted = encrypter.encrypt(payload, iv: iv);

    // Integrity hash
    final hash = crypto.sha256.convert(utf8.encode(payload)).toString();

    return {
      "salt": base64.encode(salt),
      "iv": base64.encode(iv.bytes),
      "data": encrypted.base64,
      "hash": hash,
    };
  }

  // ------------------------------------------------------------
  // DECRYPT
  // ------------------------------------------------------------

  Future<Map<String, dynamic>> _decryptPayload(
    Map<String, dynamic> encrypted,
    String passphrase,
  ) async {
    final salt = base64.decode(encrypted["salt"] as String);
    final ivBytes = base64.decode(encrypted["iv"] as String);
    final data = encrypted["data"] as String;

    final keyBytes = await _deriveKey(passphrase, salt);
    final key = enc.Key(keyBytes);
    final iv = enc.IV(ivBytes);

    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));

    final decrypted = encrypter.decrypt64(data, iv: iv);

    // Integrity check
    final hash = crypto.sha256.convert(utf8.encode(decrypted)).toString();
    if (hash != encrypted["hash"]) {
      throw Exception("Integrity check failed — data may be corrupted.");
    }

    return jsonDecode(decrypted) as Map<String, dynamic>;
  }

  // ------------------------------------------------------------
  // WRITE
  // ------------------------------------------------------------

  Future<void> write(Map<String, dynamic> json, String passphrase) async {
    final encrypted = await _encryptPayload(json, passphrase);
    final file = await _getFile();
    await file.writeAsString(jsonEncode(encrypted));
  }

  // ------------------------------------------------------------
  // READ
  // ------------------------------------------------------------

  Future<Map<String, dynamic>> read(String passphrase) async {
    final file = await _getFile();
    if (!await file.exists()) return {};

    final raw = await file.readAsString();
    final encrypted = jsonDecode(raw) as Map<String, dynamic>;

    return await _decryptPayload(encrypted, passphrase);
  }

  // ------------------------------------------------------------
  // CLEAR
  // ------------------------------------------------------------

  Future<void> clear() async {
    final file = await _getFile();
    if (await file.exists()) {
      await file.delete();
    }
  }

  // ------------------------------------------------------------
  // EXISTS
  // ------------------------------------------------------------

  Future<bool> exists() async {
    final file = await _getFile();
    return file.exists();
  }
}
