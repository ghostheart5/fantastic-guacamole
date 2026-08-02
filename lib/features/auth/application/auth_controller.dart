import 'package:fantastic_guacamole/features/auth/domain/models/chronospark_identity.dart';
import 'package:fantastic_guacamole/features/auth/data/repositories/local_identity_repository.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';

import 'package:state_notifier/state_notifier.dart';

import 'package:fantastic_guacamole/features/auth/domain/core/failure.dart';
import 'package:fantastic_guacamole/features/auth/domain/core/result.dart';
import 'package:fantastic_guacamole/features/auth/domain/entities/auth_session_entity.dart';
import 'package:fantastic_guacamole/features/auth/domain/repositories/auth_repository.dart';
import 'package:fantastic_guacamole/features/auth/domain/validators/auth_input_validator.dart';
import 'package:fantastic_guacamole/features/auth/domain/value_objects/email_address.dart';
import 'package:fantastic_guacamole/features/auth/domain/value_objects/password_value.dart';
import 'package:fantastic_guacamole/features/auth/application/auth_state.dart';

class AuthController extends StateNotifier<AuthState> {
  AuthController({required this._repository, required this._validator})
    : super(AuthState.initial()) {
    _sessionSubscription = _repository.watchSession().listen(
      _applySessionResult,
    );
    restoreSession();
  }

  final AuthRepository _repository;
  final AuthInputValidator _validator;
  StreamSubscription<Result<AuthSessionEntity?>>? _sessionSubscription;

  @override
  void dispose() {
    unawaited(_sessionSubscription?.cancel());
    super.dispose();
  }

  Future<void> restoreSession() async {
    state = state.copyWith(status: AuthStatus.loading, failure: null);
    final Result<AuthSessionEntity?> result = await _repository
        .getCurrentSession();
    _applySessionResult(result);
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final Result<void> validation = _validator.validateLogin(
      email: email,
      password: password,
    );
    if (validation.isFailure) {
      state = state.copyWith(
        status: AuthStatus.error,
        failure: _normalizeFailure(validation.failure),
        lastUpdated: DateTime.now(),
      );
      return;
    }
    state = state.copyWith(status: AuthStatus.loading, failure: null);
    final Result<AuthSessionEntity?> result = await _repository.signInWithEmail(
      email: EmailAddress(email),
      password: PasswordValue(password),
    );
    _applySessionResult(result);
    await _persistChronoSparkIdentityFromResult(
      result,
      provider: ChronoSparkAuthProvider.email,
    );
  }

