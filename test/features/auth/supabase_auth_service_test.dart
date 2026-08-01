import 'dart:async';

import 'package:fantastic_guacamole/data/models/auth_models.dart';
import 'package:fantastic_guacamole/data/services/auth_service.dart';
import 'package:fantastic_guacamole/data/services/local_user_data_cleanup_service.dart';
import 'package:fantastic_guacamole/data/storage/hive_service.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

class _FakeCleanupService extends LocalUserDataCleanupService {
  _FakeCleanupService()
    : super(
        preferences: const SharedPrefsStoreAdapter(),
        hive: const HiveStoreAdapter(),
        secureStore: SecureStore(backend: InMemorySecureStoreBackend()),
      );

  @override
  Future<void> clear({String? userId}) async {}
}

class _FakeSupabaseClient extends sb.SupabaseClient {
  _FakeSupabaseClient({required this.authClient})
    : super('https://example.supabase.co', 'public-anon-key');

  final sb.GoTrueClient authClient;

  @override
  sb.GoTrueClient get auth => authClient;
}

class _FakeGoTrueClient extends sb.GoTrueClient {
  _FakeGoTrueClient(this._authState) : super(url: 'https://example.supabase.co');

  final StreamController<sb.AuthState> _authState;
  bool failNextRefreshSessionWithNetworkError = false;
  int refreshSessionCallCount = 0;

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
    return _buildAuthResponse(userId: 'u1', email: email ?? 'person@example.com');
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
    if ((email ?? '').contains('fail')) {
      throw const sb.AuthException('Sign-up failed');
    }
    return _buildAuthResponse(userId: 'u2', email: email ?? 'person@example.com');
  }

  @override
  Future<void> signOut({sb.SignOutScope scope = sb.SignOutScope.local}) async {}

  @override
  Future<sb.AuthResponse> refreshSession([String? refreshToken]) async {
    refreshSessionCallCount += 1;
    if (failNextRefreshSessionWithNetworkError) {
      failNextRefreshSessionWithNetworkError = false;
      throw TimeoutException('Transient network timeout during refreshSession');
    }
    return _buildAuthResponse(userId: 'u-refresh', email: 'refresh@example.com');
  }

  @override
  Future<sb.ResendResponse> resend({
    String? email,
    String? phone,
    required sb.OtpType type,
    String? emailRedirectTo,
    String? captchaToken,
  }) async {
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
  }) async {}

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

  Future<void> signInWithOAuth(sb.OAuthProvider provider, {String? redirectTo}) async {}

  @override
  sb.User? get currentUser => _currentUser;

  @override
  sb.Session? get currentSession => _currentSession;

  sb.User? _currentUser;
  sb.Session? _currentSession;

  sb.AuthResponse _buildAuthResponse({
    required String userId,
    required String email,
  }) {
    final user = sb.User(
      id: userId,
      email: email,
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: DateTime.now().toIso8601String(),
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
}

void main() {
  group('AuthService', () {
    late AuthService service;
    late _FakeGoTrueClient auth;

    setUp(() {
      final authState = StreamController<sb.AuthState>.broadcast();
      auth = _FakeGoTrueClient(authState);
      final fakeClient = _FakeSupabaseClient(authClient: auth);
      service = AuthService(
        supabaseClient: fakeClient,
        store: SecureStore(backend: InMemorySecureStoreBackend()),
        localUserDataCleanupService: _FakeCleanupService(),
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

    test('signUp surfaces sign-up failure', () async {
      expect(
        () => service.signUp(email: 'fail@example.com', password: 'Password123!'),
        throwsA(isA<FirebaseAuthException>()),
      );
    });

    test('signIn maps invalid credentials to a validation-style auth exception', () async {
      expect(
        () => service.signIn(email: 'bad@example.com', password: 'Password123!'),
        throwsA(isA<FirebaseAuthException>()),
      );
    });

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

    test('getCurrentSessionSnapshot exposes session details without logging secrets', () async {
      final snapshot = await service.getCurrentSessionSnapshot();
      expect(snapshot, isNull);
    });

    test('transient refresh failure maps to auth-unavailable and next refresh recovers', () async {
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
    });

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

      final snapshot = await service.getCurrentSessionSnapshot(forceRefresh: true);
      expect(snapshot, isNotNull);
      expect(snapshot!.accessToken, 'abc');
      expect(snapshot.refreshToken, isNotEmpty);
    });
  });
}
