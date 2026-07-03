import 'dart:math';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart';
import 'package:hive/hive.dart';

class SecureHiveAdapter extends TypeAdapter<String> {
  SecureHiveAdapter(this._key);

  final Key _key;

  @override
  final int typeId = 42;

  static const String _sep = '|';

  @override
  String read(BinaryReader reader) {
    final String raw = reader.readString();
    final int pivot = raw.indexOf(_sep);
    if (pivot == -1) return raw; // legacy unencrypted data
    try {
      final IV iv = IV.fromBase64(raw.substring(0, pivot));
      final Encrypter encrypter = Encrypter(AES(_key));
      return encrypter.decrypt64(raw.substring(pivot + 1), iv: iv);
    } catch (_) {
      return raw;
    }
  }

  @override
  void write(BinaryWriter writer, String value) {
    final Random rng = Random.secure();
    final IV iv = IV(
      Uint8List.fromList(List<int>.generate(16, (_) => rng.nextInt(256))),
    );
    final Encrypter encrypter = Encrypter(AES(_key));
    final Encrypted encrypted = encrypter.encrypt(value, iv: iv);
    writer.writeString('${iv.base64}$_sep${encrypted.base64}');
  }
}
