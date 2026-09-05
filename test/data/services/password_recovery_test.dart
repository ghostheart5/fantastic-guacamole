import 'dart:async';
import 'dart:convert';

import 'package:fantastic_guacamole/data/models/auth_models.dart';
import 'package:fantastic_guacamole/data/services/auth_service.dart';
import 'package:fantastic_guacamole/data/services/supabase_password_recovery.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('reset email has the exact registered native redirect', () async {
    final fixture = _Fixture();
    addTearDown(fixture.dispose);
    await fixture.service.sendPasswordReset('user@example.com');
    expect(
      fixture.requests.single.url.queryParameters['redirect_to'],
      'chronospark://auth-callback',
    );
  });

  test('ordinary sign-in is not a recovery grant', () async {
    final fixture = _Fixture();
    addTearDown(fixture.dispose);
    await fixture.signIn();
    await expectLater(
      fixture.service.completePasswordRecovery(newPassword: 'NewPass123!'),
      throwsA(_recoveryRequired),
    );
    expect(fixture.passwordPuts, isEmpty);
  });

  test('cold-start capture retains recovery across later SDK refresh', () async {
    final fixture = _Fixture(createService: false);
    addTearDown(fixture.dispose);
    // Production attaches here, before SDK callback exchange, not when UI loads.
    SupabasePasswordRecovery.forClient(fixture.client);
    await fixture.recover();
    await fixture.client.auth.refreshSession();
    await _flush();
    fixture.createService();
    expect(fixture.service.passwordRecoveryState.isPending, isTrue);
    expect(
      (await fixture.service.passwordRecoveryChanges.first).isPending,
      isTrue,
    );
    await fixture.service.completePasswordRecovery(newPassword: 'NewPass123!');
    expect(fixture.passwordPuts, hasLength(1));
    expect(fixture.service.passwordRecoveryState.isPending, isFalse);
  });

  test('same-user new session and another account revoke recovery', () async {
    final fixture = _Fixture();
    addTearDown(fixture.dispose);
    await fixture.recover();
    fixture.sessionId = 'session-two';
    await fixture.signIn();
    expect(fixture.service.passwordRecoveryState.isPending, isFalse);
    await expectLater(
      fixture.service.completePasswordRecovery(newPassword: 'NewPass123!'),
      throwsA(_recoveryRequired),
    );
    await fixture.recover();
    fixture.userId = 'user-two';
    await fixture.signIn();
    expect(fixture.service.passwordRecoveryState.isPending, isFalse);
    expect(fixture.passwordPuts, isEmpty);
  });

  test(
    'failed and malformed password responses keep the recovery gate',
    () async {
      final fixture = _Fixture();
      addTearDown(fixture.dispose);
      await fixture.recover();
      fixture.passwordResponse = () async => _json({'msg': 'weak'}, 422);
      await expectLater(
        fixture.service.completePasswordRecovery(newPassword: 'NewPass123!'),
        throwsA(isA<FirebaseAuthException>()),
      );
      expect(fixture.service.passwordRecoveryState.isPending, isTrue);
      fixture.passwordResponse = () async => _json({'id': 'wrong-account'});
      await expectLater(
        fixture.service.completePasswordRecovery(newPassword: 'NewPass123!'),
        throwsA(isA<FirebaseAuthException>()),
      );
      expect(fixture.service.passwordRecoveryState.isPending, isTrue);
    },
  );

  test(
    'late password response cannot overwrite a newer account recovery',
    () async {
      final fixture = _Fixture();
      addTearDown(fixture.dispose);
      await fixture.recover();
      final entered = Completer<void>();
      final response = Completer<http.Response>();
      fixture.passwordResponse = () {
        entered.complete();
        return response.future;
      };
      final originalToken = fixture.client.auth.currentSession!.accessToken;
      final update = fixture.service.completePasswordRecovery(
        newPassword: 'NewPass123!',
      );
      final rejected = expectLater(update, throwsA(_recoveryRequired));
      await entered.future;
      fixture.userId = 'user-two';
      fixture.sessionId = 'session-two';
      await fixture.recover();
      final revision = fixture.service.passwordRecoveryState.revision;
      response.complete(_json(_user('user-one')));
      await rejected;
      expect(
        fixture.passwordPuts.single.headers['Authorization'],
        'Bearer $originalToken',
      );
      expect(fixture.client.auth.currentUser!.id, 'user-two');
      expect(fixture.service.passwordRecoveryState.userId, 'user-two');
      expect(fixture.service.passwordRecoveryState.revision, revision);
    },
  );

  test(
    'cancel cannot sign out another account during reminder cleanup',
    () async {
      final entered = Completer<void>();
      final resume = Completer<void>();
      final fixture = _Fixture(
        beforeSignOut: (_) {
          entered.complete();
          return resume.future;
        },
      );
      addTearDown(fixture.dispose);
      await fixture.recover();
      final cancel = fixture.service.cancelPasswordRecovery();
      final rejected = expectLater(cancel, throwsA(_recoveryRequired));
      await entered.future;
      fixture.userId = 'user-two';
      fixture.sessionId = 'session-two';
      await fixture.signIn();
      resume.complete();
      await rejected;
      expect(fixture.client.auth.currentUser!.id, 'user-two');
      expect(
        fixture.requests.where((r) => r.url.path.endsWith('/logout')),
        isEmpty,
      );
      expect(
        fixture.requests.where((r) => r.url.path.contains('/rpc/')),
        isEmpty,
      );
    },
  );

  test('cancel signs out only after notification cleanup succeeds', () async {
    final fixture = _Fixture();
    addTearDown(fixture.dispose);
    await fixture.recover();
    await fixture.service.cancelPasswordRecovery();
    await _flush();
    expect(fixture.client.auth.currentSession, isNull);
    expect(fixture.service.passwordRecoveryState.isPending, isFalse);
  });
}

