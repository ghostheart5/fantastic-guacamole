import 'dart:convert';

import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/data/storage/storage_keys.dart';
import 'package:fantastic_guacamole/state/services/retention_policy.dart';

class ExpiredSessionCleanup {
  const ExpiredSessionCleanup({
    required this._secureStore,
    required this._retentionPolicy,
  });

  final SecureStore _secureStore;
  final RetentionPolicy _retentionPolicy;

  Future<bool> run() async {
    final String? raw = await _secureStore.readString(StorageKeys.session);
    if (raw == null || raw.trim().isEmpty) {
      return false;
    }

    DateTime? expiry = _extractExpiry(raw);
    expiry ??= _extractTimestamp(raw);

    if (expiry == null) {
      return false;
    }

    if (expiry.isAfter(DateTime.now())) {
      return false;
    }

    await _secureStore.delete(StorageKeys.session);
    await _secureStore.delete(StorageKeys.credentials);
    return true;
  }

  DateTime? _extractExpiry(String raw) {
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }

      final Map<String, dynamic> map = decoded.map(
        (dynamic key, dynamic value) => MapEntry(key.toString(), value),
      );

      final Object? expiresAt = map['expiresAt'] ?? map['expires_at'];
      if (expiresAt == null) {
        return null;
      }

      if (expiresAt is num) {
        final int value = expiresAt.toInt();
        final bool milliseconds = value > 9999999999;
        return DateTime.fromMillisecondsSinceEpoch(
          milliseconds ? value : value * 1000,
          isUtc: true,
        ).toLocal();
      }

      if (expiresAt is String) {
        final DateTime? parsed = DateTime.tryParse(expiresAt);
        if (parsed != null) {
          return parsed.toLocal();
        }
      }

      return null;
    } on FormatException {
      return null;
    }
  }

  DateTime? _extractTimestamp(String raw) {
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }

      final Map<String, dynamic> map = decoded.map(
        (dynamic key, dynamic value) => MapEntry(key.toString(), value),
      );
      final Object? createdAt = map['createdAt'] ?? map['created_at'];
      if (createdAt is String) {
        final DateTime? parsed = DateTime.tryParse(createdAt);
        if (parsed != null &&
            _retentionPolicy.isSessionExpired(parsed.toLocal())) {
          return DateTime.now().subtract(const Duration(seconds: 1));
        }
      }
    } on FormatException {
      return null;
    }
    return null;
  }
}
