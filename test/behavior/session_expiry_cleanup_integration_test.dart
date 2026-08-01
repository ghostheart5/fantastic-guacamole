import 'dart:convert';

import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/data/storage/storage_keys.dart';
import 'package:fantastic_guacamole/state/services/expired_session_cleanup.dart';
import 'package:fantastic_guacamole/state/services/retention_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Session expiry cleanup integration', () {
    late SecureStore store;
    late ExpiredSessionCleanup cleanup;

    setUp(() {
      store = SecureStore(backend: InMemorySecureStoreBackend());
      cleanup = ExpiredSessionCleanup(
        secureStore: store,
        retentionPolicy: const RetentionPolicy(
          sessionMaxAge: Duration(days: 30),
          staleNotificationAge: Duration(days: 14),
          hygieneInterval: Duration(hours: 6),
        ),
      );
    });

    test('removes session and credentials when expiresAt is in the past', () async {
      final DateTime expired = DateTime.now().subtract(const Duration(hours: 1));
      await store.writeString(
        StorageKeys.session,
        jsonEncode(<String, dynamic>{'expiresAt': expired.toIso8601String()}),
      );
      await store.writeString(StorageKeys.credentials, 'cred-value');

      final bool removed = await cleanup.run();

      expect(removed, isTrue);
      expect(await store.readString(StorageKeys.session), isNull);
      expect(await store.readString(StorageKeys.credentials), isNull);
    });

    test('retains session when expiresAt is in the future', () async {
      final DateTime valid = DateTime.now().add(const Duration(hours: 2));
      await store.writeString(
        StorageKeys.session,
        jsonEncode(<String, dynamic>{'expiresAt': valid.toIso8601String()}),
      );
      await store.writeString(StorageKeys.credentials, 'cred-value');

      final bool removed = await cleanup.run();

      expect(removed, isFalse);
      expect(await store.readString(StorageKeys.session), isNotNull);
      expect(await store.readString(StorageKeys.credentials), 'cred-value');
    });

    test('removes stale session when fallback createdAt exceeds retention policy', () async {
      final DateTime staleCreatedAt = DateTime.now().subtract(const Duration(days: 60));
      await store.writeString(
        StorageKeys.session,
        jsonEncode(<String, dynamic>{'createdAt': staleCreatedAt.toIso8601String()}),
      );
      await store.writeString(StorageKeys.credentials, 'cred-value');

      final bool removed = await cleanup.run();

      expect(removed, isTrue);
      expect(await store.readString(StorageKeys.session), isNull);
      expect(await store.readString(StorageKeys.credentials), isNull);
    });
  });
}
