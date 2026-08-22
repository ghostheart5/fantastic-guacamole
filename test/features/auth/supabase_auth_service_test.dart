import 'dart:async';

import 'package:fantastic_guacamole/data/models/auth_models.dart';
import 'package:fantastic_guacamole/data/services/auth_service.dart';
import 'package:fantastic_guacamole/data/services/local_user_data_cleanup_service.dart';
import 'package:fantastic_guacamole/data/storage/hive_service.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

class _FakeCleanupService extends LocalUserDataCleanupService {
  _FakeCleanupService({required SecureStore store})
    : super(
        preferences: const SharedPrefsStoreAdapter(),
        hive: const HiveStoreAdapter(),
        secureStore: store,
      );

  int clearCalls = 0;
  int prepareCalls = 0;
  int prepareSignOutCalls = 0;
  int clearLocalDataCalls = 0;
  String? clearedUserId;

  @override
  Future<void> prepareForAccountDeletion() async {
    prepareCalls += 1;
  }

  @override
  Future<void> clearLocalData({String? userId}) async {
    clearLocalDataCalls += 1;
    clearedUserId = userId;
    await secureStore.deleteAll();
  }

  @override
  Future<void> clear({String? userId}) async {
    clearCalls += 1;
    clearedUserId = userId;
    await secureStore.delete('auth.cached_session');
    await secureStore.delete('profile_state_v2');
  }

  @override
  Future<void> prepareForSignOut() async {
    prepareSignOutCalls += 1;
  }
}

class _FakeSupabaseClient extends sb.SupabaseClient {
  _FakeSupabaseClient({required this.authClient})
    : super('https://example.supabase.co', 'public-anon-key');

  final sb.GoTrueClient authClient;

  @override
  sb.GoTrueClient get auth => authClient;
}

class _FakeGoTrueClient extends sb.GoTrueClient {
  _FakeGoTrueClient(this._authState)
    : super(url: 'https://example.supabase.co');

  final StreamController<sb.AuthState> _authState;
  bool failNextRefreshSessionWithNetworkError = false;
  bool signUpRequiresConfirmation = false;
  bool failSignOut = false;
  int refreshSessionCallCount = 0;
  int signUpCallCount = 0;
  int resendCallCount = 0;
  String? lastSignUpRedirect;
  String? lastResendRedirect;
  String? lastPasswordResetRedirect;

  @override
  Stream<sb.AuthState> get onAuthStateChange => _authState.stream;

  @override
  Future<sb.AuthResponse> signInWithPassword({
    String? email,
    String? phone,
    required String password,
    String? captchaToken,
  }) async {
    if (email == 'bad@example.com') {
      throw const sb.AuthException('Invalid login credentials');
    }
    return _buildAuthResponse(
      userId: 'u1',
      email: email ?? 'person@example.com',
    );
  }

  @override
  Future<sb.AuthResponse> signUp({
    String? email,
    String? phone,
    required String password,
    String? emailRedirectTo,
    Map<String, dynamic>? data,
    String? captchaToken,
    sb.OtpChannel channel = sb.OtpChannel.sms,
  }) async {
    signUpCallCount += 1;
    lastSignUpRedirect = emailRedirectTo;
    if ((email ?? '').contains('fail')) {
      throw const sb.AuthException('Sign-up failed');
    }
    if (signUpRequiresConfirmation) {
      final sb.User user = _buildUser(
        userId: 'u2',
        email: email ?? 'person@example.com',
        emailConfirmed: false,
      );
      _currentUser = null;
      _currentSession = null;
      return sb.AuthResponse(user: user, session: null);
    }
    return _buildAuthResponse(
      userId: 'u2',
      email: email ?? 'person@example.com',
    );
  }

  @override
  Future<void> signOut({sb.SignOutScope scope = sb.SignOutScope.local}) async {
    if (failSignOut) {
      throw TimeoutException('Remote sign-out failed');
    }
    _currentUser = null;
    _currentSession = null;
  }

