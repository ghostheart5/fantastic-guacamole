import 'dart:convert';

import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';

/// Storage boundary for the legacy AI conversation workspace payload.
class SiWorkspaceStore {
  SiWorkspaceStore(this._store);

  static const String _workspaceStateKey = 'si_engine_workspace_v1';

  final SecureStore _store;

  Future<Map<String, dynamic>?> load() async {
    final String? raw = await _store.readString(_workspaceStateKey);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map<dynamic, dynamic>)
        return decoded.cast<String, dynamic>();
      throw const FormatException('Stored SI workspace is not a JSON object.');
    } on Object catch (error) {
      Logger.error('Stored SI workspace state is corrupt.', error);
      throw StateError('Stored SI workspace state is corrupt.');
    }
  }

  Future<void> save(Map<String, dynamic> state) {
    return _store.writeString(_workspaceStateKey, jsonEncode(state));
  }
}
