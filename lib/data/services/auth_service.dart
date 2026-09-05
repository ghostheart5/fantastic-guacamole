import 'dart:async';
import 'dart:convert';

import 'package:fantastic_guacamole/config/env.dart';
import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/data/models/auth_models.dart';
import 'package:fantastic_guacamole/data/network/secure_endpoint.dart'
    as secure_endpoint;
import 'package:fantastic_guacamole/data/services/contracts/auth_service_contract.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

class AuthService implements AuthServiceContract {
  AuthService({
    required sb.SupabaseClient supabaseClient,
    required this.store,
    http.Client? httpClient,
    String? accountDeleteEndpoint,
    String? oauthGoogleRedirectUrl,
    String? oauthGitHubRedirectUrl,
    Future<void> Function(String accountId)? onBeforeSignedOut,
    Future<void> Function()? onSignedOut,
    Future<void> Function(String accountId)? onAccountDeleted,
    Future<void> Function()? onDevicePushTokenRevoked,
  }) : _auth = supabaseClient,
       _httpClient = httpClient ?? _sharedHttpClient,
       _accountDeleteEndpoint =
           accountDeleteEndpoint ?? Env.accountDeleteEndpoint,
       _oauthGoogleRedirectUrl = oauthGoogleRedirectUrl ?? Env.oauthRedirectUrl,
       _oauthGitHubRedirectUrl =
           oauthGitHubRedirectUrl ?? Env.githubOauthRedirectUrl,
       _beforeSignedOutCallback = onBeforeSignedOut,
       _signedOutCallback = onSignedOut,
       _accountDeletedCallback = onAccountDeleted,
       _devicePushTokenRevokedCallback = onDevicePushTokenRevoked;

  static final http.Client _sharedHttpClient = http.Client();
  static const String _pendingDeletionCapabilityKey =
      'account_deletion_pending_capability_v1';
  static final RegExp _opaqueCapabilityPattern = RegExp(r'^[0-9a-f]{64}$');
  static final RegExp _deletionStatePattern = RegExp(r'^[a-z][a-z0-9_]{0,63}$');

  final sb.SupabaseClient _auth;
  final SecureStore store;
  final http.Client _httpClient;
  final String _accountDeleteEndpoint;
  final String _oauthGoogleRedirectUrl;
  final String _oauthGitHubRedirectUrl;
  final Future<void> Function(String accountId)? _beforeSignedOutCallback;
  final Future<void> Function()? _signedOutCallback;
  final Future<void> Function(String accountId)? _accountDeletedCallback;
  final Future<void> Function()? _devicePushTokenRevokedCallback;
  int _failedSignInAttempts = 0;
  DateTime? _signInBlockedUntil;

