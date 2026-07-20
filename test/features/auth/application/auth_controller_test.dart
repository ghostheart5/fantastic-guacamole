import 'dart:async';

import 'package:fantastic_guacamole/features/auth/application/auth_controller.dart';
import 'package:fantastic_guacamole/features/auth/application/auth_state.dart';
import 'package:fantastic_guacamole/features/auth/domain/core/result.dart';
import 'package:fantastic_guacamole/features/auth/domain/entities/auth_session_entity.dart';
import 'package:fantastic_guacamole/features/auth/domain/entities/auth_user_entity.dart';
import 'package:fantastic_guacamole/features/auth/domain/repositories/auth_repository.dart';
import 'package:fantastic_guacamole/features/auth/domain/validators/auth_input_validator.dart';
import 'package:fantastic_guacamole/features/auth/domain/value_objects/email_address.dart';
import 'package:fantastic_guacamole/features/auth/domain/value_objects/password_value.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this._session});

  AuthSessionEntity? _session;
  final StreamController<Result<AuthSessionEntity?>> _controller =
      StreamController<Result<AuthSessionEntity?>>.broadcast();

  @override
  Stream<Result<AuthSessionEntity?>> watchSession() => _controller.stream;

  @override
  Future<Result<AuthSessionEntity?>> getCurrentSession() async {
    return Result<AuthSessionEntity?>.success(_session);
  }

  @override
  Future<Result<AuthUserEntity?>> getCurrentUser() async {
    return Result<AuthUserEntity?>.success(_session?.user);
  }

  @override
  Future<Result<AuthSessionEntity?>> signInWithEmail({
    required EmailAddress email,
    required PasswordValue password,
  }) async {
    _session = AuthSessionEntity(
      accessToken: 'token',
      refreshToken: 'refresh',
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
      user: AuthUserEntity(
        id: 'user-1',
        email: email.value,
        displayName: 'Test User',
        emailVerified: true,
        isAnonymous: false,
      ),
      issuedAt: DateTime.now(),
    );
    return Result<AuthSessionEntity?>.success(_session);
  }

  @override
  Future<Result<AuthSessionEntity?>> signUpWithEmail({
    required EmailAddress email,
    required PasswordValue password,
  }) async {
    return signInWithEmail(email: email, password: password);
  }

  @override
  Future<Result<AuthSessionEntity?>> signInWithGoogle() async {
    return const Result<AuthSessionEntity?>.failure('not implemented');
  }

  @override
  Future<Result<AuthSessionEntity?>> signInWithGitHub() async {
    return const Result<AuthSessionEntity?>.failure('not implemented');
  }

  @override
  Future<Result<void>> sendPasswordReset({required EmailAddress email}) async {
    return const Result<void>.success(null);
  }

  @override
  Future<Result<void>> sendEmailVerification() async {
    return const Result<void>.success(null);
  }

  @override
  Future<Result<void>> refreshSession() async {
    return const Result<void>.success(null);
  }

  @override
  Future<Result<void>> signOut() async {
    _session = null;
    return const Result<void>.success(null);
  }

  @override
  Future<Result<void>> deleteAccount({required PasswordValue password}) async {
    _session = null;
    return const Result<void>.success(null);
  }

  void emitSession(AuthSessionEntity? session) {
    _controller.add(Result<AuthSessionEntity?>.success(session));
  }

  Future<void> dispose() => _controller.close();
}

void main() {
  test('updates state when sign in succeeds', () async {
    final FakeAuthRepository repository = FakeAuthRepository();
    final AuthController controller = AuthController(
      repository: repository,
      validator: const AuthInputValidator(),
    );

    await controller.signInWithEmail(
      email: 'person@example.com',
      password: 'Password123',
    );

    expect(controller.state.status, AuthStatus.authenticated);
    expect(controller.state.user?.email, 'person@example.com');
    controller.dispose();
    await repository.dispose();
  });

  test('reacts to external session changes', () async {
    final AuthSessionEntity session = AuthSessionEntity(
      accessToken: 'stream-token',
      refreshToken: 'refresh',
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
      user: const AuthUserEntity(
        id: 'user-stream',
        email: 'stream@example.com',
        displayName: 'Stream User',
        emailVerified: true,
        isAnonymous: false,
      ),
      issuedAt: DateTime.now(),
    );
    final FakeAuthRepository repository = FakeAuthRepository();
    final AuthController controller = AuthController(
      repository: repository,
      validator: const AuthInputValidator(),
    );

    repository.emitSession(session);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(controller.state.status, AuthStatus.authenticated);
    expect(controller.state.user?.email, 'stream@example.com');
    controller.dispose();
    await repository.dispose();
  });
}