  @override
  Future<sb.AuthResponse> refreshSession([String? refreshToken]) async {
    refreshSessionCallCount += 1;
    if (failNextRefreshSessionWithNetworkError) {
      failNextRefreshSessionWithNetworkError = false;
      throw TimeoutException('Transient network timeout during refreshSession');
    }
    return _buildAuthResponse(
      userId: 'u-refresh',
      email: 'refresh@example.com',
    );
  }

  @override
  Future<sb.ResendResponse> resend({
    String? email,
    String? phone,
    required sb.OtpType type,
    String? emailRedirectTo,
    String? captchaToken,
  }) async {
    resendCallCount += 1;
    lastResendRedirect = emailRedirectTo;
    return sb.ResendResponse(messageId: 'otp-message');
  }

  @override
  Future<void> signInWithOtp({
    String? email,
    String? phone,
    String? emailRedirectTo,
    bool? shouldCreateUser,
    Map<String, dynamic>? data,
    String? captchaToken,
    sb.OtpChannel channel = sb.OtpChannel.sms,
  }) async {}

  @override
  Future<sb.AuthResponse> verifyOTP({
    String? email,
    String? phone,
    String? token,
    required sb.OtpType type,
    String? redirectTo,
    String? captchaToken,
    String? tokenHash,
  }) async {
    return _buildAuthResponse(userId: 'u3', email: 'otp@example.com');
  }

  @override
  Future<void> resetPasswordForEmail(
    String email, {
    String? redirectTo,
    String? captchaToken,
  }) async {
    lastPasswordResetRedirect = redirectTo;
  }

