import 'dart:convert';

import 'package:fantastic_guacamole/data/storage/secure_store.dart';

import 'package:fantastic_guacamole/features/auth/domain/entities/auth_session_entity.dart';
import 'package:fantastic_guacamole/features/auth/data/datasources/auth_local_data_source.dart';

class SecureStoreAuthLocalDataSource implements AuthLocalDataSource {
  SecureStoreAuthLocalDataSource({required this._secureStore});

  static const String _sessionKey = 'auth.cached_session';

  final SecureStore _secureStore;

  @override
  Future<void> cacheSession(AuthSessionEntity? session) async {
    if (session == null) {
      await clearSession();
      return;
    }
    await _secureStore.writeString(_sessionKey, jsonEncode(session.toMap()));
  }

  @override
  Future<void> clearSession() {
    return _secureStore.delete(_sessionKey);
  }

  @override
  Future<AuthSessionEntity?> getCachedSession() async {
    final String? encoded = await _secureStore.readString(_sessionKey);
    if (encoded == null || encoded.isEmpty) {
      return null;
    }
    try {
      final Object? decoded = jsonDecode(encoded);
      if (decoded is! Map<String, dynamic>) {
        await clearSession();
        return null;
      }
      return AuthSessionEntity.fromMap(decoded);
    } on FormatException {
      await clearSession();
      return null;
    }
  }
}