final Matcher _recoveryRequired = isA<FirebaseAuthException>().having(
  (error) => error.code,
  'code',
  'recovery-session-required',
);

Future<void> _flush() => Future<void>.delayed(Duration.zero);

class _Fixture {
  _Fixture({bool createService = true, this.beforeSignOut}) {
    httpClient = MockClient((request) async {
      requests.add(request);
      if (request.method == 'PUT' && request.url.path.endsWith('/user')) {
        passwordPuts.add(request);
        return passwordResponse?.call() ?? _json(_user(userId));
      }
      if (request.url.path.endsWith('/verify') ||
          request.url.path.endsWith('/token')) {
        return _json(_session(userId, sessionId));
      }
      return _json(<String, Object?>{});
    });
    client = sb.SupabaseClient(
      'https://example.supabase.co',
      'public-test-key',
      httpClient: httpClient,
      authOptions: const sb.AuthClientOptions(
        autoRefreshToken: false,
        authFlowType: sb.AuthFlowType.implicit,
      ),
    );
    if (createService) this.createService();
  }

  late final MockClient httpClient;
  late final sb.SupabaseClient client;
  late AuthService service;
  String userId = 'user-one';
  String sessionId = 'session-one';
  final Future<void> Function(String)? beforeSignOut;
  Future<http.Response> Function()? passwordResponse;
  final List<http.Request> requests = [];
  final List<http.Request> passwordPuts = [];

  void createService() {
    service = AuthService(
      supabaseClient: client,
      httpClient: httpClient,
      passwordUpdateEndpoint: 'https://example.supabase.co/auth/v1/user',
      store: SecureStore(backend: InMemorySecureStoreBackend()),
      onBeforeSignedOut: beforeSignOut,
      onDevicePushTokenRevoked: () async {},
    );
  }

  Future<void> recover() async {
    await client.auth.verifyOTP(
      email: 'user@example.com',
      token: '123456',
      type: sb.OtpType.recovery,
    );
    await _flush();
  }

  Future<void> signIn() async {
    await client.auth.signInWithPassword(
      email: 'user@example.com',
      password: 'OldPass123!',
    );
    await _flush();
  }

  Future<void> dispose() async {
    await SupabasePasswordRecovery.forClient(client).dispose();
    await client.dispose();
    httpClient.close();
  }
}

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

Map<String, Object?> _user(String id) => {
  'id': id,
  'aud': 'authenticated',
  'email': 'user@example.com',
  'created_at': '2026-09-01T00:00:00.000Z',
  'email_confirmed_at': '2026-09-01T00:00:00.000Z',
  'app_metadata': <String, Object?>{},
  'user_metadata': <String, Object?>{},
};

Map<String, Object?> _session(String id, String sessionId) {
  final payload = base64Url
      .encode(
        utf8.encode(
          jsonEncode({
            'sub': id,
            'session_id': sessionId,
            'exp':
                DateTime.now()
                    .add(const Duration(hours: 1))
                    .millisecondsSinceEpoch ~/
                1000,
          }),
        ),
      )
      .replaceAll('=', '');
  return {
    'access_token': 'eyJhbGciOiJIUzI1NiJ9.$payload.test-signature',
    'token_type': 'bearer',
    'expires_in': 3600,
    'refresh_token': 'refresh-$sessionId',
    'user': _user(id),
  };
}
