import 'dart:async';
import 'dart:convert';

import 'package:fantastic_guacamole/data/models/auth_models.dart';
import 'package:fantastic_guacamole/data/services/auth_service.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

void main() {
  group('AuthService account deletion helpers', () {
    test('parseSecureHttpsEndpoint accepts valid https endpoint', () {
      final Uri? uri = AuthService.parseSecureHttpsEndpoint(
        'https://api.chronospark.app/v1/account/delete',
      );

      expect(uri, isNotNull);
      expect(uri!.scheme, 'https');
      expect(uri.host, 'api.chronospark.app');
    });

    test('parseSecureHttpsEndpoint rejects non-https or invalid endpoint', () {
      expect(
        AuthService.parseSecureHttpsEndpoint(
          'http://api.chronospark.app/v1/account/delete',
        ),
        isNull,
      );
      expect(AuthService.parseSecureHttpsEndpoint('not-a-url'), isNull);
      expect(AuthService.parseSecureHttpsEndpoint('https:///delete'), isNull);
    });

    test('deletionFailureMessage does not expose backend response bodies', () {
      final String message = AuthService.deletionFailureMessage(
        statusCode: 403,
        responseBody: '{"message":"Deletion forbidden for this account."}',
      );

      expect(message, 'Account deletion failed (403). Please try again later.');
    });

    test('deletionFailureMessage falls back when body is not json', () {
      final String message = AuthService.deletionFailureMessage(
        statusCode: 500,
        responseBody: 'internal server error',
      );

      expect(message, 'Account deletion failed (500). Please try again later.');
    });
  });

  group('AuthService runtime behavior', () {
    test(
      'authStateChanges emits signed-in user with name fallback metadata',
      () async {
        final MockClient client = MockClient((http.Request request) async {
          if (request.url.path.endsWith('/auth/v1/token')) {
            return http.Response(
              jsonEncode(
                _authResponseJsonVariant(
                  email: 'pilot@chronospark.app',
                  userMetadata: <String, dynamic>{'name': 'Pilot Nova'},
                ),
              ),
              200,
              headers: <String, String>{'content-type': 'application/json'},
            );
          }
          return http.Response('{}', 200);
        });
        final AuthService service = AuthService(
          supabaseClient: _supabaseClient(client),
          store: SecureStore(backend: InMemorySecureStoreBackend()),
        );

        final Future<User?> nextUser = service.authStateChanges().firstWhere(
          (User? user) => user != null,
        );

        await service.signIn(
          email: 'pilot@chronospark.app',
          password: 'correct-pass',
        );

        final User? user = await nextUser;
        expect(user?.displayName, 'Pilot Nova');
        expect(user?.emailVerified, isTrue);
      },
    );

    test('signIn surfaces non-auth exceptions as auth-unavailable', () async {
      final AuthService service = AuthService(
        supabaseClient: _supabaseClient(
          MockClient((http.Request request) async {
            throw Exception('socket exploded');
          }),
        ),
        store: SecureStore(backend: InMemorySecureStoreBackend()),
      );

      await expectLater(
        () => service.signIn(
          email: 'operator@chronospark.app',
          password: 'correct-pass',
        ),
        throwsA(
          isA<FirebaseAuthException>().having(
            (e) => e.code,
            'code',
            'auth-unavailable',
          ),
        ),
      );
    });

    test('signUp maps created user into a credential', () async {
      final MockClient client = MockClient((http.Request request) async {
        if (request.url.path.endsWith('/auth/v1/signup')) {
          return http.Response(
            jsonEncode(_authResponseJson(email: 'new@chronospark.app')),
            200,
            headers: <String, String>{'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 200);
      });
      final AuthService service = AuthService(
        supabaseClient: _supabaseClient(client),
        store: SecureStore(backend: InMemorySecureStoreBackend()),
      );

      final UserCredential credential = await service.signUp(
        email: 'new@chronospark.app',
        password: 'CorrectPass123',
      );

      expect(credential.user, isNotNull);
      expect(credential.user?.email, 'new@chronospark.app');
    });

    test('signUp maps already registered auth backend errors', () async {
      final MockClient client = MockClient((http.Request request) async {
        if (request.url.path.endsWith('/auth/v1/signup')) {
          return http.Response(
            jsonEncode(<String, dynamic>{
              'msg': 'User has already been registered',
            }),
            400,
            headers: <String, String>{'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 200);
      });
      final AuthService service = AuthService(
        supabaseClient: _supabaseClient(client),
        store: SecureStore(backend: InMemorySecureStoreBackend()),
      );

      await expectLater(
        () => service.signUp(
          email: 'new@chronospark.app',
          password: 'CorrectPass123',
        ),
        throwsA(
          isA<FirebaseAuthException>().having(
            (e) => e.code,
            'code',
            'email-already-in-use',
          ),
        ),
      );
    });

    test(
      'sendPasswordReset posts recover request and returns normally',
      () async {
        int recoverCalls = 0;
        final MockClient client = MockClient((http.Request request) async {
          if (request.url.path.endsWith('/auth/v1/recover')) {
            recoverCalls += 1;
            return http.Response(
              '{}',
              200,
              headers: <String, String>{'content-type': 'application/json'},
            );
          }
          return http.Response('{}', 200);
        });
        final AuthService service = AuthService(
          supabaseClient: _supabaseClient(client),
          store: SecureStore(backend: InMemorySecureStoreBackend()),
        );

        await service.sendPasswordReset('operator@chronospark.app');

        expect(recoverCalls, 1);
      },
    );

    test('sendPasswordReset maps auth exceptions from backend', () async {
      final MockClient client = MockClient((http.Request request) async {
        if (request.url.path.endsWith('/auth/v1/recover')) {
          return http.Response(
            jsonEncode(<String, dynamic>{'msg': 'Email rate limit exceeded'}),
            429,
            headers: <String, String>{'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 200);
      });
      final AuthService service = AuthService(
        supabaseClient: _supabaseClient(client),
        store: SecureStore(backend: InMemorySecureStoreBackend()),
      );

      await expectLater(
        () => service.sendPasswordReset('operator@chronospark.app'),
        throwsA(
          isA<FirebaseAuthException>().having(
            (e) => e.code,
            'code',
            'too-many-requests',
          ),
        ),
      );
    });

    test(
      'sendEmailVerification throws when there is no signed-in user',
      () async {
        final AuthService service = AuthService(
          supabaseClient: _supabaseClient(
            MockClient(
              (http.Request request) async => http.Response('{}', 200),
            ),
          ),
          store: SecureStore(backend: InMemorySecureStoreBackend()),
        );

        await expectLater(
          () => service.sendEmailVerification(),
          throwsA(
            isA<FirebaseAuthException>().having(
              (e) => e.code,
              'code',
              'no-current-user',
            ),
          ),
        );
      },
    );

    test(
      'sendEmailVerification resends signup verification for signed-in user',
      () async {
        int resendCalls = 0;
        final MockClient client = MockClient((http.Request request) async {
          if (request.url.path.endsWith('/auth/v1/token')) {
            return http.Response(
              jsonEncode(_authResponseJson(email: 'operator@chronospark.app')),
              200,
              headers: <String, String>{'content-type': 'application/json'},
            );
          }
          if (request.url.path.endsWith('/auth/v1/resend')) {
            resendCalls += 1;
            return http.Response(
              '{}',
              200,
              headers: <String, String>{'content-type': 'application/json'},
            );
          }
          return http.Response('{}', 200);
        });
        final AuthService service = AuthService(
          supabaseClient: _supabaseClient(client),
          store: SecureStore(backend: InMemorySecureStoreBackend()),
        );

        await service.signIn(
          email: 'operator@chronospark.app',
          password: 'correct-pass',
        );
        await service.sendEmailVerification();

        expect(resendCalls, 1);
      },
    );

    test('sendEmailVerification maps auth resend failures', () async {
      int tokenCalls = 0;
      final MockClient client = MockClient((http.Request request) async {
        if (request.url.path.endsWith('/auth/v1/token')) {
          tokenCalls += 1;
          return http.Response(
            jsonEncode(_authResponseJson(email: 'operator@chronospark.app')),
            200,
            headers: <String, String>{'content-type': 'application/json'},
          );
        }
        if (request.url.path.endsWith('/auth/v1/resend')) {
          return http.Response(
            jsonEncode(<String, dynamic>{'msg': 'Email not confirmed'}),
            400,
            headers: <String, String>{'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 200);
      });
      final AuthService service = AuthService(
        supabaseClient: _supabaseClient(client),
        store: SecureStore(backend: InMemorySecureStoreBackend()),
      );

      await service.signIn(
        email: 'operator@chronospark.app',
        password: 'correct-pass',
      );

      await expectLater(
        () => service.sendEmailVerification(),
        throwsA(
          isA<FirebaseAuthException>().having(
            (e) => e.code,
            'code',
            'user-not-verified',
          ),
        ),
      );
      expect(tokenCalls, 1);
    });

    test('reloadCurrentUser and getIdToken use refreshSession path', () async {
      int tokenCalls = 0;
      final MockClient client = MockClient((http.Request request) async {
        if (request.url.path.endsWith('/auth/v1/token')) {
          tokenCalls += 1;
          return http.Response(
            jsonEncode(_authResponseJson(email: 'operator@chronospark.app')),
            200,
            headers: <String, String>{'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 200);
      });
      final AuthService service = AuthService(
        supabaseClient: _supabaseClient(client),
        store: SecureStore(backend: InMemorySecureStoreBackend()),
      );

      await service.signIn(
        email: 'operator@chronospark.app',
        password: 'correct-pass',
      );
      final User? user = await service.reloadCurrentUser();
      final String? token = await service.getIdToken(forceRefresh: true);

      expect(user?.email, 'operator@chronospark.app');
      expect(token, 'access-token');
      expect(tokenCalls, greaterThanOrEqualTo(2));
    });

    test('reloadCurrentUser maps refresh auth failures', () async {
      int tokenCalls = 0;
      final MockClient client = MockClient((http.Request request) async {
        if (request.url.path.endsWith('/auth/v1/token')) {
          tokenCalls += 1;
          if (tokenCalls == 1) {
            return http.Response(
              jsonEncode(_authResponseJson(email: 'operator@chronospark.app')),
              200,
              headers: <String, String>{'content-type': 'application/json'},
            );
          }
          return http.Response(
            jsonEncode(<String, dynamic>{'msg': 'Email rate limit exceeded'}),
            429,
            headers: <String, String>{'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 200);
      });
      final AuthService service = AuthService(
        supabaseClient: _supabaseClient(client),
        store: SecureStore(backend: InMemorySecureStoreBackend()),
      );

      await service.signIn(
        email: 'operator@chronospark.app',
        password: 'correct-pass',
      );

      await expectLater(
        () => service.reloadCurrentUser(),
        throwsA(
          isA<FirebaseAuthException>().having(
            (e) => e.code,
            'code',
            'too-many-requests',
          ),
        ),
      );
    });

    test('getIdToken maps refresh auth failures', () async {
      int tokenCalls = 0;
      final MockClient client = MockClient((http.Request request) async {
        if (request.url.path.endsWith('/auth/v1/token')) {
          tokenCalls += 1;
          if (tokenCalls == 1) {
            return http.Response(
              jsonEncode(_authResponseJson(email: 'operator@chronospark.app')),
              200,
              headers: <String, String>{'content-type': 'application/json'},
            );
          }
          return http.Response(
            jsonEncode(<String, dynamic>{'msg': 'Email rate limit exceeded'}),
            429,
            headers: <String, String>{'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 200);
      });
      final AuthService service = AuthService(
        supabaseClient: _supabaseClient(client),
        store: SecureStore(backend: InMemorySecureStoreBackend()),
      );

      await service.signIn(
        email: 'operator@chronospark.app',
        password: 'correct-pass',
      );

      await expectLater(
        () => service.getIdToken(forceRefresh: true),
        throwsA(
          isA<FirebaseAuthException>().having(
            (e) => e.code,
            'code',
            'too-many-requests',
          ),
        ),
      );
    });

    test('signOut clears current session user', () async {
      final MockClient client = MockClient((http.Request request) async {
        if (request.url.path.endsWith('/auth/v1/token')) {
          return http.Response(
            jsonEncode(_authResponseJson(email: 'operator@chronospark.app')),
            200,
            headers: <String, String>{'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 200);
      });
      final AuthService service = AuthService(
        supabaseClient: _supabaseClient(client),
        store: SecureStore(backend: InMemorySecureStoreBackend()),
      );

      await service.signIn(
        email: 'operator@chronospark.app',
        password: 'correct-pass',
      );
      await service.signOut();

      expect(service.currentUser, isNull);
    });

    test(
      'deleteCurrentAccount rejects missing password for signed-in user',
      () async {
        final MockClient client = MockClient((http.Request request) async {
          if (request.url.path.endsWith('/auth/v1/token')) {
            return http.Response(
              jsonEncode(_authResponseJson(email: 'operator@chronospark.app')),
              200,
              headers: <String, String>{'content-type': 'application/json'},
            );
          }
          return http.Response('{}', 200);
        });
        final AuthService service = AuthService(
          supabaseClient: _supabaseClient(client),
          store: SecureStore(backend: InMemorySecureStoreBackend()),
          httpClient: client,
          accountDeleteEndpoint: 'http://not-secure.example.com/delete',
        );

        await service.signIn(
          email: 'operator@chronospark.app',
          password: 'correct-pass',
        );

        await expectLater(
          () => service.deleteCurrentAccount(password: ''),
          throwsA(
            isA<FirebaseAuthException>().having(
              (e) => e.code,
              'code',
              'missing-password',
            ),
          ),
        );
      },
    );

    test('deleteCurrentAccount rejects when no user is signed in', () async {
      final AuthService service = AuthService(
        supabaseClient: _supabaseClient(
          MockClient((http.Request request) async => http.Response('{}', 200)),
        ),
        store: SecureStore(backend: InMemorySecureStoreBackend()),
        accountDeleteEndpoint: 'https://api.chronospark.app/account/delete',
      );

      await expectLater(
        () => service.deleteCurrentAccount(password: 'correct-pass'),
        throwsA(
          isA<FirebaseAuthException>().having(
            (e) => e.code,
            'code',
            'no-current-user',
          ),
        ),
      );
    });

    test(
      'deleteCurrentAccount rejects when current user email is unavailable',
      () async {
        final MockClient client = MockClient((http.Request request) async {
          if (request.url.path.endsWith('/auth/v1/token')) {
            return http.Response(
              jsonEncode(_authResponseJsonVariant(email: null)),
              200,
              headers: <String, String>{'content-type': 'application/json'},
            );
          }
          return http.Response('{}', 200);
        });
        final AuthService service = AuthService(
          supabaseClient: _supabaseClient(client),
          store: SecureStore(backend: InMemorySecureStoreBackend()),
          httpClient: client,
          accountDeleteEndpoint: 'https://api.chronospark.app/account/delete',
        );

        await service.signIn(
          email: 'operator@chronospark.app',
          password: 'correct-pass',
        );

        await expectLater(
          () => service.deleteCurrentAccount(password: 'correct-pass'),
          throwsA(
            isA<FirebaseAuthException>().having(
              (e) => e.code,
              'code',
              'missing-email',
            ),
          ),
        );
      },
    );

    test(
      'deleteCurrentAccount rejects when delete endpoint is not configured',
      () async {
        final MockClient client = MockClient((http.Request request) async {
          if (request.url.path.endsWith('/auth/v1/token')) {
            return http.Response(
              jsonEncode(_authResponseJson(email: 'operator@chronospark.app')),
              200,
              headers: <String, String>{'content-type': 'application/json'},
            );
          }
          return http.Response('{}', 200);
        });
        final AuthService service = AuthService(
          supabaseClient: _supabaseClient(client),
          store: SecureStore(backend: InMemorySecureStoreBackend()),
          httpClient: client,
          accountDeleteEndpoint: '   ',
        );

        await service.signIn(
          email: 'operator@chronospark.app',
          password: 'correct-pass',
        );

        await expectLater(
          () => service.deleteCurrentAccount(password: 'correct-pass'),
          throwsA(
            isA<FirebaseAuthException>().having(
              (e) => e.code,
              'code',
              'operation-not-supported',
            ),
          ),
        );
      },
    );

    test(
      'deleteCurrentAccount rejects invalid delete endpoint for signed-in user',
      () async {
        final MockClient client = MockClient((http.Request request) async {
          if (request.url.path.endsWith('/auth/v1/token')) {
            return http.Response(
              jsonEncode(_authResponseJson(email: 'operator@chronospark.app')),
              200,
              headers: <String, String>{'content-type': 'application/json'},
            );
          }
          return http.Response('{}', 200);
        });
        final AuthService service = AuthService(
          supabaseClient: _supabaseClient(client),
          store: SecureStore(backend: InMemorySecureStoreBackend()),
          httpClient: client,
          accountDeleteEndpoint: 'http://not-secure.example.com/delete',
        );

        await service.signIn(
          email: 'operator@chronospark.app',
          password: 'correct-pass',
        );
        await expectLater(
          () => service.deleteCurrentAccount(password: 'correct-pass'),
          throwsA(
            isA<FirebaseAuthException>().having(
              (e) => e.code,
              'code',
              'operation-not-supported',
            ),
          ),
        );
      },
    );

    test(
      'deleteCurrentAccount maps re-auth auth exceptions before backend call',
      () async {
        int tokenCalls = 0;
        final MockClient client = MockClient((http.Request request) async {
          if (request.url.path.endsWith('/auth/v1/token')) {
            tokenCalls += 1;
            if (tokenCalls == 1) {
              return http.Response(
                jsonEncode(
                  _authResponseJson(email: 'operator@chronospark.app'),
                ),
                200,
                headers: <String, String>{'content-type': 'application/json'},
              );
            }
            return http.Response(
              jsonEncode(<String, dynamic>{'msg': 'Invalid login credentials'}),
              400,
              headers: <String, String>{'content-type': 'application/json'},
            );
          }
          fail('Backend delete call should not happen when re-auth fails');
        });
        final AuthService service = AuthService(
          supabaseClient: _supabaseClient(client),
          store: SecureStore(backend: InMemorySecureStoreBackend()),
          httpClient: client,
          accountDeleteEndpoint: 'https://api.chronospark.app/account/delete',
        );

        await service.signIn(
          email: 'operator@chronospark.app',
          password: 'correct-pass',
        );

        await expectLater(
          () => service.deleteCurrentAccount(password: 'wrong-pass'),
          throwsA(
            isA<FirebaseAuthException>().having(
              (e) => e.code,
              'code',
              'wrong-password',
            ),
          ),
        );
      },
    );

    test(
      'deleteCurrentAccount rejects when re-authentication yields empty token',
      () async {
        int tokenCalls = 0;
        final MockClient client = MockClient((http.Request request) async {
          if (request.url.path.endsWith('/auth/v1/token')) {
            tokenCalls += 1;
            if (tokenCalls == 1) {
              return http.Response(
                jsonEncode(
                  _authResponseJson(email: 'operator@chronospark.app'),
                ),
                200,
                headers: <String, String>{'content-type': 'application/json'},
              );
            }
            return http.Response(
              jsonEncode(
                _authResponseJsonVariant(
                  email: 'operator@chronospark.app',
                  accessToken: '   ',
                ),
              ),
              200,
              headers: <String, String>{'content-type': 'application/json'},
            );
          }
          fail(
            'Backend delete call should not happen when access token is empty',
          );
        });
        final AuthService service = AuthService(
          supabaseClient: _supabaseClient(client),
          store: SecureStore(backend: InMemorySecureStoreBackend()),
          httpClient: client,
          accountDeleteEndpoint: 'https://api.chronospark.app/account/delete',
        );

        await service.signIn(
          email: 'operator@chronospark.app',
          password: 'correct-pass',
        );

        await expectLater(
          () => service.deleteCurrentAccount(password: 'correct-pass'),
          throwsA(
            isA<FirebaseAuthException>().having(
              (e) => e.code,
              'code',
              'auth-unavailable',
            ),
          ),
        );
      },
    );

    test('signIn maps invalid-email auth backend errors', () async {
      final MockClient client = MockClient((http.Request request) async {
        return http.Response(
          jsonEncode(<String, dynamic>{'msg': 'Email address invalid'}),
          400,
          headers: <String, String>{'content-type': 'application/json'},
        );
      });
      final AuthService service = AuthService(
        supabaseClient: _supabaseClient(client),
        store: SecureStore(backend: InMemorySecureStoreBackend()),
      );

      await expectLater(
        () => service.signIn(email: 'bad-email', password: 'correct-pass'),
        throwsA(
          isA<FirebaseAuthException>().having(
            (e) => e.code,
            'code',
            'invalid-email',
          ),
        ),
      );
    });

    test('signIn maps weak-password auth backend errors', () async {
      final MockClient client = MockClient((http.Request request) async {
        return http.Response(
          jsonEncode(<String, dynamic>{'msg': 'Password should be stronger'}),
          422,
          headers: <String, String>{'content-type': 'application/json'},
        );
      });
      final AuthService service = AuthService(
        supabaseClient: _supabaseClient(client),
        store: SecureStore(backend: InMemorySecureStoreBackend()),
      );

      await expectLater(
        () => service.signIn(
          email: 'operator@chronospark.app',
          password: 'correct-pass',
        ),
        throwsA(
          isA<FirebaseAuthException>().having(
            (e) => e.code,
            'code',
            'weak-password',
          ),
        ),
      );
    });

    test(
      'signIn maps invalid credentials and temporarily throttles retries',
      () async {
        final AuthService service = AuthService(
          supabaseClient: _supabaseClient(
            MockClient((http.Request request) async {
              if (request.url.path.endsWith('/auth/v1/token')) {
                return http.Response(
                  jsonEncode(<String, dynamic>{
                    'msg': 'Invalid login credentials',
                  }),
                  400,
                  headers: <String, String>{'content-type': 'application/json'},
                );
              }
              return http.Response('{}', 200);
            }),
          ),
          store: SecureStore(backend: InMemorySecureStoreBackend()),
        );

        await expectLater(
          () => service.signIn(
            email: 'operator@chronospark.app',
            password: 'wrong-pass',
          ),
          throwsA(
            isA<FirebaseAuthException>().having(
              (e) => e.code,
              'code',
              'wrong-password',
            ),
          ),
        );

        await expectLater(
          () => service.signIn(
            email: 'operator@chronospark.app',
            password: 'wrong-pass',
          ),
          throwsA(
            isA<FirebaseAuthException>().having(
              (e) => e.code,
              'code',
              'too-many-requests',
            ),
          ),
        );
      },
    );

    test(
      'deleteCurrentAccount clears local state only after confirmed backend success',
      () async {
        final InMemorySecureStoreBackend backend = InMemorySecureStoreBackend();
        final SecureStore store = SecureStore(backend: backend);
        await store.writeString('session-cache', 'present');
        int deleteCalls = 0;
        final MockClient client = MockClient((http.Request request) async {
          if (request.url.path.endsWith('/auth/v1/token')) {
            return http.Response(
              jsonEncode(_authResponseJson(email: 'operator@chronospark.app')),
              200,
              headers: <String, String>{'content-type': 'application/json'},
            );
          }
          if (request.url.toString() ==
              'https://api.chronospark.app/account/delete') {
            deleteCalls += 1;
            expect(request.headers['authorization'], 'Bearer access-token');
            expect(jsonDecode(request.body), <String, dynamic>{
              'userId': 'user-1',
              'email': 'operator@chronospark.app',
            });
            return http.Response('{}', 204);
          }
          return http.Response('{}', 200);
        });

        final AuthService service = AuthService(
          supabaseClient: _supabaseClient(client),
          store: store,
          httpClient: client,
          accountDeleteEndpoint: 'https://api.chronospark.app/account/delete',
        );

        await service.signIn(
          email: 'operator@chronospark.app',
          password: 'correct-pass',
        );
        await service.deleteCurrentAccount(password: 'correct-pass');

        expect(deleteCalls, 1);
        expect(await store.readString('session-cache'), isNull);
        expect(service.currentUser, isNull);
      },
    );

    test(
      'deleteCurrentAccount preserves local state when backend deletion fails',
      () async {
        final InMemorySecureStoreBackend backend = InMemorySecureStoreBackend();
        final SecureStore store = SecureStore(backend: backend);
        await store.writeString('session-cache', 'present');
        final MockClient client = MockClient((http.Request request) async {
          if (request.url.path.endsWith('/auth/v1/token')) {
            return http.Response(
              jsonEncode(_authResponseJson(email: 'operator@chronospark.app')),
              200,
              headers: <String, String>{'content-type': 'application/json'},
            );
          }
          if (request.url.toString() ==
              'https://api.chronospark.app/account/delete') {
            return http.Response(
              '{"message":"Deletion is blocked while subscription is active."}',
              409,
              headers: <String, String>{'content-type': 'application/json'},
            );
          }
          return http.Response('{}', 200);
        });

        final AuthService service = AuthService(
          supabaseClient: _supabaseClient(client),
          store: store,
          httpClient: client,
          accountDeleteEndpoint: 'https://api.chronospark.app/account/delete',
        );

        await service.signIn(
          email: 'operator@chronospark.app',
          password: 'correct-pass',
        );

        await expectLater(
          () => service.deleteCurrentAccount(password: 'correct-pass'),
          throwsA(
            isA<FirebaseAuthException>().having(
              (e) => e.message,
              'message',
              'Account deletion failed (409). Please try again later.',
            ),
          ),
        );

        expect(await store.readString('session-cache'), 'present');
        expect(service.currentUser, isNotNull);
      },
    );

    test(
      'deleteCurrentAccount surfaces timeout as network-request-failed',
      () async {
        final MockClient client = MockClient((http.Request request) async {
          if (request.url.path.endsWith('/auth/v1/token')) {
            return http.Response(
              jsonEncode(_authResponseJson(email: 'operator@chronospark.app')),
              200,
              headers: <String, String>{'content-type': 'application/json'},
            );
          }
          throw TimeoutException('timed out');
        });
        final AuthService service = AuthService(
          supabaseClient: _supabaseClient(client),
          store: SecureStore(backend: InMemorySecureStoreBackend()),
          httpClient: client,
          accountDeleteEndpoint: 'https://api.chronospark.app/account/delete',
        );

        await service.signIn(
          email: 'operator@chronospark.app',
          password: 'correct-pass',
        );

        await expectLater(
          () => service.deleteCurrentAccount(password: 'correct-pass'),
          throwsA(
            isA<FirebaseAuthException>().having(
              (e) => e.code,
              'code',
              'network-request-failed',
            ),
          ),
        );
      },
    );
  });
}

sb.SupabaseClient _supabaseClient(http.Client client) {
  return sb.SupabaseClient(
    'https://chronospark.example.com',
    'anon-key',
    httpClient: client,
    authOptions: const sb.AuthClientOptions(
      authFlowType: sb.AuthFlowType.implicit,
    ),
  );
}

Map<String, dynamic> _authResponseJson({required String email}) {
  return _authResponseJsonVariant(email: email);
}

Map<String, dynamic> _authResponseJsonVariant({
  String accessToken = 'access-token',
  String? email = 'operator@chronospark.app',
  Map<String, dynamic>? userMetadata,
}) {
  return <String, dynamic>{
    'access_token': accessToken,
    'token_type': 'bearer',
    'expires_in': 3600,
    'refresh_token': 'refresh-token',
    'user': <String, dynamic>{
      'id': 'user-1',
      'aud': 'authenticated',
      'email': email,
      'created_at': '2026-07-05T00:00:00.000Z',
      'email_confirmed_at': '2026-07-05T00:00:00.000Z',
      'app_metadata': <String, dynamic>{},
      'user_metadata':
          userMetadata ?? <String, dynamic>{'full_name': 'Operator One'},
    },
  };
}
