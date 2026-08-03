import 'package:fantastic_guacamole/features/auth/application/auth_state.dart';
import 'package:fantastic_guacamole/features/auth/domain/core/failure.dart';
import 'package:fantastic_guacamole/features/auth/domain/entities/auth_session_entity.dart';
import 'package:fantastic_guacamole/features/auth/domain/entities/auth_user_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthState', () {
    test('initial state is not busy, authenticated, or error', () {
      final AuthState state = AuthState.initial();

      expect(state.status, AuthStatus.initial);
      expect(state.isBusy, isFalse);
      expect(state.isAuthenticated, isFalse);
      expect(state.hasError, isFalse);
    });

    test('copyWith reflects authenticated and error transitions', () {
      const AuthUserEntity user = AuthUserEntity(
        id: 'u1',
        email: 'u1@example.com',
        displayName: 'U1',
        emailVerified: true,
        isAnonymous: false,
      );
      final AuthSessionEntity session = AuthSessionEntity(
        accessToken: 'a',
        refreshToken: 'r',
        issuedAt: DateTime(2026, 1, 1),
        expiresAt: DateTime(2099, 1, 1),
        user: user,
      );

      final AuthState authenticated = AuthState.initial().copyWith(
        status: AuthStatus.authenticated,
        session: session,
        user: user,
      );

      expect(authenticated.isAuthenticated, isTrue);

      final AuthState errored = authenticated.copyWith(
        status: AuthStatus.error,
        failure: const AuthFailure(code: 'x', message: 'nope'),
      );
      expect(errored.hasError, isTrue);
    });
  });

  group('Auth entities', () {
    test('AuthUserEntity round-trips via map', () {
      const AuthUserEntity original = AuthUserEntity(
        id: 'user-1',
        email: 'test@example.com',
        displayName: 'Tester',
        emailVerified: true,
        isAnonymous: false,
        avatarUrl: 'https://avatar',
        roles: <String>['member', 'admin'],
      );

      final AuthUserEntity reconstructed = AuthUserEntity.fromMap(original.toMap());
      expect(reconstructed, original);
    });

    test('AuthSessionEntity map conversion preserves key fields and expiry flag', () {
      const AuthUserEntity user = AuthUserEntity(
        id: 'user-2',
        email: 'u2@example.com',
        displayName: 'U2',
        emailVerified: false,
        isAnonymous: false,
      );
      final AuthSessionEntity futureSession = AuthSessionEntity(
        accessToken: 'token-a',
        refreshToken: 'token-r',
        issuedAt: DateTime(2026, 8, 1),
        expiresAt: DateTime(2099, 8, 1),
        user: user,
      );

      final AuthSessionEntity reconstructed = AuthSessionEntity.fromMap(
        futureSession.toMap(),
      );

      expect(reconstructed.accessToken, 'token-a');
      expect(reconstructed.user.email, 'u2@example.com');
      expect(reconstructed.isExpired, isFalse);
    });
  });
}
