import 'dart:async';

import 'package:fantastic_guacamole/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:fantastic_guacamole/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:fantastic_guacamole/features/auth/data/models/auth_session_model.dart';
import 'package:fantastic_guacamole/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:fantastic_guacamole/features/auth/domain/entities/auth_session_entity.dart';
import 'package:fantastic_guacamole/features/auth/domain/entities/auth_user_entity.dart';
import 'package:fantastic_guacamole/features/auth/domain/value_objects/email_address.dart';
import 'package:fantastic_guacamole/features/auth/domain/value_objects/password_value.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthRepositoryImpl session restoration', () {
    test('uses and caches a valid remote session', () async {
      final _FakeLocalDataSource local = _FakeLocalDataSource();
      final AuthSessionEntity remoteSession = _activeSession();
      final AuthRepositoryImpl repository = AuthRepositoryImpl(
        remoteDataSource: _FakeRemoteDataSource(session: remoteSession),
        localDataSource: local,
      );

      final result = await repository.getCurrentSession();

      expect(result.getOrNull(), remoteSession);
      expect(local.cachedSession, remoteSession);
    });

    test('clears a cached session when Supabase reports no session', () async {
      final _FakeLocalDataSource local = _FakeLocalDataSource(
        cachedSession: _activeSession(),
      );
      final AuthRepositoryImpl repository = AuthRepositoryImpl(
        remoteDataSource: _FakeRemoteDataSource(),
        localDataSource: local,
      );

      final result = await repository.getCurrentSession();

      expect(result.getOrNull(), isNull);
      expect(local.cachedSession, isNull);
      expect(local.clearCalls, 1);
    });

    test('clears cached session when remote revalidation fails', () async {
      final _FakeLocalDataSource local = _FakeLocalDataSource(
        cachedSession: _activeSession(),
      );
      final AuthRepositoryImpl repository = AuthRepositoryImpl(
        remoteDataSource: _FakeRemoteDataSource(
          getSessionError: StateError('refresh token rejected'),
        ),
        localDataSource: local,
      );

      final result = await repository.getCurrentSession();

      expect(result.isFailure, isTrue);
      expect(local.cachedSession, isNull);
      expect(local.clearCalls, 1);
    });

    test('does not restore an expired cached session', () async {
      final _FakeLocalDataSource local = _FakeLocalDataSource(
        cachedSession: _activeSession(expired: true),
      );
      final AuthRepositoryImpl repository = AuthRepositoryImpl(
        remoteDataSource: _FakeRemoteDataSource(),
        localDataSource: local,
      );

      final result = await repository.getCurrentSession();

      expect(result.getOrNull(), isNull);
      expect(local.cachedSession, isNull);
    });

    test(
      'remote sign-out simulation clears cached session and stays signed out',
      () async {
        final _FakeLocalDataSource local = _FakeLocalDataSource(
          cachedSession: _activeSession(),
        );
        final AuthRepositoryImpl repository = AuthRepositoryImpl(
          remoteDataSource: _FakeRemoteDataSource(),
          localDataSource: local,
        );

        final result = await repository.getCurrentSession();

        expect(result.getOrNull(), isNull);
        expect(local.cachedSession, isNull);
      },
    );
  });

  group('AuthRepositoryImpl sign-out', () {
    test('clears local cache after successful remote sign-out', () async {
      final _FakeLocalDataSource local = _FakeLocalDataSource(
        cachedSession: _activeSession(),
      );
      final AuthRepositoryImpl repository = AuthRepositoryImpl(
        remoteDataSource: _FakeRemoteDataSource(),
        localDataSource: local,
      );

      final result = await repository.signOut();

      expect(result.isSuccess, isTrue);
      expect(local.cachedSession, isNull);
    });

    test('clears local cache when remote sign-out fails', () async {
      final _FakeLocalDataSource local = _FakeLocalDataSource(
        cachedSession: _activeSession(),
      );
      final AuthRepositoryImpl repository = AuthRepositoryImpl(
        remoteDataSource: _FakeRemoteDataSource(
          signOutError: StateError('network unavailable'),
        ),
        localDataSource: local,
      );

      final result = await repository.signOut();

      expect(result.isFailure, isTrue);
      expect(local.cachedSession, isNull);
    });
  });
}

class _FakeLocalDataSource implements AuthLocalDataSource {
  _FakeLocalDataSource({this.cachedSession});

  AuthSessionEntity? cachedSession;
  int clearCalls = 0;

  @override
  Future<void> cacheSession(AuthSessionEntity? session) async {
    cachedSession = session;
  }

  @override
  Future<void> clearSession() async {
    clearCalls += 1;
    cachedSession = null;
  }

  @override
  Future<AuthSessionEntity?> getCachedSession() async => cachedSession;
}

class _FakeRemoteDataSource implements AuthRemoteDataSource {
  _FakeRemoteDataSource({
    this.session,
    this.getSessionError,
    this.signOutError,
  });

  final AuthSessionEntity? session;
  final Object? getSessionError;
  final Object? signOutError;

  @override
  Future<AuthSessionModel?> getCurrentSession() async {
    if (getSessionError != null) {
      throw getSessionError!;
    }
    return session == null ? null : AuthSessionModel.fromEntity(session!);
  }

  @override
  Future<void> signOut() async {
    if (signOutError != null) {
      throw signOutError!;
    }
  }

  @override
  Stream<AuthSessionModel?> watchSession() =>
      const Stream<AuthSessionModel?>.empty();

  @override
  Future<AuthSessionModel?> signInWithEmail({
    required EmailAddress email,
    required PasswordValue password,
  }) => throw UnimplementedError();

  @override
  Future<AuthSessionModel?> signUpWithEmail({
    required EmailAddress email,
    required PasswordValue password,
  }) => throw UnimplementedError();

  @override
  Future<AuthSessionModel?> signInWithGoogle() => throw UnimplementedError();

  @override
  Future<void> sendEmailVerification() => throw UnimplementedError();

  @override
  Future<void> sendPasswordReset({required EmailAddress email}) =>
      throw UnimplementedError();

  @override
  Future<void> refreshSession() => throw UnimplementedError();

  @override
  Future<void> deleteAccount({required PasswordValue password}) =>
      throw UnimplementedError();
}

AuthSessionEntity _activeSession({bool expired = false}) {
  final DateTime now = DateTime.now();
  return AuthSessionEntity(
    accessToken: 'access-token',
    refreshToken: 'refresh-token',
    issuedAt: now.subtract(const Duration(hours: 1)),
    expiresAt: expired
        ? now.subtract(const Duration(minutes: 1))
        : now.add(const Duration(hours: 1)),
    user: const AuthUserEntity(
      id: 'user-1',
      email: 'person@example.com',
      displayName: 'Person',
      emailVerified: true,
      isAnonymous: false,
    ),
  );
}