  @override
  Stream<User?> authStateChanges() {
    return _auth.auth.onAuthStateChange.map(
      (sb.AuthState state) => _mapUser(state.session?.user),
    );
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
      final sb.AuthResponse response = await _auth.auth.signUp(
        email: email,
        password: password,
      );
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

  @override
  Future<UserCredential> signInWithGoogle() async {
    try {
      final String redirectTo = _oauthGoogleRedirectUrl.trim();
      final bool launched = await _auth.auth.signInWithOAuth(
        sb.OAuthProvider.google,
        redirectTo: redirectTo.isEmpty ? null : redirectTo,
      );
      if (!launched) {
        Logger.error('Google OAuth browser launch returned false.');
        throw FirebaseAuthException(
          code: 'auth-unavailable',
          message: 'Google sign-in browser could not be opened.',
        );
      }
      return UserCredential(user: currentUser);
    } on sb.AuthException catch (error) {
      Logger.error(
        'Google OAuth provider rejected the request '
        '(status ${error.statusCode ?? 'unknown'}).',
      );
      throw _mapAuthException(error);
    } on FirebaseAuthException {
      rethrow;
    } on Object catch (error) {
      final String diagnostic = error is PlatformException
          ? 'PlatformException(${error.code})'
          : error.runtimeType.toString();
      Logger.error('Google OAuth launch failed: $diagnostic.');
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
        message: 'Unable to refresh sign-in.',
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
    final sb.User? user = _auth.auth.currentUser;
    Object? serverTokenCleanupFailure;
    if (user != null) {
      try {
        await _beforeSignedOutCallback?.call(user.id);
      } on Object {
        throw FirebaseAuthException(
          code: 'local-notification-isolation-failed',
          message:
              'Sign-out was paused because scheduled reminders could not be isolated safely. Please retry.',
        );
      }
      try {
        await _auth.rpc<dynamic>('unregister_firebase_device');
      } on Object catch (error) {
        serverTokenCleanupFailure = error;
        Logger.warn('Push-token cleanup during sign-out failed: $error');
      }
      try {
        await _devicePushTokenRevokedCallback?.call();
      } on Object {
        Logger.warn('Device push-token revocation during sign-out failed.');
        if (serverTokenCleanupFailure != null) {
          throw FirebaseAuthException(
            code: 'push-token-isolation-failed',
            message:
                'Sign-out was paused because notification isolation could not be confirmed. Please reconnect and retry.',
          );
        }
      }
      if (serverTokenCleanupFailure != null &&
          _devicePushTokenRevokedCallback == null) {
        throw FirebaseAuthException(
          code: 'push-token-isolation-failed',
          message:
              'Sign-out was paused because notification isolation could not be confirmed. Please reconnect and retry.',
        );
      }
    }
    await _auth.auth.signOut();
    await _signedOutCallback?.call();
  }

  @override
  Future<PendingAccountDeletionStatus?> readPendingAccountDeletion() async {
    final _PendingDeletionCapability? capability =
        await _readPendingDeletionCapability();
    if (capability == null) return null;
    return PendingAccountDeletionStatus(
      serverState: capability.serverState,
      createdAtUtc: capability.createdAtUtc,
      localCleanupCompleted: capability.localCleanupCompleted,
    );
  }

  @override
  Future<AccountDeletionResult?> refreshPendingAccountDeletion() async {
    final _PendingDeletionCapability? capability =
        await _readPendingDeletionCapability();
    if (capability == null) return null;

    final Uri? uri = parseSecureHttpsEndpoint(_accountDeleteEndpoint.trim());
    if (uri == null) {
      throw FirebaseAuthException(
        code: 'operation-not-supported',
        message: 'Account deletion status is unavailable in this build.',
      );
    }

    try {
      final http.Response response = await _httpClient
          .post(
            uri,
            headers: const <String, String>{'Content-Type': 'application/json'},
            body: jsonEncode(<String, String>{
              'action': 'status',
              'requestId': capability.requestId,
              'receipt': capability.receipt,
            }),
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw FirebaseAuthException(
          code: response.statusCode == 404
              ? 'deletion-request-not-found'
              : 'operation-failed',
          message:
              'Account deletion status could not be confirmed. Retry or contact support.',
        );
      }
      final Map<String, dynamic> body = _parseDeletionSuccessBody(
        response: response,
      );
      final bool completed = body['completed'] == true;
      final String state = (body['state'] as String?)?.trim() ?? '';
      if (!_deletionStatePattern.hasMatch(state) ||
          (completed && state != 'completed') ||
          (!completed && state == 'completed')) {
        throw _invalidDeletionResponse();
      }
      if (completed) {
        await forgetPendingAccountDeletion();
        return AccountDeletionResult.completed(
          localCleanupCompleted: capability.localCleanupCompleted,
        );
      }
      await _writePendingDeletionCapability(
        capability.copyWith(serverState: state),
      );
      return AccountDeletionResult.pending(
        serverState: state,
        localCleanupCompleted: capability.localCleanupCompleted,
      );
    } on TimeoutException {
      throw FirebaseAuthException(
        code: 'network-request-failed',
        message:
            'Account deletion status timed out. Check your connection and retry.',
      );
    }
  }

  @override
  Future<void> forgetPendingAccountDeletion() {
    return store.delete(_pendingDeletionCapabilityKey);
  }

  @override
  Future<AccountDeletionResult> deleteCurrentAccount({
    required String password,
  }) async {
    final User? user = currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No signed-in user found.',
      );
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

    AccountDeletionResult? acceptedResult;

    try {
      final sb.AuthResponse reauthentication = await _auth.auth
          .signInWithPassword(email: email, password: password);
      final sb.Session? reauthenticatedSession = reauthentication.session;
      final String? accessToken = reauthenticatedSession?.accessToken;
      if (accessToken == null || accessToken.trim().isEmpty) {
        throw FirebaseAuthException(
          code: 'auth-unavailable',
          message: 'Sign-in token missing after re-authentication.',
        );
      }
      if (reauthentication.user?.id != user.id ||
          reauthenticatedSession?.user.id != user.id ||
          _auth.auth.currentUser?.id != user.id) {
        throw FirebaseAuthException(
          code: 'auth-unavailable',
          message: 'Account changed during re-authentication. Please retry.',
        );
      }

      final http.Response response = await _httpClient
          .post(
            uri,
            headers: <String, String>{
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $accessToken',
            },
            // The endpoint derives the deletion target from the bearer token;
            // do not transmit redundant identity or email fields.
            body: jsonEncode(const <String, String>{}),
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

      final Map<String, dynamic> body = _parseDeletionSuccessBody(
        response: response,
      );
      final bool accepted = body['accepted'] == true;
      final bool completed = body['completed'] == true;
      final bool retry = body['retry'] == true;
      final String state = (body['state'] as String?)?.trim() ?? '';
      final String requestId = (body['requestId'] as String?)?.trim() ?? '';
      final String receipt = (body['receipt'] as String?)?.trim() ?? '';
      final bool validCapability =
          _opaqueCapabilityPattern.hasMatch(requestId) &&
          _opaqueCapabilityPattern.hasMatch(receipt);

      if (!accepted || state.isEmpty || !validCapability) {
        throw _invalidDeletionResponse();
      }
      if (response.statusCode == 200 &&
          completed &&
          !retry &&
          state == 'completed') {
        acceptedResult = const AccountDeletionResult.completed();
      } else if (response.statusCode == 202 &&
          !completed &&
          retry &&
          state != 'completed') {
        final bool statusTrackingAvailable =
            await _persistPendingDeletionCapability(
              requestId: requestId,
              receipt: receipt,
              serverState: state,
              localCleanupCompleted: false,
            );
        acceptedResult = AccountDeletionResult.pending(
          serverState: state,
          statusTrackingAvailable: statusTrackingAvailable,
        );
      } else {
        throw _invalidDeletionResponse();
      }
    } on sb.AuthException catch (error) {
      throw _mapAuthException(error);
    } on TimeoutException {
      throw FirebaseAuthException(
        code: 'network-request-failed',
        message: 'Account deletion timed out. Check your connection and retry.',
      );
    }

    return _finalizeAcceptedDeletion(
      accountId: user.id,
      result: acceptedResult,
    );
  }

  Future<AccountDeletionResult> _finalizeAcceptedDeletion({
    required String accountId,
    required AccountDeletionResult result,
  }) async {
    bool localCleanupCompleted = true;

    if (result.isCompleted) {
      try {
        await forgetPendingAccountDeletion();
      } on Object {
        localCleanupCompleted = false;
        Logger.warn(
          'Completed account deletion receipt cleanup failed after server acceptance.',
        );
      }
    }

    try {
      await _beforeSignedOutCallback?.call(accountId);
    } on Object {
      localCleanupCompleted = false;
      Logger.warn(
        'Scheduled reminder isolation failed after server accepted account deletion.',
      );
    }

    try {
      await _auth.auth.signOut();
    } on Object {
      localCleanupCompleted = false;
      Logger.warn(
        'Local sign-out failed after server accepted account deletion.',
      );
    }
    try {
      await _accountDeletedCallback?.call(accountId);
    } on Object {
      localCleanupCompleted = false;
      Logger.warn(
        'Local account-data cleanup failed after server accepted account deletion.',
      );
    }
    try {
      await _signedOutCallback?.call();
    } on Object {
      localCleanupCompleted = false;
      Logger.warn(
        'Post-sign-out cleanup failed after server accepted account deletion.',
      );
    }

    if (result.isPending && result.statusTrackingAvailable) {
      try {
        await _updatePendingDeletionCleanupStatus(localCleanupCompleted);
      } on Object {
        localCleanupCompleted = false;
        Logger.warn(
          'Pending account deletion cleanup status could not be updated.',
        );
      }
    }

    return result.isCompleted
        ? AccountDeletionResult.completed(
            localCleanupCompleted: localCleanupCompleted,
          )
        : AccountDeletionResult.pending(
            serverState: result.serverState,
            localCleanupCompleted: localCleanupCompleted,
            statusTrackingAvailable: result.statusTrackingAvailable,
          );
  }

  Future<bool> _persistPendingDeletionCapability({
    required String requestId,
    required String receipt,
    required String serverState,
    required bool localCleanupCompleted,
  }) async {
    if (!_opaqueCapabilityPattern.hasMatch(requestId) ||
        !_opaqueCapabilityPattern.hasMatch(receipt) ||
        !_deletionStatePattern.hasMatch(serverState)) {
      return false;
    }
    try {
      await _writePendingDeletionCapability(
        _PendingDeletionCapability(
          requestId: requestId,
          receipt: receipt,
          serverState: serverState,
          createdAtUtc: DateTime.now().toUtc(),
          localCleanupCompleted: localCleanupCompleted,
        ),
      );
      return true;
    } on Object {
      Logger.warn(
        'Pending account deletion status capability could not be saved.',
      );
      return false;
    }
  }

  Future<void> _updatePendingDeletionCleanupStatus(bool completed) async {
    final _PendingDeletionCapability? capability =
        await _readPendingDeletionCapability();
    if (capability == null) return;
    await _writePendingDeletionCapability(
      capability.copyWith(localCleanupCompleted: completed),
    );
  }

  Future<void> _writePendingDeletionCapability(
    _PendingDeletionCapability capability,
  ) {
    return store.writeString(
      _pendingDeletionCapabilityKey,
      jsonEncode(capability.toJson()),
    );
  }

  Future<_PendingDeletionCapability?> _readPendingDeletionCapability() async {
    final String? raw = await store.readString(_pendingDeletionCapabilityKey);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map) throw const FormatException();
      final _PendingDeletionCapability? capability =
          _PendingDeletionCapability.fromJson(
            decoded.map(
              (dynamic key, dynamic value) => MapEntry(key.toString(), value),
            ),
          );
      if (capability == null ||
          !_opaqueCapabilityPattern.hasMatch(capability.requestId) ||
          !_opaqueCapabilityPattern.hasMatch(capability.receipt) ||
          !_deletionStatePattern.hasMatch(capability.serverState)) {
        throw const FormatException();
      }
      return capability;
    } on Object {
      await store.delete(_pendingDeletionCapabilityKey);
      Logger.warn('Invalid pending account deletion receipt was removed.');
      return null;
    }
  }

