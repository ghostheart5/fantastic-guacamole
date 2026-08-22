import 'dart:convert';

import 'package:fantastic_guacamole/data/models/auth_models.dart';
import 'package:fantastic_guacamole/data/services/auth_service.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthService password and OAuth boundaries', () {
    test('updatePassword rejects blank input before reaching auth', () async {
      final AuthService service = _service(
        MockClient((http.Request request) async {
          fail('Blank passwords must be rejected before HTTP.');
        }),
      );

      await expectLater(
        () => service.updatePassword(newPassword: '   '),
        throwsA(
          isA<FirebaseAuthException>().having(
            (FirebaseAuthException error) => error.code,
            'code',
            'missing-password',
          ),
        ),
      );
    });

    test('updatePassword trims and sends the new password', () async {
      int updateCalls = 0;
      final MockClient client = MockClient((http.Request request) async {
        if (request.url.path.endsWith('/auth/v1/token')) {
          return _authResponse();
        }
        if (request.url.path.endsWith('/auth/v1/user')) {
          updateCalls += 1;
          expect(request.method, 'PUT');
          expect(jsonDecode(request.body), <String, dynamic>{
            'password': 'NewPass123!',
          });
          return http.Response(
            jsonEncode(_userJson()),
            200,
            headers: <String, String>{'content-type': 'application/json'},
          );
        }
        fail('Unexpected request: ${request.method} ${request.url}');
      });
      final AuthService service = _service(client);
      await service.signIn(
        email: 'planner@chronospark.app',
        password: 'correct-pass',
      );

      await service.updatePassword(newPassword: '  NewPass123!  ');

      expect(updateCalls, 1);
    });

    test('updatePassword maps backend auth failures', () async {
      final MockClient client = MockClient((http.Request request) async {
        if (request.url.path.endsWith('/auth/v1/token')) {
          return _authResponse();
        }
        if (request.url.path.endsWith('/auth/v1/user')) {
          return http.Response(
            jsonEncode(<String, dynamic>{'msg': 'Password should be stronger'}),
            422,
            headers: <String, String>{'content-type': 'application/json'},
          );
        }
        fail('Unexpected request: ${request.method} ${request.url}');
      });
      final AuthService service = _service(client);
      await service.signIn(
        email: 'planner@chronospark.app',
        password: 'correct-pass',
      );

      await expectLater(
        () => service.updatePassword(newPassword: 'weak'),
        throwsA(
          isA<FirebaseAuthException>().having(
            (FirebaseAuthException error) => error.code,
            'code',
            'weak-password',
          ),
        ),
      );
    });

    test(
      'signUp maps unexpected new-user failures without leaking details',
      () async {
        final AuthService service = _service(
          MockClient((http.Request request) async {
            return http.Response(
              jsonEncode(<String, dynamic>{
                'msg': 'Unexpected failure saving new user',
              }),
              500,
              headers: <String, String>{'content-type': 'application/json'},
            );
          }),
        );

        await expectLater(
          () => service.signUp(
            email: 'new@chronospark.app',
            password: 'CorrectPass123!',
          ),
          throwsA(
            isA<FirebaseAuthException>()
                .having(
                  (FirebaseAuthException error) => error.code,
                  'code',
                  'operation-failed',
                )
                .having(
                  (FirebaseAuthException error) => error.message,
                  'message',
                  isNot(contains('Unexpected failure')),
                ),
          ),
        );
      },
    );

    test('OAuth plugin failures are mapped to safe provider errors', () async {
      final AuthService service = _service(
        MockClient((http.Request request) async {
          fail('Generating an OAuth URL must not make an HTTP request.');
        }),
        googleRedirect: '   ',
        githubRedirect: 'chronospark://auth/callback',
      );

      await expectLater(
        () => service.signInWithGoogle(),
        throwsA(
          isA<FirebaseAuthException>()
              .having(
                (FirebaseAuthException error) => error.code,
                'code',
                'auth-unavailable',
              )
              .having(
                (FirebaseAuthException error) => error.message,
                'message',
                contains('Google'),
              ),
        ),
      );
      await expectLater(
        () => service.signInWithGitHub(),
        throwsA(
          isA<FirebaseAuthException>()
              .having(
                (FirebaseAuthException error) => error.code,
                'code',
                'auth-unavailable',
              )
              .having(
                (FirebaseAuthException error) => error.message,
                'message',
                contains('GitHub'),
              ),
        ),
      );
    });
  });
}

AuthService _service(
  http.Client client, {
  String googleRedirect = 'chronospark://auth/callback',
  String githubRedirect = 'chronospark://auth/callback',
}) {
  return AuthService(
    supabaseClient: sb.SupabaseClient(
      'https://chronospark.example.com',
      'anon-key',
      httpClient: client,
      authOptions: const sb.AuthClientOptions(
        authFlowType: sb.AuthFlowType.implicit,
      ),
    ),
    store: SecureStore(backend: InMemorySecureStoreBackend()),
    oauthGoogleRedirectUrl: googleRedirect,
    oauthGitHubRedirectUrl: githubRedirect,
  );
}

http.Response _authResponse() {
  return http.Response(
    jsonEncode(<String, dynamic>{
      'access_token': 'access-token',
      'token_type': 'bearer',
      'expires_in': 3600,
      'refresh_token': 'refresh-token',
      'user': _userJson(),
    }),
    200,
    headers: <String, String>{'content-type': 'application/json'},
  );
}

Map<String, dynamic> _userJson() {
  return <String, dynamic>{
    'id': 'user-1',
    'aud': 'authenticated',
    'email': 'planner@chronospark.app',
    'created_at': '2026-08-21T00:00:00.000Z',
    'email_confirmed_at': '2026-08-21T00:00:00.000Z',
    'app_metadata': <String, dynamic>{},
    'user_metadata': <String, dynamic>{},
  };
}
