import 'dart:async';
import 'dart:convert';

import 'package:fantastic_guacamole/config/env.dart';
import 'package:fantastic_guacamole/core/network/retry_executor.dart';
import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/data/models/auth_models.dart';
import 'package:fantastic_guacamole/data/network/secure_endpoint.dart' as secure_endpoint;
import 'package:fantastic_guacamole/data/services/local_user_data_cleanup_service.dart';
import 'package:fantastic_guacamole/data/services/contracts/auth_service_contract.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/data/storage/hive_service.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

class AuthService implements AuthServiceContract {
  AuthService({
    required sb.SupabaseClient supabaseClient,
    required SecureStore store,
    http.Client? httpClient,
    String? accountDeleteEndpoint,
    String? oauthGoogleRedirectUrl,
    String? oauthGitHubRedirectUrl,
    LocalUserDataCleanupService? localUserDataCleanupService,
  }) : _auth = supabaseClient,
       _store = store,
       _httpClient = httpClient ?? _sharedHttpClient,
       _accountDeleteEndpoint = accountDeleteEndpoint ?? Env.accountDeleteEndpoint,
       _oauthGoogleRedirectUrl = oauthGoogleRedirectUrl ?? Env.oauthRedirectUrl,
       _oauthGitHubRedirectUrl = oauthGitHubRedirectUrl ?? Env.githubOauthRedirectUrl,
       _localUserDataCleanupService =
           localUserDataCleanupService ??
           LocalUserDataCleanupService(
             preferences: const SharedPrefsStoreAdapter(),
             hive: const HiveStoreAdapter(),
             secureStore: store,
           );

  static final http.Client _sharedHttpClient = http.Client();

  final sb.SupabaseClient _auth;
  final SecureStore _store;
  final http.Client _httpClient;
  final String _accountDeleteEndpoint;
  final String _oauthGoogleRedirectUrl;
  final String _oauthGitHubRedirectUrl;
  final LocalUserDataCleanupService _localUserDataCleanupService;
  int _failedSignInAttempts = 0;
  DateTime? _signInBlockedUntil;

  @override
  Stream<User?> authStateChanges() {
    return _auth.auth.onAuthStateChange.map((sb.AuthState state) => _mapUser(state.session?.user));
  }

  @override
  User? get currentUser => _mapUser(_auth.auth.currentUser);

  @override
  Future<UserCredential> signIn({required String email, required String password}) async {
    final DateTime now = DateTime.now();
    final DateTime? blockedUntil = _signInBlockedUntil;
    if (blockedUntil != null && now.isBefore(blockedUntil)) {
      throw FirebaseAuthException(
        code: 'too-many-requests',
        message: 'Too many sign-in attempts. Please wait and try again.',
      );
    }
    try {
      final sb.AuthResponse response = await _auth.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final UserCredential credential = UserCredential(user: _mapUser(response.user));
      _failedSignInAttempts = 0;
      _signInBlockedUntil = null;
      return credential;
    } on sb.AuthException catch (error) {
      final FirebaseAuthException mapped = _mapAuthException(error);
      if (_isCredentialFailure(mapped.code)) {
        _failedSignInAttempts += 1;
        final int seconds = (2 << (_failedSignInAttempts > 5 ? 5 : _failedSignInAttempts)).clamp(
          2,
          60,
        );
        _signInBlockedUntil = now.add(Duration(seconds: seconds));
      }
      throw mapped;
    } on Object {
      throw FirebaseAuthException(
        code: 'auth-unavailable',
        message: 'Authentication backend is unavailable.',
      );
    }
  }

  @override
  Future<UserCredential> signUp({required String email, required String password}) async {
    try {
      final sb.AuthResponse response = await _auth.auth.signUp(email: email, password: password);
      await _seedProfileStateFromSignupEmail(email);
      return UserCredential(user: _mapUser(response.user));
    } on sb.AuthException catch (error) {
      Logger.errorCategory('Auth Errors', 'Supabase signUp failed', error);
      throw _mapAuthException(error);
    } on Object {
      throw FirebaseAuthException(
        code: 'auth-unavailable',
        message: 'Authentication backend is unavailable.',
      );
    }
  }

  Future<void> _seedProfileStateFromSignupEmail(String email) async {
    const String secureProfileStateKey = 'profile_state_v2';
    final String normalizedEmail = email.trim();
    final String localPart = normalizedEmail.contains('@')
        ? normalizedEmail.split('@').first.trim()
        : '';
    final String profileName = localPart.isEmpty ? 'Operator' : localPart;
    final DateTime now = DateTime.now();
    final Map<String, dynamic> payload = <String, dynamic>{
      'xp': 0,
      'level': 1,
      'streak': 0,
      'longestStreak': 0,
      'name': profileName,
      'soundEnabled': true,
      'lastActiveDate': null,
      'profileReady': true,
      'updatedAt': now.toIso8601String(),
    };
    await _store.writeString(secureProfileStateKey, jsonEncode(payload));
  }