  @override
  Future<sb.UserResponse> updateUser(
    sb.UserAttributes attributes, {
    String? emailRedirectTo,
  }) async {
    return sb.UserResponse.fromJson({
      'id': 'u3',
      'aud': 'authenticated',
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> signInWithOAuth(
    sb.OAuthProvider provider, {
    String? redirectTo,
  }) async {}

  @override
  sb.User? get currentUser => _currentUser;

  @override
  sb.Session? get currentSession => _currentSession;

  sb.User? _currentUser;
  sb.Session? _currentSession;

  void setAuthenticatedUser({
    required String provider,
    required String lastSignInAt,
  }) {
    _buildAuthResponse(
      userId: 'u1',
      email: provider == 'phone' ? '' : 'person@example.com',
      provider: provider,
      lastSignInAt: lastSignInAt,
    );
  }

  sb.AuthResponse _buildAuthResponse({
    required String userId,
    required String email,
    String provider = 'email',
    String? lastSignInAt,
  }) {
    final sb.User user = _buildUser(
      userId: userId,
      email: email,
      provider: provider,
      lastSignInAt: lastSignInAt,
    );
    final session = sb.Session(
      accessToken: 'abc',
      tokenType: 'bearer',
      user: user,
      expiresIn: 3600,
      refreshToken: 'refresh-$userId',
    );
    _currentUser = user;
    _currentSession = session;
    return sb.AuthResponse(user: user, session: session);
  }

  sb.User _buildUser({
    required String userId,
    required String email,
    bool emailConfirmed = true,
    String provider = 'email',
    String? lastSignInAt,
  }) {
    return sb.User(
      id: userId,
      email: email,
      appMetadata: <String, dynamic>{
        'provider': provider,
        'providers': <String>[provider],
      },
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: DateTime.now().toIso8601String(),
      lastSignInAt: lastSignInAt ?? DateTime.now().toUtc().toIso8601String(),
      emailConfirmedAt: emailConfirmed
          ? DateTime.now().toIso8601String()
          : null,
    );
  }
}

void main() {
  group('AuthService', () {
    late AuthService service;
    late _FakeGoTrueClient auth;
    late SecureStore store;
    late _FakeCleanupService cleanup;
    late DateTime now;
    late int deletionRequestCount;

    setUp(() {
      final authState = StreamController<sb.AuthState>.broadcast();
      auth = _FakeGoTrueClient(authState);
      final fakeClient = _FakeSupabaseClient(authClient: auth);
      store = SecureStore(backend: InMemorySecureStoreBackend());
      cleanup = _FakeCleanupService(store: store);
      now = DateTime.utc(2026, 8, 9, 18);
      deletionRequestCount = 0;
      service = AuthService(
        supabaseClient: fakeClient,
        store: store,
        httpClient: MockClient((http.Request request) async {
          deletionRequestCount += 1;
          return http.Response('{"completed":true}', 200);
        }),
        accountDeleteEndpoint:
            'https://example.supabase.co/functions/v1/account-delete',
        supabaseUrl: 'https://example.supabase.co',
        oauthGoogleRedirectUrl: 'chronospark://auth-callback',
        passwordRecoveryRedirectUrl: 'chronospark://auth-callback',
        localUserDataCleanupService: cleanup,
        clock: () => now,
      );
    });

    test('signUp returns a credential on success', () async {
      final credential = await service.signUp(
        email: 'person@example.com',
        password: 'Password123!',
      );
      expect(credential.user, isNotNull);
      expect(credential.user!.email, 'person@example.com');
    });

    test(
      'unconfirmed sign-up does not overwrite durable profile state',
      () async {
        auth.signUpRequiresConfirmation = true;
        await store.writeString('profile_state_v2', '{"name":"Existing"}');

        await service.signUp(
          email: 'new@example.com',
          password: 'Password123!',
        );

        expect(
          await store.readString('profile_state_v2'),
          '{"name":"Existing"}',
        );
        expect(auth.signUpCallCount, 1);
        expect(auth.resendCallCount, 0);
        expect(auth.lastSignUpRedirect, 'chronospark://auth-callback');
      },
    );

    test(
      'verified sign-up session hydrates a missing durable profile',
      () async {
        await service.signUp(
          email: 'verified@example.com',
          password: 'Password123!',
        );
        await service.awaitCurrentUserProfileHydration();

        final String? profile = await store.readString(
          'profile_state_v3.v2.dTI=',
        );
        expect(profile, isNotNull);
        expect(profile, contains('verified'));
      },
    );

    test('signUp surfaces sign-up failure', () async {
      expect(
        () =>
            service.signUp(email: 'fail@example.com', password: 'Password123!'),
        throwsA(isA<FirebaseAuthException>()),
      );
    });

    test(
      'signIn maps invalid credentials to a validation-style auth exception',
      () async {
        expect(
          () => service.signIn(
            email: 'bad@example.com',
            password: 'Password123!',
          ),
          throwsA(isA<FirebaseAuthException>()),
        );
      },
    );

    test('sendPhoneOtp and verifyPhoneOtp succeed with valid inputs', () async {
      await expectLater(service.sendPhoneOtp('+15551234567'), completes);
      final credential = await service.verifyPhoneOtp(
        phone: '+15551234567',
        token: '123456',
      );
      expect(credential.user, isNotNull);
    });

    test('signOut clears session state without exposing secrets', () async {
      await expectLater(service.signOut(), completes);
    });

    test(
      'failed remote sign-out preserves the active account until retry',
      () async {
        await service.signIn(
          email: 'person@example.com',
          password: 'Password123!',
        );
        await store.writeString('auth.cached_session', 'cached');
        await store.writeString('profile_state_v2', '{"name":"Person"}');
        auth.failSignOut = true;

        await expectLater(
          service.signOut,
          throwsA(isA<FirebaseAuthException>()),
        );

        expect(cleanup.prepareSignOutCalls, 1);
        expect(cleanup.clearCalls, 0);
        expect(auth.currentUser?.id, 'u1');
        expect(await store.readString('auth.cached_session'), 'cached');
        expect(await store.readString('profile_state_v2'), '{"name":"Person"}');
      },
    );

    test(
      'password deletion reauthenticates and completes both purge stages',
      () async {
        await service.signIn(
          email: 'person@example.com',
          password: 'Password123!',
        );

        await service.deleteCurrentAccount(password: 'Password123!');

        expect(deletionRequestCount, 1);
        expect(cleanup.prepareCalls, 1);
        expect(cleanup.clearLocalDataCalls, 1);
        expect(cleanup.clearedUserId, 'u1');
        expect(auth.currentUser, isNull);
      },
    );

    test(
      'fresh phone sign-in can delete without inventing a password',
      () async {
        auth.setAuthenticatedUser(
          provider: 'phone',
          lastSignInAt: now
              .subtract(const Duration(minutes: 9))
              .toIso8601String(),
        );

        await service.deleteCurrentAccount(password: '');

        expect(deletionRequestCount, 1);
        expect(cleanup.prepareCalls, 1);
        expect(cleanup.clearLocalDataCalls, 1);
      },
    );

    test(
      'stale Google sign-in is rejected before destructive cleanup',
      () async {
        auth.setAuthenticatedUser(
          provider: 'google',
          lastSignInAt: now
              .subtract(defaultAccountDeletionRecentSignInWindow)
              .toIso8601String(),
        );

        await expectLater(
          () => service.deleteCurrentAccount(password: ''),
          throwsA(
            isA<FirebaseAuthException>().having(
              (FirebaseAuthException error) => error.code,
              'code',
              'recent-sign-in-required',
            ),
          ),
        );

        expect(deletionRequestCount, 0);
        expect(cleanup.prepareCalls, 0);
        expect(cleanup.clearLocalDataCalls, 0);
      },
    );

    test(
      'account deletion never sends a bearer token off the Supabase origin',
      () async {
        await service.signIn(
          email: 'person@example.com',
          password: 'Password123!',
        );
        final AuthService untrustedEndpointService = AuthService(
          supabaseClient: _FakeSupabaseClient(authClient: auth),
          store: store,
          httpClient: MockClient((http.Request request) async {
            deletionRequestCount += 1;
            return http.Response('{}', 200);
          }),
          accountDeleteEndpoint:
              'https://attacker.example/functions/v1/account-delete',
          supabaseUrl: 'https://example.supabase.co',
          localUserDataCleanupService: cleanup,
        );

        await expectLater(
          () => untrustedEndpointService.deleteCurrentAccount(
            password: 'Password123!',
          ),
          throwsA(
            isA<FirebaseAuthException>().having(
              (FirebaseAuthException error) => error.code,
              'code',
              'operation-not-supported',
            ),
          ),
        );

        expect(deletionRequestCount, 0);
        expect(cleanup.prepareCalls, 0);
        expect(cleanup.clearLocalDataCalls, 0);
      },
    );

    test('explicit verification resend uses the configured callback', () async {
      await service.signIn(
        email: 'person@example.com',
        password: 'Password123!',
      );

      await service.sendEmailVerification();

      expect(auth.resendCallCount, 1);
      expect(auth.lastResendRedirect, 'chronospark://auth-callback');
    });

    test('password reset uses the configured recovery callback', () async {
      await service.sendPasswordReset('person@example.com');

      expect(auth.lastPasswordResetRedirect, 'chronospark://auth-callback');
    });

    test(
      'getCurrentSessionSnapshot exposes session details without logging secrets',
      () async {
        final snapshot = await service.getCurrentSessionSnapshot();
        expect(snapshot, isNull);
      },
    );

    test(
      'transient refresh failure maps to auth-unavailable and next refresh recovers',
      () async {
        auth.failNextRefreshSessionWithNetworkError = true;

        await expectLater(
          () => service.getIdToken(forceRefresh: true),
          throwsA(
            isA<FirebaseAuthException>().having(
              (FirebaseAuthException e) => e.code,
              'code',
              'auth-unavailable',
            ),
          ),
        );

        final token = await service.getIdToken(forceRefresh: true);
        expect(token, 'abc');
        expect(auth.refreshSessionCallCount, greaterThanOrEqualTo(2));
      },
    );

    test('session snapshot recovers after transient refresh failure', () async {
      auth.failNextRefreshSessionWithNetworkError = true;

      await expectLater(
        () => service.getCurrentSessionSnapshot(forceRefresh: true),
        throwsA(
          isA<FirebaseAuthException>().having(
            (FirebaseAuthException e) => e.code,
            'code',
            'auth-unavailable',
          ),
        ),
      );

      final snapshot = await service.getCurrentSessionSnapshot(
        forceRefresh: true,
      );
      expect(snapshot, isNotNull);
      expect(snapshot!.accessToken, 'abc');
      expect(snapshot.refreshToken, isNotEmpty);
    });
  });
}
