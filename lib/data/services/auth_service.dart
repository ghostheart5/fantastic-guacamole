import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:fantastic_guacamole/config/env.dart';
import 'package:fantastic_guacamole/core/network/retry_executor.dart';
import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/data/models/auth_models.dart';
import 'package:fantastic_guacamole/data/network/secure_endpoint.dart'
    as secure_endpoint;
import 'package:fantastic_guacamole/data/repositories/firebase_supabase_bridge_repository.dart';
import 'package:fantastic_guacamole/data/services/local_user_data_cleanup_service.dart';
import 'package:fantastic_guacamole/data/services/contracts/auth_service_contract.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/data/storage/hive_service.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

class AuthService implements AuthServiceContract {
  static const String _pendingAccountDeletionKey =
      'chronospark.pending_account_deletion.v1';
  AuthService({
    required sb.SupabaseClient supabaseClient,
    required SecureStore store,
    http.Client? httpClient,
    String? accountDeleteEndpoint,
    String? supabaseUrl,
    String? oauthGoogleRedirectUrl,
    String? passwordRecoveryRedirectUrl,
    LocalUserDataCleanupService? localUserDataCleanupService,
    Duration accountDeletionRecentSignInWindow =
        defaultAccountDeletionRecentSignInWindow,
    DateTime Function()? clock,
  }) : _auth = supabaseClient,
       _store = store,
       _httpClient = httpClient ?? _sharedHttpClient,
       _accountDeleteEndpoint =
           accountDeleteEndpoint ?? Env.accountDeleteEndpoint,
       _supabaseUrl = supabaseUrl ?? Env.supabaseUrl,
       _oauthGoogleRedirectUrl = oauthGoogleRedirectUrl ?? Env.oauthRedirectUrl,
       _passwordRecoveryRedirectUrl =
           passwordRecoveryRedirectUrl ?? Env.passwordRecoveryRedirectUrl,
       _accountDeletionRecentSignInWindow = accountDeletionRecentSignInWindow,
       _clock = clock ?? _utcNow,
       _localUserDataCleanupService =
           localUserDataCleanupService ??
           LocalUserDataCleanupService(
             preferences: const SharedPrefsStoreAdapter(),
             hive: const HiveStoreAdapter(),
             secureStore: store,
             disassociateFirebaseMessagingToken: () =>
                 FirebaseSupabaseBridgeRepository(
                   store: store,
                 ).disassociateFirebaseMessagingToken(supabaseClient),
           ),
       assert(accountDeletionRecentSignInWindow > Duration.zero);

  static final http.Client _sharedHttpClient = http.Client();

  final sb.SupabaseClient _auth;
  final SecureStore _store;
  final http.Client _httpClient;
  final String _accountDeleteEndpoint;
  final String _supabaseUrl;
  final String _oauthGoogleRedirectUrl;
  final String _passwordRecoveryRedirectUrl;
  final Duration _accountDeletionRecentSignInWindow;
  final DateTime Function() _clock;
  final LocalUserDataCleanupService _localUserDataCleanupService;
  int _failedSignInAttempts = 0;
  DateTime? _signInBlockedUntil;
  int _profileHydrationGeneration = 0;
  Future<void> _profileHydrationTail = Future<void>.value();
  String? _confirmedAccountDeletionUserId;

  @override
  Stream<User?> authStateChanges() {
    return _auth.auth.onAuthStateChange.map((sb.AuthState state) {
      _scheduleProfileHydration(state.session?.user);
      return _mapUser(state.session?.user);
    });
  }

  @override
  User? get currentUser => _mapUser(_auth.auth.currentUser);