  static Map<String, dynamic> _parseDeletionSuccessBody({
    required http.Response response,
  }) {
    try {
      final Object? decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } on FormatException {
      // Converted below into a stable, non-sensitive client error.
    }
    throw _invalidDeletionResponse();
  }

  static FirebaseAuthException _invalidDeletionResponse() {
    return FirebaseAuthException(
      code: 'invalid-response',
      message:
          'Account deletion returned an invalid success response. Your local account data was preserved.',
    );
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
      appMetadata: Map<String, dynamic>.unmodifiable(supabaseUser.appMetadata),
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
      return FirebaseAuthException(
        code: 'wrong-password',
        message: 'Credentials are incorrect.',
      );
    }
    if (message.contains('email not confirmed')) {
      return FirebaseAuthException(
        code: 'user-not-verified',
        message: 'Verify your email before signing in.',
      );
    }
    if (message.contains('already registered') ||
        message.contains('already been registered')) {
      return FirebaseAuthException(
        code: 'email-already-in-use',
        message: 'Unable to create account with these details.',
      );
    }
    if (rawCode == '429') {
      return FirebaseAuthException(
        code: 'too-many-requests',
        message: 'Too many requests. Please wait and try again.',
      );
    }
    if (rawCode == '400' && message.contains('email')) {
      return FirebaseAuthException(
        code: 'invalid-email',
        message: 'Invalid email format.',
      );
    }
    if (rawCode == '422' && message.contains('password')) {
      return FirebaseAuthException(
        code: 'weak-password',
        message: 'Password does not meet the security requirements.',
      );
    }
    return FirebaseAuthException(
      code: 'auth-unavailable',
      message: 'Authentication backend is unavailable.',
    );
  }
}

