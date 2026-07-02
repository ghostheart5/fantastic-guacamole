import 'dart:convert';

import 'package:fantastic_guacamole/data/storage/secure_store.dart';

class SiEngineRepository {
  SiEngineRepository({required this._store});

  static const String _stateKey = 'si_engine_state_v1';
  final SecureStore _store;

  Future<Map<String, dynamic>?> loadState() async {
    final String? raw = await _store.readString(_stateKey);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map<dynamic, dynamic>) {
        return decoded.cast<String, dynamic>();
      }
      return null;
    } on FormatException {
      return null;
    }
  }

  Future<void> saveState(Map<String, dynamic> state) async {
    await _store.writeString(_stateKey, jsonEncode(state));
  }
}