  @override
  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    final DateTime now = DateTime.now();
    final DateTime? blockedUntil = _signInBlockedUntil;
    if (blockedUntil != null && now.isBefore(blockedUntil)) {
      throw FirebaseAuthException(
        code: 'too-many-requests',
        message: 'Too many sign-in attempts. Please wait and try again.',
      );
    }
    try {
      await _prepareForAccountReplacement(
        intendedEmail: email,
        alwaysWhenAuthenticated: false,
      );
      final sb.AuthResponse response = await _auth.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final UserCredential credential = UserCredential(
        user: _mapUser(response.user),
      );
      _failedSignInAttempts = 0;
      _signInBlockedUntil = null;
      return credential;
    } on sb.AuthException catch (error) {
      final FirebaseAuthException mapped = _mapAuthException(error);
      if (_isCredentialFailure(mapped.code)) {
        _failedSignInAttempts += 1;
        final int seconds =
            (2 << (_failedSignInAttempts > 5 ? 5 : _failedSignInAttempts))
                .clamp(2, 60);
        _signInBlockedUntil = now.add(Duration(seconds: seconds));
      }
      throw mapped;
    } on FirebaseAuthException {
      rethrow;
    } on Object {
      throw FirebaseAuthException(
        code: 'auth-unavailable',
        message: 'Authentication backend is unavailable.',
      );
    }
  }

  @override
  Future<UserCredential> signUp({
    required String email,
    required String password,
  }) async {
    try {
      await _prepareForAccountReplacement(
        intendedEmail: email,
        alwaysWhenAuthenticated: true,
      );
      final String emailRedirectTo = _authRedirectUrl;
      final sb.AuthResponse response = await _auth.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: emailRedirectTo.isEmpty ? null : emailRedirectTo,
      );
      if (response.session != null) {
        _scheduleProfileHydration(response.user);
      }
      return UserCredential(user: _mapUser(response.user));
    } on sb.AuthException catch (error) {
      Logger.errorCategory('Auth Errors', 'Supabase signUp failed', error);
      throw _mapAuthException(error);
    } on FirebaseAuthException {
      rethrow;
    } on Object {
      throw FirebaseAuthException(
        code: 'auth-unavailable',
        message: 'Authentication backend is unavailable.',
      );
    }
  }

  String get _authRedirectUrl => _oauthGoogleRedirectUrl.trim();

  void _scheduleProfileHydration(sb.User? user) {
    _queueProfileHydration(user);
  }

  Future<void> _queueProfileHydration(sb.User? user) {
    final int generation = ++_profileHydrationGeneration;
    final String? expectedUserId = user?.id.trim();
    if (expectedUserId == null || expectedUserId.isEmpty) {
      return Future<void>.value();
    }
    final Future<void> operation = _profileHydrationTail.then(
      (_) => _hydrateProfileStateForVerifiedUser(
        user,
        generation: generation,
        expectedUserId: expectedUserId,
      ),
    );
    _profileHydrationTail = operation.catchError((
      Object error,
      StackTrace stackTrace,
    ) {
      Logger.errorCategory(
        'Auth Profile',
        'Deferred authenticated profile initialization failed.',
        error,
        stackTrace,
      );
    });
    return operation;
  }

  Future<void> cancelAndDrainProfileHydration() async {
    _profileHydrationGeneration++;
    await _profileHydrationTail.catchError((Object _) {});
  }

  Future<void> awaitCurrentUserProfileHydration() {
    return _queueProfileHydration(_auth.auth.currentUser);
  }

  Future<void> _hydrateProfileStateForVerifiedUser(
    sb.User? user, {
    required int generation,
    required String expectedUserId,
  }) async {
    if (user?.emailConfirmedAt == null) {
      return;
    }

    if (!_isCurrentProfileHydration(generation, expectedUserId)) {
      return;
    }
    final String secureProfileStateKey =
        'profile_state_v2.${_safeStorageScope(expectedUserId)}';
    final String? existing = await _store.readString(secureProfileStateKey);
    if (!_isCurrentProfileHydration(generation, expectedUserId)) {
      return;
    }
    if (existing != null && existing.trim().isNotEmpty) {
      return;
    }

    final String normalizedEmail = user?.email?.trim() ?? '';
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
    if (!_isCurrentProfileHydration(generation, expectedUserId)) {
      return;
    }
    await _store.writeString(secureProfileStateKey, jsonEncode(payload));
  }

  bool _isCurrentProfileHydration(int generation, String expectedUserId) {
    return generation == _profileHydrationGeneration &&
        _auth.auth.currentUser?.id.trim() == expectedUserId;
  }

  Future<void> _prepareForAccountReplacement({
    String? intendedEmail,
    required bool alwaysWhenAuthenticated,
  }) async {
    final sb.User? current = _auth.auth.currentUser;
    if (current == null) {
      return;
    }
    final String currentEmail = current.email?.trim().toLowerCase() ?? '';
    final String nextEmail = intendedEmail?.trim().toLowerCase() ?? '';
    if (!alwaysWhenAuthenticated &&
        currentEmail.isNotEmpty &&
        currentEmail == nextEmail) {
      return;
    }
    throw FirebaseAuthException(
      code: 'account-switch-requires-local-clear',
      message:
          'Sign out before using another account. ChronoSpark preserves local-first data for the current account and cannot replace it implicitly.',
    );
  }

  bool consumeConfirmedAccountDeletion(String previousUserId) {
    if (_confirmedAccountDeletionUserId != previousUserId) {
      return false;
    }
    _confirmedAccountDeletionUserId = null;
    return true;
  }

  @override
  Future<UserCredential> signInWithGoogle() async {
    try {
      await _prepareForAccountReplacement(alwaysWhenAuthenticated: true);
      final String redirectTo = _oauthGoogleRedirectUrl.trim();
      await _auth.auth.signInWithOAuth(
        sb.OAuthProvider.google,
        redirectTo: redirectTo.isEmpty ? null : redirectTo,
      );
      return UserCredential(user: currentUser);
    } on sb.AuthException catch (error) {
      throw _mapAuthException(error);
    } on FirebaseAuthException {
      rethrow;
    } on Object {
      throw FirebaseAuthException(
        code: 'auth-unavailable',
        message: 'Google sign-in is currently unavailable.',
      );
    }
  }

  @override
  Future<void> sendPhoneOtp(String phone) async {
    final String cleanPhone = phone.trim();

    if (cleanPhone.isEmpty) {
      throw FirebaseAuthException(
        code: 'missing-phone',
        message: 'Phone number is required.',
      );
    }

    try {
      await _prepareForAccountReplacement(alwaysWhenAuthenticated: true);
      await _auth.auth.signInWithOtp(
        phone: cleanPhone,
        channel: sb.OtpChannel.sms,
      );
    } on sb.AuthException catch (error) {
      throw _mapAuthException(error);
    } on FirebaseAuthException {
      rethrow;
    } on Object {
      throw FirebaseAuthException(
        code: 'auth-unavailable',
        message: 'Phone verification is currently unavailable.',
      );
    }
  }

  @override
  Future<UserCredential> verifyPhoneOtp({
    required String phone,
    required String token,
  }) async {
    final String cleanPhone = phone.trim();
    final String cleanToken = token.trim();

    if (cleanPhone.isEmpty) {
      throw FirebaseAuthException(
        code: 'missing-phone',
        message: 'Phone number is required.',
      );
    }

    if (cleanToken.isEmpty) {
      throw FirebaseAuthException(
        code: 'missing-verification-code',
        message: 'Verification code is required.',
      );
    }

    try {
      await _prepareForAccountReplacement(alwaysWhenAuthenticated: true);
      final sb.AuthResponse response = await _auth.auth.verifyOTP(
        phone: cleanPhone,
        token: cleanToken,
        type: sb.OtpType.sms,
      );

      return UserCredential(user: _mapUser(response.user));
    } on sb.AuthException catch (error) {
      throw _mapAuthException(error);
    } on FirebaseAuthException {
      rethrow;
    } on Object {
      throw FirebaseAuthException(
        code: 'auth-unavailable',
        message: 'Phone verification is currently unavailable.',
      );
    }
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    try {
      final String redirectTo = _passwordRecoveryRedirectUrl.trim();
      await _auth.auth.resetPasswordForEmail(
        email,
        redirectTo: redirectTo.isEmpty ? null : redirectTo,
      );
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
      throw FirebaseAuthException(
        code: 'missing-password',
        message: 'New password is required.',
      );
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
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No signed-in user found.',
      );
    }
    try {
      final String redirectTo = _authRedirectUrl;
      await _auth.auth.resend(
        type: sb.OtpType.signup,
        email: email,
        emailRedirectTo: redirectTo.isEmpty ? null : redirectTo,
      );
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
      if (await _recoverCompletedAccountDeletion()) {
        return null;
      }
      await _auth.auth.refreshSession();
      final sb.User? user = _auth.auth.currentUser;
      _scheduleProfileHydration(user);
      return _mapUser(user);
    } on sb.AuthException catch (error) {
      throw _mapAuthException(error);
    } on Object {
      throw FirebaseAuthException(
        code: 'auth-unavailable',
        message: 'Unable to refresh the current session.',
      );
    }
  }

  Future<bool> _recoverCompletedAccountDeletion() async {
    final String? pendingRaw = await _store.readString(
      _pendingAccountDeletionKey,
    );
    if (pendingRaw == null || pendingRaw.isEmpty) return false;
    final String endpoint = _accountDeleteEndpoint.trim();
    if (!Env.resolveIsTrustedEdgeFunctionEndpoint(
      endpoint: endpoint,
      supabaseUrl: _supabaseUrl,
      functionName: 'account-delete',
    )) {
      return false;
    }

    try {
      final Object? decoded = jsonDecode(pendingRaw);
      if (decoded is! Map) return false;
      final String userId = decoded['userId']?.toString() ?? '';
      final String requestId = decoded['requestId']?.toString() ?? '';
      final String receipt = decoded['receipt']?.toString() ?? '';
      if (userId.isEmpty ||
          !RegExp(r'^[0-9a-f]{64}$').hasMatch(requestId) ||
          !RegExp(r'^[A-Za-z0-9_-]{32,256}$').hasMatch(receipt)) {
        return false;
      }
      final http.Response response = await _httpClient
          .post(
            Uri.parse(endpoint),
            headers: const <String, String>{'Content-Type': 'application/json'},
            body: jsonEncode(<String, String>{
              'action': 'status',
              'requestId': requestId,
              'receipt': receipt,
            }),
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return false;
      final Object? result = jsonDecode(response.body);
      if (result is! Map || result['completed'] != true) return false;

      _confirmedAccountDeletionUserId = userId;
      FirebaseSupabaseBridgeRepository.suspendSessionWrites();
      await _localUserDataCleanupService.clearLocalData(userId: userId);
      try {
        await _auth.auth.signOut();
      } on Object {
        Logger.warn(
          'Recovered cloud account deletion, but local auth sign-out failed.',
        );
      }
      return true;
    } on FormatException {
      return false;
    } on TimeoutException {
      return false;
    } on http.ClientException {
      return false;
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
    FirebaseSupabaseBridgeRepository.suspendSessionWrites();
    Object? cleanupError;
    try {
      await _localUserDataCleanupService.prepareForSignOut();
    } on Object catch (error) {
      cleanupError = error;
    }

    Object? signOutError;
    try {
      await _auth.auth.signOut();
    } on Object catch (error) {
      signOutError = error;
      Logger.warn('Remote sign-out failed after local account cleanup.');
    }
    if (signOutError != null && _auth.auth.currentUser != null) {
      FirebaseSupabaseBridgeRepository.resumeSessionWrites();
    }
    if (cleanupError != null) {
      throw FirebaseAuthException(
        code: 'local-cleanup-failed',
        message:
            'Sign-out could not complete notification and messaging cleanup. Retry before another person uses this device.',
      );
    }
    if (signOutError is sb.AuthException) {
      throw _mapAuthException(signOutError);
    }
    if (signOutError != null) {
      throw FirebaseAuthException(
        code: 'auth-unavailable',
        message: 'Remote sign-out could not be completed.',
      );
    }
  }

  @override
  Future<void> deleteCurrentAccount({required String password}) async {
    final sb.User? supabaseUser = _auth.auth.currentUser;
    final User? user = _mapUser(supabaseUser);
    if (user == null || supabaseUser == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No signed-in user found.',
      );
    }
    final String email = user.email?.trim() ?? '';

    final String endpoint = _accountDeleteEndpoint.trim();
    if (endpoint.isEmpty) {
      throw FirebaseAuthException(
        code: 'operation-not-supported',
        message:
            'Account deletion is unavailable because CHRONOSPARK_ACCOUNT_DELETE_ENDPOINT is not configured.',
      );
    }

    if (!Env.resolveIsTrustedEdgeFunctionEndpoint(
      endpoint: endpoint,
      supabaseUrl: _supabaseUrl,
      functionName: 'account-delete',
    )) {
      throw FirebaseAuthException(
        code: 'operation-not-supported',
        message:
            'Account deletion endpoint must be the configured Supabase account-delete function.',
      );
    }
    final Uri uri = Uri.parse(endpoint);

    try {
      await _reauthenticateForAccountDeletion(
        user: supabaseUser,
        password: password,
      );

      await _localUserDataCleanupService.prepareForAccountDeletion();

      final String? accessToken = _auth.auth.currentSession?.accessToken;
      if (accessToken == null || accessToken.trim().isEmpty) {
        throw FirebaseAuthException(
          code: 'auth-unavailable',
          message: 'Session token missing after re-authentication.',
        );
      }

      Map<String, String>? deletionRequest;
      final String? pendingRaw = await _store.readString(
        _pendingAccountDeletionKey,
      );
      if (pendingRaw != null) {
        try {
          final Object? decoded = jsonDecode(pendingRaw);
          if (decoded is Map && decoded['userId'] == user.id) {
            final String pendingReceipt = decoded['receipt']?.toString() ?? '';
            final String pendingRequestId =
                decoded['requestId']?.toString() ?? '';
            if (RegExp(r'^[A-Za-z0-9_-]{32,256}$').hasMatch(pendingReceipt) &&
                RegExp(r'^[0-9a-f]{64}$').hasMatch(pendingRequestId)) {
              deletionRequest = <String, String>{
                'action': 'delete',
                'requestId': pendingRequestId,
                'receipt': pendingReceipt,
                'userId': user.id,
                if (email.isNotEmpty) 'email': email,
              };
            }
          }
        } on FormatException {
          await _store.delete(_pendingAccountDeletionKey);
        }
      }
      if (deletionRequest == null) {
        final List<int> receiptBytes = List<int>.generate(
          32,
          (_) => Random.secure().nextInt(256),
          growable: false,
        );
        final String receipt = base64UrlEncode(
          receiptBytes,
        ).replaceAll('=', '');
        final String requestId = sha256
            .convert(utf8.encode(receipt))
            .toString();
        deletionRequest = <String, String>{
          'action': 'delete',
          'requestId': requestId,
          'receipt': receipt,
          'userId': user.id,
          if (email.isNotEmpty) 'email': email,
        };
        await _store.writeString(
          _pendingAccountDeletionKey,
          jsonEncode(deletionRequest),
        );
      }
      final String receipt = deletionRequest['receipt']!;
      final String requestId = deletionRequest['requestId']!;

      http.Response response = await runWithRetry<http.Response>(
        maxAttempts: 3,
        action: () async {
          http.Response next = await _httpClient
              .post(
                uri,
                headers: <String, String>{
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer $accessToken',
                },
                body: jsonEncode(deletionRequest),
              )
              .timeout(const Duration(seconds: 20));
          if (next.statusCode == 401) {
            next = await _httpClient
                .post(
                  uri,
                  headers: const <String, String>{
                    'Content-Type': 'application/json',
                  },
                  body: jsonEncode(<String, String>{
                    'action': 'status',
                    'requestId': requestId,
                    'receipt': receipt,
                  }),
                )
                .timeout(const Duration(seconds: 20));
          }
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

      for (
        int attempt = 0;
        response.statusCode == 202 && attempt < 5;
        attempt++
      ) {
        await Future<void>.delayed(Duration(seconds: attempt + 1));
        response = await _httpClient
            .post(
              uri,
              headers: const <String, String>{
                'Content-Type': 'application/json',
              },
              body: jsonEncode(<String, String>{
                'action': 'status',
                'requestId': requestId,
                'receipt': receipt,
              }),
            )
            .timeout(const Duration(seconds: 20));
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (response.statusCode == 428) {
          throw FirebaseAuthException(
            code: 'recent-sign-in-required',
            message:
                'For security, sign out and sign back in with your account provider, then retry deletion within ${_accountDeletionRecentSignInWindow.inMinutes} minutes.',
          );
        }
        throw FirebaseAuthException(
          code: 'operation-failed',
          message: deletionFailureMessage(
            statusCode: response.statusCode,
            responseBody: response.body,
          ),
        );
      }
      final Object? deletionResult = jsonDecode(response.body);
      if (response.statusCode == 202 ||
          deletionResult is! Map ||
          deletionResult['completed'] != true) {
        throw FirebaseAuthException(
          code: 'operation-pending',
          message:
              'Account deletion is still being finalized. Keep this device online and retry shortly.',
        );
      }
    } on sb.AuthException catch (error) {
      throw _mapAuthException(error);
    } on TimeoutException {
      throw FirebaseAuthException(
        code: 'network-request-failed',
        message: 'Account deletion timed out. Check your connection and retry.',
      );
    } on http.ClientException {
      throw FirebaseAuthException(
        code: 'network-request-failed',
        message: 'Account deletion could not reach the server. Retry online.',
      );
    }

    _confirmedAccountDeletionUserId = user.id;
    Object? localCleanupError;
    FirebaseSupabaseBridgeRepository.suspendSessionWrites();
    try {
      await _localUserDataCleanupService.clearLocalData(userId: user.id);
    } on Object catch (error) {
      localCleanupError = error;
    }
    Object? finalSignOutError;
    try {
      await _auth.auth.signOut();
    } on Object catch (error) {
      finalSignOutError = error;
      Logger.warn('Final local sign-out after account deletion failed.');
    }
    if (localCleanupError != null) {
      throw FirebaseAuthException(
        code: 'local-cleanup-failed',
        message:
            'Your cloud account was deleted, but this device could not finish clearing private data. Clear ChronoSpark app storage before another person uses it.',
      );
    }
    if (finalSignOutError != null) {
      throw FirebaseAuthException(
        code: 'local-cleanup-failed',
        message:
            'Your cloud account was deleted, but this device could not clear its local authentication session. Clear ChronoSpark app storage before another person uses it.',
      );
    }
  }

  static Uri? parseSecureHttpsEndpoint(String endpoint) {
    return secure_endpoint.parseSecureHttpsEndpoint(endpoint);
  }

  static String deletionFailureMessage({
    required int statusCode,
    required String responseBody,
  }) {
    return 'Account deletion failed ($statusCode). Please try again later.';
  }

  Future<void> _reauthenticateForAccountDeletion({
    required sb.User user,
    required String password,
  }) async {
    final User mappedUser = _mapUser(user)!;
    switch (mappedUser.accountDeletionReauthenticationMethod) {
      case AccountDeletionReauthenticationMethod.password:
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
        final sb.AuthResponse response = await _auth.auth.signInWithPassword(
          email: email,
          password: password,
        );
        if (response.user?.id != user.id) {
          throw FirebaseAuthException(
            code: 'account-mismatch',
            message:
                'Reauthentication returned a different account. Deletion was stopped.',
          );
        }
        return;
      case AccountDeletionReauthenticationMethod.recentGoogleSignIn:
      case AccountDeletionReauthenticationMethod.recentPhoneSignIn:
        _requireRecentProviderSignIn(mappedUser.lastSignInAt);
        return;
      case AccountDeletionReauthenticationMethod.unsupported:
        throw FirebaseAuthException(
          code: 'operation-not-supported',
          message:
              'This account provider cannot be reauthenticated safely for deletion. Contact support without sharing credentials.',
        );
    }
  }

  void _requireRecentProviderSignIn(DateTime? lastSignInAt) {
    if (!isAccountDeletionSignInRecent(
      lastSignInAt,
      now: _clock(),
      recentSignInWindow: _accountDeletionRecentSignInWindow,
    )) {
      throw FirebaseAuthException(
        code: 'recent-sign-in-required',
        message:
            'For security, sign out and sign back in with your account provider, then retry deletion within ${_accountDeletionRecentSignInWindow.inMinutes} minutes.',
      );
    }
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
    final Map<String, dynamic> metadata =
        supabaseUser.userMetadata ?? const <String, dynamic>{};
    final String? primaryProvider = supabaseUser.appMetadata['provider']
        ?.toString()
        .trim();
    final Object? rawProviders = supabaseUser.appMetadata['providers'];
    final Iterable<dynamic> metadataProviders = rawProviders is List<dynamic>
        ? rawProviders
        : const <dynamic>[];
    final Set<String> providers = <String>{
      if (primaryProvider != null && primaryProvider.isNotEmpty)
        primaryProvider,
      ...metadataProviders.map(
        (dynamic provider) => provider.toString().trim(),
      ),
      ...?supabaseUser.identities?.map(
        (sb.UserIdentity identity) => identity.provider.trim(),
      ),
    }..removeWhere((String provider) => provider.isEmpty);
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
      authenticationProvider: primaryProvider,
      authenticationProviders: List<String>.unmodifiable(providers),
      lastSignInAt: DateTime.tryParse(supabaseUser.lastSignInAt ?? '')?.toUtc(),
    );
  }

  static DateTime _utcNow() => DateTime.now().toUtc();

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
      return FirebaseAuthException(
        code: 'wrong-password',
        message: error.message,
      );
    }
    if (message.contains('email not confirmed')) {
      return FirebaseAuthException(
        code: 'user-not-verified',
        message: error.message,
      );
    }
    if (message.contains('already registered') ||
        message.contains('already been registered')) {
      return FirebaseAuthException(
        code: 'email-already-in-use',
        message: error.message,
      );
    }
    if (rawCode == '429') {
      return FirebaseAuthException(
        code: 'too-many-requests',
        message: error.message,
      );
    }
    if (rawCode == '400' && message.contains('email')) {
      return FirebaseAuthException(
        code: 'invalid-email',
        message: error.message,
      );
    }
    if (rawCode == '422' && message.contains('password')) {
      return FirebaseAuthException(
        code: 'weak-password',
        message: error.message,
      );
    }
    return FirebaseAuthException(
      code: 'auth-unavailable',
      message: error.message,
    );
  }

  DateTime? _sessionExpiry(sb.Session session) {
    final dynamic raw = session.expiresAt;
    if (raw is int) {
      return DateTime.fromMillisecondsSinceEpoch(
        raw * 1000,
        isUtc: true,
      ).toLocal();
    }
    if (raw is String) {
      return DateTime.tryParse(raw);
    }
    return null;
  }
}

String _safeStorageScope(String value) {
  final String normalized = value.trim().replaceAll(
    RegExp('[^a-zA-Z0-9._-]'),
    '_',
  );
  return normalized.isEmpty ? 'signed_out' : normalized;
}