final class _PendingDeletionCapability {
  const _PendingDeletionCapability({
    required this.requestId,
    required this.receipt,
    required this.serverState,
    required this.createdAtUtc,
    required this.localCleanupCompleted,
  });

  final String requestId;
  final String receipt;
  final String serverState;
  final DateTime createdAtUtc;
  final bool localCleanupCompleted;

  Map<String, Object> toJson() => <String, Object>{
    'version': 1,
    'requestId': requestId,
    'receipt': receipt,
    'serverState': serverState,
    'createdAtUtc': createdAtUtc.toIso8601String(),
    'localCleanupCompleted': localCleanupCompleted,
  };

  _PendingDeletionCapability copyWith({
    String? serverState,
    bool? localCleanupCompleted,
  }) {
    return _PendingDeletionCapability(
      requestId: requestId,
      receipt: receipt,
      serverState: serverState ?? this.serverState,
      createdAtUtc: createdAtUtc,
      localCleanupCompleted:
          localCleanupCompleted ?? this.localCleanupCompleted,
    );
  }

  static _PendingDeletionCapability? fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1) return null;
    final String requestId = json['requestId']?.toString().trim() ?? '';
    final String receipt = json['receipt']?.toString().trim() ?? '';
    final String serverState = json['serverState']?.toString().trim() ?? '';
    final DateTime? createdAtUtc = DateTime.tryParse(
      json['createdAtUtc']?.toString() ?? '',
    )?.toUtc();
    final Object? localCleanupCompleted = json['localCleanupCompleted'];
    if (requestId.isEmpty ||
        receipt.isEmpty ||
        serverState.isEmpty ||
        createdAtUtc == null ||
        localCleanupCompleted is! bool) {
      return null;
    }
    return _PendingDeletionCapability(
      requestId: requestId,
      receipt: receipt,
      serverState: serverState,
      createdAtUtc: createdAtUtc,
      localCleanupCompleted: localCleanupCompleted,
    );
  }
}
