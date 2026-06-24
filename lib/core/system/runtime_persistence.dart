import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class RuntimePersistence {
  Future<Map<String, dynamic>?> loadSnapshot();
  Future<void> saveSnapshot(Map<String, dynamic> snapshot);
}

class SharedPrefsRuntimePersistence implements RuntimePersistence {
  SharedPrefsRuntimePersistence({this.key = 'runtime_state_v2'});

  final String key;

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  @override
  Future<Map<String, dynamic>?> loadSnapshot() async {
    final String? raw = await _secureStorage.read(key: key);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveSnapshot(Map<String, dynamic> snapshot) async {
    await _secureStorage.write(key: key, value: jsonEncode(snapshot));
  }
}
