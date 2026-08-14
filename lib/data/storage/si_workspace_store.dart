import 'dart:convert';

import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';

/// Storage boundary for the authenticated AI conversation workspace payload.
class SiWorkspaceStore {
  SiWorkspaceStore(this._store, {required this.storageScope});

  static const String legacyStorageKey = 'si_engine_workspace_v1';
  static const String _v2KeyPrefix = 'si_engine_workspace_v2';

  final SecureStore _store;
  final AccountStorageScope storageScope;

  String get _key => canonicalStorageKeyForScope(storageScope);

  static String canonicalStorageKeyForScope(AccountStorageScope scope) {
    final String? namespace = scope.v2Namespace;
    if (!scope.isAuthenticated || namespace == null) {
      throw StateError(
        'SI workspace persistence is unavailable outside a safe authenticated scope.',
      );
    }
    return '$_v2KeyPrefix.$namespace';
  }

  Future<Map<String, dynamic>?> load() async {
    final String? raw = await _store.readString(_key);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map<dynamic, dynamic>) {
        return decoded.cast<String, dynamic>();
      }
      throw const FormatException('Stored SI workspace is not a JSON object.');
    } on Object catch (error) {
      Logger.error('Stored SI workspace state is corrupt.', error);
      throw StateError('Stored SI workspace state is corrupt.');
    }
  }

  Future<void> save(Map<String, dynamic> state) {
    return _store.writeString(_key, jsonEncode(state));
  }
}