  @override
  Future<UserCredential> signInWithGoogle() async {
    try {
      final String redirectTo = _oauthGoogleRedirectUrl.trim();
      await _auth.auth.signInWithOAuth(
        sb.OAuthProvider.google,
        redirectTo: redirectTo.isEmpty ? null : redirectTo,
      );
      return UserCredential(user: currentUser);
    } on sb.AuthException catch (error) {
      throw _mapAuthException(error);
    } on Object {
      throw FirebaseAuthException(
        code: 'auth-unavailable',
        message: 'Google sign-in is currently unavailable.',
      );
    }
  }

  @override
  Future<UserCredential> signInWithGitHub() async {
    try {
      final String redirectTo = _oauthGitHubRedirectUrl.trim();
      await _auth.auth.signInWithOAuth(
        sb.OAuthProvider.github,
        redirectTo: redirectTo.isEmpty ? null : redirectTo,
      );
      return UserCredential(user: currentUser);
    } on sb.AuthException catch (error) {
      throw _mapAuthException(error);
    } on Object {
      throw FirebaseAuthException(
        code: 'auth-unavailable',
        message: 'GitHub sign-in is currently unavailable.',
      );
    }
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.auth.resetPasswordForEmail(email);
    } on sb.AuthException catch (error) {
      throw _mapAuthException(error);
    } on Object {
      throw FirebaseAuthException(
        code: 'auth-unavailable',
        message: 'Password reset is currently unavailable.',
      );
    }
  }

  @override
  Future<void> updatePassword({required String newPassword}) async {
    final String trimmed = newPassword.trim();
    if (trimmed.isEmpty) {
      throw FirebaseAuthException(code: 'missing-password', message: 'New password is required.');
    }
    try {
      await _auth.auth.updateUser(sb.UserAttributes(password: trimmed));
    } on sb.AuthException catch (error) {
      throw _mapAuthException(error);
    } on Object {
      throw FirebaseAuthException(
        code: 'auth-unavailable',
        message: 'Password update is currently unavailable.',
      );
    }
  }

  @override
  Future<void> sendEmailVerification() async {
    final User? user = currentUser;
    final String email = user?.email?.trim() ?? '';
    if (email.isEmpty) {
      throw FirebaseAuthException(code: 'no-current-user', message: 'No signed-in user found.');
    }
    try {
      await _auth.auth.resend(type: sb.OtpType.signup, email: email);
    } on sb.AuthException catch (error) {
      throw _mapAuthException(error);
    } on Object {
      throw FirebaseAuthException(
        code: 'auth-unavailable',
        message: 'Email verification is currently unavailable.',
      );
    }
  }

  @override
  Future<User?> reloadCurrentUser() async {
    try {
      await _auth.auth.refreshSession();
      return currentUser;
    } on sb.AuthException catch (error) {
      throw _mapAuthException(error);
    } on Object {
      throw FirebaseAuthException(
        code: 'auth-unavailable',
        message: 'Unable to refresh the current session.',
      );
    }
  }

  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    try {
      if (forceRefresh) {
        await _auth.auth.refreshSession();
      }
      return _auth.auth.currentSession?.accessToken;
    } on sb.AuthException catch (error) {
      throw _mapAuthException(error);
    } on Object {
      throw FirebaseAuthException(
        code: 'auth-unavailable',
        message: 'Unable to retrieve the authentication token.',
      );
    }
  }

  @override
  Future<AuthSessionSnapshot?> getCurrentSessionSnapshot({
    bool forceRefresh = false,
  }) async {
    try {
      if (forceRefresh) {
        await _auth.auth.refreshSession();
      }
      final sb.Session? session = _auth.auth.currentSession;
      if (session == null) {
        return null;
      }
      final DateTime issuedAt = DateTime.now();
      return AuthSessionSnapshot(
        accessToken: session.accessToken,
        refreshToken: session.refreshToken ?? '',
        expiresAt: _sessionExpiry(session) ?? issuedAt,
        issuedAt: issuedAt,
      );
    } on sb.AuthException catch (error) {
      throw _mapAuthException(error);
    } on Object {
      throw FirebaseAuthException(
        code: 'auth-unavailable',
        message: 'Unable to retrieve the current authentication session.',
      );
    }
  }

  @override
  Future<void> signOut() async {
    final String? userId = _auth.auth.currentUser?.id;
    await _auth.auth.signOut();
    await _localUserDataCleanupService.clear(userId: userId);
  }

  @override
  Future<void> deleteCurrentAccount({required String password}) async {
    final User? user = currentUser;
    if (user == null) {
      throw FirebaseAuthException(code: 'no-current-user', message: 'No signed-in user found.');
    }
    final String email = user.email?.trim() ?? '';
    if (email.isEmpty) {
      throw FirebaseAuthException(
        code: 'missing-email',
        message: 'Current account email is unavailable.',
      );
    }
    if (password.trim().isEmpty) {
      throw FirebaseAuthException(
        code: 'missing-password',
        message: 'Password is required to delete this account.',
      );
    }

    final String endpoint = _accountDeleteEndpoint.trim();
    if (endpoint.isEmpty) {
      throw FirebaseAuthException(
        code: 'operation-not-supported',
        message:
            'Account deletion is unavailable because CHRONOSPARK_ACCOUNT_DELETE_ENDPOINT is not configured.',
      );
    }

    final Uri? uri = parseSecureHttpsEndpoint(endpoint);
    if (uri == null) {
      throw FirebaseAuthException(
        code: 'operation-not-supported',
        message: 'Account deletion endpoint must be a valid HTTPS URL.',
      );
    }

    bool deleted = false;

    try {
      await _auth.auth.signInWithPassword(email: email, password: password);

      final String? accessToken = _auth.auth.currentSession?.accessToken;
      if (accessToken == null || accessToken.trim().isEmpty) {
        throw FirebaseAuthException(
          code: 'auth-unavailable',
          message: 'Session token missing after re-authentication.',
        );
      }

      final http.Response response = await runWithRetry<http.Response>(
        maxAttempts: 3,
        action: () async {
          final http.Response next = await _httpClient
              .post(
                uri,
                headers: <String, String>{
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer $accessToken',
                },
                body: jsonEncode(<String, String>{
                  'userId': user.id,
                  'email': email,
                }),
              )
              .timeout(const Duration(seconds: 20));
          if (next.statusCode == 408 ||
              next.statusCode == 429 ||
              next.statusCode >= 500) {
            throw http.ClientException(
              'Transient account deletion endpoint failure: ${next.statusCode}',
              uri,
            );
          }
          return next;
        },
        retryIf: (Object error) {
          return error is TimeoutException || error is http.ClientException;
        },
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw FirebaseAuthException(
          code: 'operation-failed',
          message: deletionFailureMessage(
            statusCode: response.statusCode,
            responseBody: response.body,
          ),
        );
      }

      deleted = true;
    } on sb.AuthException catch (error) {
      throw _mapAuthException(error);
    } on TimeoutException {
      throw FirebaseAuthException(
        code: 'network-request-failed',
        message: 'Account deletion timed out. Check your connection and retry.',
      );
    } finally {
      if (deleted) {
        await _localUserDataCleanupService.clear(userId: user.id);
        try {
          await _auth.auth.signOut();
        } on Object catch (error) {
          Logger.warn('Final sign-out after account deletion failed: $error');
        }
      }
    }
  }

  static Uri? parseSecureHttpsEndpoint(String endpoint) {
    return secure_endpoint.parseSecureHttpsEndpoint(endpoint);
  }

  static String deletionFailureMessage({required int statusCode, required String responseBody}) {
    return 'Account deletion failed ($statusCode). Please try again later.';
  }

  bool _isCredentialFailure(String code) {
    return code == 'wrong-password' ||
        code == 'invalid-credential' ||
        code == 'user-not-found' ||
        code == 'invalid-email';
  }

  User? _mapUser(sb.User? supabaseUser) {
    if (supabaseUser == null) {
      return null;
    }
    final String? email = supabaseUser.email;
    final Map<String, dynamic> metadata = supabaseUser.userMetadata ?? const <String, dynamic>{};
    final String? fullName = metadata['full_name']?.toString().trim();
    final String? name = metadata['name']?.toString().trim();
    final bool verified = supabaseUser.emailConfirmedAt != null;
    return User(
      id: supabaseUser.id,
      email: email,
      displayName: (fullName?.isNotEmpty ?? false)
          ? fullName
          : ((name?.isNotEmpty ?? false) ? name : null),
      emailVerified: verified,
    );
  }

  FirebaseAuthException _mapAuthException(sb.AuthException error) {
    final String rawCode = (error.statusCode ?? '').toString().toLowerCase();
    final String message = error.message.toLowerCase();
    if (message.contains('database error saving new user') ||
        (message.contains('unexpected') &&
            message.contains('failure') &&
            message.contains('new user'))) {
      return FirebaseAuthException(
        code: 'operation-failed',
        message: 'Sign-up is temporarily unavailable. Please retry shortly.',
      );
    }
    if (message.contains('invalid login credentials')) {
      return FirebaseAuthException(code: 'wrong-password', message: error.message);
    }
    if (message.contains('email not confirmed')) {
      return FirebaseAuthException(code: 'user-not-verified', message: error.message);
    }
    if (message.contains('already registered') || message.contains('already been registered')) {
      return FirebaseAuthException(code: 'email-already-in-use', message: error.message);
    }
    if (rawCode == '429') {
      return FirebaseAuthException(code: 'too-many-requests', message: error.message);
    }
    if (rawCode == '400' && message.contains('email')) {
      return FirebaseAuthException(code: 'invalid-email', message: error.message);
    }
    if (rawCode == '422' && message.contains('password')) {
      return FirebaseAuthException(code: 'weak-password', message: error.message);
    }
    return FirebaseAuthException(code: 'auth-unavailable', message: error.message);
  }

  DateTime? _sessionExpiry(sb.Session session) {
    final dynamic raw = session.expiresAt;
    if (raw is int) {
      return DateTime.fromMillisecondsSinceEpoch(raw * 1000, isUtc: true)
          .toLocal();
    }
    if (raw is String) {
      return DateTime.tryParse(raw);
    }
    return null;
  }
}
