import 'dart:async';

import 'package:fantastic_guacamole/state/providers/repository_providers.dart';
import 'package:fantastic_guacamole/state/providers/storage_providers.dart';
import 'package:fantastic_guacamole/data/models/auth_models.dart' as app;
import 'package:fantastic_guacamole/data/repositories/firebase_supabase_bridge_repository.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/state/providers/intelligence_provider.dart';
import 'package:fantastic_guacamole/state/providers/service_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

void main() {
  group('firebaseSupabaseBridgeProvider auth transitions', () {
    test('does not clear local data on sign-out', () async {
      expect(await _cleanupProviderReadsForTransition(null), 0);
    });

    test('does not clear local data on account replacement', () async {
      expect(
        await _cleanupProviderReadsForTransition(
          const app.User(id: 'account-b', emailVerified: true),
        ),
        0,
      );
    });
  });
}

Future<int> _cleanupProviderReadsForTransition(app.User? nextUser) async {
  final StreamController<app.User?> authController =
      StreamController<app.User?>();
  int cleanupProviderReads = 0;
  final ProviderContainer container = ProviderContainer(
    overrides: [
      supabaseClientProvider.overrideWithValue(
        _FakeSupabaseClient(
          _FakeGoTrueClient(
            const sb.User(
              id: 'account-a',
              appMetadata: <String, dynamic>{},
              userMetadata: null,
              aud: 'authenticated',
              createdAt: '2026-08-27T00:00:00.000Z',
            ),
          ),
        ),
      ),
      authUserProvider.overrideWith((Ref ref) => authController.stream),
      firebaseSupabaseBridgeRepositoryProvider.overrideWithValue(
        FirebaseSupabaseBridgeRepository(
          store: SecureStore(backend: InMemorySecureStoreBackend()),
        ),
      ),
      localUserDataCleanupServiceProvider.overrideWith((Ref ref) {
        cleanupProviderReads += 1;
        throw StateError('Auth transitions must not request local cleanup.');
      }),
    ],
  );

  try {
    container.read(firebaseSupabaseBridgeProvider);
    authController.add(nextUser);
    await pumpEventQueue(times: 10);
    return cleanupProviderReads;
  } finally {
    container.dispose();
    await authController.close();
  }
}

class _FakeSupabaseClient implements sb.SupabaseClient {
  _FakeSupabaseClient(this.auth);

  @override
  final sb.GoTrueClient auth;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeGoTrueClient implements sb.GoTrueClient {
  _FakeGoTrueClient(this.currentUser);

  @override
  final sb.User? currentUser;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