  Future<void> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    final Result<void> validation = _validator.validateSignUp(
      email: email,
      password: password,
    );
    if (validation.isFailure) {
      state = state.copyWith(
        status: AuthStatus.error,
        failure: _normalizeFailure(validation.failure),
        lastUpdated: DateTime.now(),
      );
      return;
    }
    state = state.copyWith(status: AuthStatus.loading, failure: null);
    final Result<AuthSessionEntity?> result = await _repository.signUpWithEmail(
      email: EmailAddress(email),
      password: PasswordValue(password),
    );
    _applySessionResult(result);
    await _persistChronoSparkIdentityFromResult(
      result,
      provider: ChronoSparkAuthProvider.email,
    );
  }

  Future<void> signOut() async {
    state = state.copyWith(status: AuthStatus.loading, failure: null);
    final Result<void> result = await _repository.signOut();
    await _clearChronoSparkIdentityFromResult(result);
    result.fold(
      onSuccess: (_) {
        state = AuthState(
          status: AuthStatus.unauthenticated,
          lastUpdated: DateTime.now(),
        );
      },
      onFailure: (Object failure) {
        state = state.copyWith(
          status: AuthStatus.error,
          failure: _normalizeFailure(failure),
          lastUpdated: DateTime.now(),
        );
      },
    );
  }

  Future<void> signInWithGoogle() async {
    state = state.copyWith(status: AuthStatus.loading, failure: null);
    final Result<AuthSessionEntity?> result = await _repository
        .signInWithGoogle();

    bool successWithoutSession = false;
    bool hasValidSession = false;
    result.fold(
      onSuccess: (AuthSessionEntity? session) {
        final bool authenticated = session != null && !session.isExpired;
        hasValidSession = authenticated;
        successWithoutSession = !authenticated;
      },
      onFailure: (Object _) {},
    );

    if (successWithoutSession) {
      // Browser OAuth may return before callback session is available.
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        session: null,
        user: null,
        failure: null,
        lastUpdated: DateTime.now(),
      );
      return;
    }

    _applySessionResult(result);
    if (hasValidSession) {
      await _persistChronoSparkIdentityFromResult(
        result,
        provider: ChronoSparkAuthProvider.google,
      );
    }
  }

  Future<void> completeOAuthCallback() async {
    debugPrint('Authentication callback received');
    state = state.copyWith(status: AuthStatus.loading, failure: null);

    final Result<AuthSessionEntity?> result = await _repository
        .getCurrentSession();

    _applySessionResult(result);
    await _persistChronoSparkIdentityFromResult(
      result,
      provider: ChronoSparkAuthProvider.google,
    );

    bool hasValidSession = false;
    result.fold(
      onSuccess: (AuthSessionEntity? session) {
        hasValidSession = session != null && !session.isExpired;
      },
      onFailure: (Object _) {},
    );

    if (hasValidSession) {
      debugPrint('OAuth callback session refresh completed');
    } else {
      debugPrint('OAuth callback session missing');
    }
  }

  Future<void> sendPasswordReset(String email) async {
    final Result<void> validation = _validator.validateEmail(email);
    if (validation.isFailure) {
      state = state.copyWith(
        status: AuthStatus.error,
        failure: _normalizeFailure(validation.failure),
        lastUpdated: DateTime.now(),
      );
      return;
    }
    state = state.copyWith(status: AuthStatus.loading, failure: null);
    final Result<void> result = await _repository.sendPasswordReset(
      email: EmailAddress(email),
    );
    result.fold(
      onSuccess: (_) {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          lastUpdated: DateTime.now(),
        );
      },
      onFailure: (Object failure) {
        state = state.copyWith(
          status: AuthStatus.error,
          failure: _normalizeFailure(failure),
          lastUpdated: DateTime.now(),
        );
      },
    );
  }

  Future<void> _persistChronoSparkIdentityFromResult(
    Result<AuthSessionEntity?> result, {
    required ChronoSparkAuthProvider provider,
  }) async {
    AuthSessionEntity? successfulSession;

    result.fold(
      onSuccess: (AuthSessionEntity? session) {
        successfulSession = session;
      },
      onFailure: (Object _) {},
    );

    final AuthSessionEntity? session = successfulSession;

    if (session == null || session.isExpired) {
      return;
    }

    final DateTime now = DateTime.now();
    final String email = session.user.email.trim();
    final String displayName = session.user.displayName.trim().isEmpty
        ? 'Operator'
        : session.user.displayName.trim();

    final ChronoSparkIdentity identity = ChronoSparkIdentity(
      id: '${provider.name}-${now.millisecondsSinceEpoch}',
      email: email,
      displayName: displayName,
      createdAt: now,
      lastActiveAt: now,
      accountTier: ChronoSparkAccountTier.free,
      authProvider: provider,
      syncStatus: ChronoSparkIdentitySyncStatus.localOnly,
      emailVerified: session.user.emailVerified,
    );

    await LocalIdentityRepository().saveIdentity(identity);
  }

  Future<void> _clearChronoSparkIdentityFromResult(Result<void> result) async {
    bool shouldClear = false;

    result.fold(
      onSuccess: (_) {
        shouldClear = true;
      },
      onFailure: (Object _) {},
    );

    if (!shouldClear) {
      return;
    }

    await LocalIdentityRepository().clearIdentity();
  }

  void _applySessionResult(Result<AuthSessionEntity?> result) {
    result.fold(
      onSuccess: (AuthSessionEntity? session) {
        final bool authenticated = session != null && !session.isExpired;
        state = state.copyWith(
          status: authenticated
              ? AuthStatus.authenticated
              : AuthStatus.unauthenticated,
          session: authenticated ? session : null,
          user: authenticated ? session.user : null,
          failure: null,
          lastUpdated: DateTime.now(),
        );
      },
      onFailure: (Object failure) {
        state = state.copyWith(
          status: AuthStatus.error,
          failure: _normalizeFailure(failure),
          lastUpdated: DateTime.now(),
        );
      },
    );
  }

  AuthFailure _normalizeFailure(Object? failure) {
    if (failure is AuthFailure) {
      return failure;
    }
    return AuthFailure(
      code: 'auth-unknown',
      message: 'Authentication could not be completed. Please try again.',
      details: failure,
    );
  }
}
