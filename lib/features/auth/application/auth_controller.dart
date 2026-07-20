import 'dart:async';

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
  AuthController({
    required this._repository,
    required this._validator,
  })  : super(AuthState.initial()) {
    _sessionSubscription = _repository.watchSession().listen(_applySessionResult);
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
    final Result<AuthSessionEntity?> result = await _repository.getCurrentSession();
    _applySessionResult(result);
  }

  Future<void> signInWithEmail({required String email, required String password}) async {
    final Result<void> validation = _validator.validateLogin(email: email, password: password);
    if (validation.isFailure) {
      state = state.copyWith(status: AuthStatus.error, failure: _normalizeFailure(validation.failure), lastUpdated: DateTime.now());
      return;
    }
    state = state.copyWith(status: AuthStatus.loading, failure: null);
    final Result<AuthSessionEntity?> result = await _repository.signInWithEmail(
      email: EmailAddress(email),
      password: PasswordValue(password),
    );
    _applySessionResult(result);
  }

  Future<void> signUpWithEmail({required String email, required String password}) async {
    final Result<void> validation = _validator.validateSignUp(email: email, password: password);
    if (validation.isFailure) {
      state = state.copyWith(status: AuthStatus.error, failure: _normalizeFailure(validation.failure), lastUpdated: DateTime.now());
      return;
    }
    state = state.copyWith(status: AuthStatus.loading, failure: null);
    final Result<AuthSessionEntity?> result = await _repository.signUpWithEmail(
      email: EmailAddress(email),
      password: PasswordValue(password),
    );
    _applySessionResult(result);
  }

  Future<void> signOut() async {
    state = state.copyWith(status: AuthStatus.loading, failure: null);
    final Result<void> result = await _repository.signOut();
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
    final Result<AuthSessionEntity?> result = await _repository.signInWithGoogle();
    _applySessionResult(result);
  }

  Future<void> signInWithGitHub() async {
    state = state.copyWith(status: AuthStatus.loading, failure: null);
    final Result<AuthSessionEntity?> result = await _repository.signInWithGitHub();
    _applySessionResult(result);
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

  void _applySessionResult(Result<AuthSessionEntity?> result) {
    result.fold(
      onSuccess: (AuthSessionEntity? session) {
        final bool authenticated = session != null && !session.isExpired;
        state = state.copyWith(
          status: authenticated ? AuthStatus.authenticated : AuthStatus.unauthenticated,
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
      message: failure?.toString() ?? 'An unknown authentication error occurred.',
      details: failure,
    );
  }
}
