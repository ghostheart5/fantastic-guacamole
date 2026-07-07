import 'dart:async';
import 'dart:convert';

import 'package:fantastic_guacamole/config/env.dart';
import 'package:fantastic_guacamole/data/models/auth_models.dart';
import 'package:fantastic_guacamole/data/network/secure_endpoint.dart' as secure_endpoint;
import 'package:fantastic_guacamole/data/services/contracts/auth_service_contract.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

class AuthService implements AuthServiceContract {
  AuthService({
    required sb.SupabaseClient supabaseClient,
    required this._store,
    http.Client? httpClient,
    String? accountDeleteEndpoint,
    String? oauthRedirectUrl,
  }) : _auth = supabaseClient,
       _httpClient = httpClient ?? _sharedHttpClient,
       _accountDeleteEndpoint = accountDeleteEndpoint ?? Env.accountDeleteEndpoint,
       _oauthRedirectUrl = oauthRedirectUrl ?? Env.oauthRedirectUrl;

  static final http.Client _sharedHttpClient = http.Client();

  final sb.SupabaseClient _auth;
  final SecureStore _store;
  final http.Client _httpClient;
  final String _accountDeleteEndpoint;
  final String _oauthRedirectUrl;
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
      return UserCredential(user: _mapUser(response.user));
    } on sb.AuthException catch (error) {
      throw _mapAuthException(error);
    } on Object {
      throw FirebaseAuthException(
        code: 'auth-unavailable',
        message: 'Authentication backend is unavailable.',
      );
    }
  }

  @override
  Future<UserCredential> signInWithGoogle() async {
    try {
      final String redirectTo = _oauthRedirectUrl.trim();
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
  Future<void> signOut() async {
    await _auth.auth.signOut();
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

      final http.Response response = await _httpClient
          .post(
            uri,
            headers: <String, String>{
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $accessToken',
            },
            body: jsonEncode(<String, String>{'userId': user.id, 'email': email}),
          )
          .timeout(const Duration(seconds: 20));

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
        await _store.deleteAll();
        await _auth.auth.signOut();
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
}
