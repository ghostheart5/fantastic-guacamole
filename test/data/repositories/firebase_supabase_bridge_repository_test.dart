import 'dart:convert';

import 'package:fantastic_guacamole/data/repositories/firebase_supabase_bridge_repository.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

void main() {
  test(
    'push-token claims are device-serialized and bound to bearer auth',
    () async {
      final List<_RegistrationRequest> registrations = <_RegistrationRequest>[];
      final sb.SupabaseClient ownerA = _clientFor('owner-a', registrations);
      final sb.SupabaseClient ownerB = _clientFor('owner-b', registrations);
      await ownerA.auth.signInWithPassword(
        email: 'owner-a@example.com',
        password: 'password',
      );
      await ownerB.auth.signInWithPassword(
        email: 'owner-b@example.com',
        password: 'password',
      );
      final FirebaseSupabaseBridgeRepository repository =
          FirebaseSupabaseBridgeRepository(
            store: SecureStore(backend: InMemorySecureStoreBackend()),
          );

      await Future.wait(<Future<void>>[
        repository.syncFirebaseMessagingToken(ownerA, 'device-token-123456'),
        repository.syncFirebaseMessagingToken(ownerA, 'device-token-123456'),
      ]);
      await repository.syncFirebaseMessagingToken(
        ownerB,
        'device-token-123456',
      );

      expect(registrations, hasLength(2));
      expect(
        registrations
            .map((_RegistrationRequest value) => value.authorization)
            .toSet(),
        <String>{'Bearer access-token-owner-a', 'Bearer access-token-owner-b'},
      );
      expect(
        registrations
            .map(
              (_RegistrationRequest value) => value.body['p_installation_id'],
            )
            .toSet(),
        hasLength(1),
      );
      expect(
        registrations.first.body,
        containsPair('p_token', 'device-token-123456'),
      );
    },
  );
}

sb.SupabaseClient _clientFor(
  String userId,
  List<_RegistrationRequest> registrations,
) {
  return sb.SupabaseClient(
    'https://chronospark.example.com',
    'anon-key',
    httpClient: MockClient((http.Request request) async {
      if (request.url.path.endsWith('/auth/v1/token')) {
        return http.Response(
          jsonEncode(<String, dynamic>{
            'access_token': 'access-token-$userId',
            'token_type': 'bearer',
            'expires_in': 3600,
            'refresh_token': 'refresh-token-$userId',
            'user': <String, dynamic>{
              'id': userId,
              'aud': 'authenticated',
              'email': '$userId@example.com',
              'created_at': '2026-08-21T00:00:00.000Z',
              'email_confirmed_at': '2026-08-21T00:00:00.000Z',
              'app_metadata': <String, dynamic>{},
              'user_metadata': <String, dynamic>{'mutable_owner': 'ignored'},
            },
          }),
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      }
      if (request.url.path == '/rest/v1/rpc/register_firebase_device') {
        registrations.add((
          authorization: request.headers['authorization'] ?? '',
          body: (jsonDecode(request.body) as Map<dynamic, dynamic>).map(
            (dynamic key, dynamic value) => MapEntry(key.toString(), value),
          ),
        ));
        return http.Response(
          '1',
          200,
          headers: <String, String>{'content-type': 'application/json'},
          request: request,
        );
      }
      fail('Unexpected request: ${request.method} ${request.url}');
    }),
    authOptions: const sb.AuthClientOptions(
      authFlowType: sb.AuthFlowType.implicit,
    ),
  );
}

typedef _RegistrationRequest = ({
  String authorization,
  Map<String, dynamic> body,
});
