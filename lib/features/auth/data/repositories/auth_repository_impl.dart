import 'package:fantastic_guacamole/features/auth/domain/core/failure.dart';
import 'package:fantastic_guacamole/features/auth/domain/core/result.dart';
import 'package:fantastic_guacamole/features/auth/domain/entities/auth_session_entity.dart';
import 'package:fantastic_guacamole/features/auth/domain/entities/auth_user_entity.dart';
import 'package:fantastic_guacamole/features/auth/domain/repositories/auth_repository.dart';
import 'package:fantastic_guacamole/features/auth/domain/value_objects/email_address.dart';
import 'package:fantastic_guacamole/features/auth/domain/value_objects/password_value.dart';
import 'package:fantastic_guacamole/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:fantastic_guacamole/features/auth/data/datasources/auth_remote_data_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required this._remoteDataSource,
    required this._localDataSource,
  });

  final AuthRemoteDataSource _remoteDataSource;
  final AuthLocalDataSource _localDataSource;

  @override
  Stream<Result<AuthSessionEntity?>> watchSession() async* {
    await for (final AuthSessionEntity? session in _remoteDataSource.watchSession()) {
      try {
        if (session == null) {
          await _localDataSource.clearSession();
          yield const Result<AuthSessionEntity?>.success(null);
        } else {
          await _localDataSource.cacheSession(session);
          yield Result<AuthSessionEntity?>.success(session);
        }
      } catch (error) {
        yield Result<AuthSessionEntity?>.failure(
          AuthFailure(
            code: 'auth-cache-failed',
            message: 'Failed to update cached auth session.',
            details: error,
          ),
        );
      }
    }
  }

  @override
  Future<Result<AuthSessionEntity?>> getCurrentSession() async {
    try {
      final AuthSessionEntity? session = await _remoteDataSource.getCurrentSession();
      if (session == null) {
        final AuthSessionEntity? cached = await _localDataSource.getCachedSession();
        return Result<AuthSessionEntity?>.success(cached);
      }
      await _localDataSource.cacheSession(session);
      return Result<AuthSessionEntity?>.success(session);
    } catch (error) {
      return Result<AuthSessionEntity?>.failure(
        AuthFailure(
          code: 'auth-session-failed',
          message: 'Unable to retrieve the current auth session.',
          details: error,
        ),
      );
    }
  }

  @override
  Future<Result<AuthUserEntity?>> getCurrentUser() async {
    final Result<AuthSessionEntity?> result = await getCurrentSession();
    return result.fold(
      onSuccess: (AuthSessionEntity? session) {
        return Result<AuthUserEntity?>.success(session?.user);
      },
      onFailure: (Object failure) {
        return Result<AuthUserEntity?>.failure(failure);
      },
    );
  }

  @override
  Future<Result<AuthSessionEntity?>> signInWithEmail({
    required EmailAddress email,
    required PasswordValue password,
  }) => _wrapSession(() => _remoteDataSource.signInWithEmail(email: email, password: password));

  @override
  Future<Result<AuthSessionEntity?>> signUpWithEmail({
    required EmailAddress email,
    required PasswordValue password,
  }) => _wrapSession(() => _remoteDataSource.signUpWithEmail(email: email, password: password));

  @override
  Future<Result<AuthSessionEntity?>> signInWithGoogle() => _wrapSession(_remoteDataSource.signInWithGoogle);

  @override
  Future<Result<AuthSessionEntity?>> signInWithGitHub() => _wrapSession(_remoteDataSource.signInWithGitHub);

  @override
  Future<Result<void>> sendPasswordReset({required EmailAddress email}) {
    return _wrapVoid(() => _remoteDataSource.sendPasswordReset(email: email));
  }

  @override
  Future<Result<void>> sendEmailVerification() {
    return _wrapVoid(_remoteDataSource.sendEmailVerification);
  }

  @override
  Future<Result<void>> refreshSession() {
    return _wrapVoid(_remoteDataSource.refreshSession);
  }

  @override
  Future<Result<void>> signOut() {
    return _wrapVoid(() async {
      await _remoteDataSource.signOut();
      await _localDataSource.clearSession();
    });
  }

  @override
  Future<Result<void>> deleteAccount({required PasswordValue password}) {
    return _wrapVoid(() async {
      await _remoteDataSource.deleteAccount(password: password);
      await _localDataSource.clearSession();
    });
  }

  Future<Result<AuthSessionEntity?>> _wrapSession(
    Future<AuthSessionEntity?> Function() action,
  ) async {
    try {
      final AuthSessionEntity? session = await action();
      if (session == null) {
        await _localDataSource.clearSession();
        return const Result<AuthSessionEntity?>.success(null);
      }
      await _localDataSource.cacheSession(session);
      return Result<AuthSessionEntity?>.success(session);
    } catch (error) {
      return Result<AuthSessionEntity?>.failure(
        AuthFailure(
          code: 'auth-operation-failed',
          message: 'Authentication operation failed.',
          details: error,
        ),
      );
    }
  }

  Future<Result<void>> _wrapVoid(Future<void> Function() action) async {
    try {
      await action();
      return const Result<void>.success(null);
    } catch (error) {
      return Result<void>.failure(
        AuthFailure(
          code: 'auth-operation-failed',
          message: 'Authentication operation failed.',
          details: error,
        ),
      );
    }
  }
}
