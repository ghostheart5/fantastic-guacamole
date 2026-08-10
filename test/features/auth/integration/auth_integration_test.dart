import 'dart:async';

import 'package:fantastic_guacamole/features/auth/application/auth_providers.dart';
import 'package:fantastic_guacamole/features/auth/application/auth_state.dart';
import 'package:fantastic_guacamole/features/auth/domain/core/result.dart';
import 'package:fantastic_guacamole/features/auth/domain/entities/auth_session_entity.dart';
import 'package:fantastic_guacamole/features/auth/domain/entities/auth_user_entity.dart';
import 'package:fantastic_guacamole/features/auth/domain/repositories/auth_repository.dart';
import 'package:fantastic_guacamole/features/auth/domain/value_objects/email_address.dart';
import 'package:fantastic_guacamole/features/auth/domain/value_objects/password_value.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('auth integration flow', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test(
      'login success authenticates user and publishes session state',
      () async {
        final _FakeAuthRepository repository = _FakeAuthRepository(
          initialSession: null,
        );
        final ProviderContainer container = ProviderContainer(
          overrides: [authRepositoryProvider.overrideWithValue(repository)],
        );
        addTearDown(container.dispose);

        final states = <AuthStatus>[];
        final subscription = container.listen<AuthState>(
          authControllerProvider,
          (_, AuthState next) => states.add(next.status),
          fireImmediately: true,
        );
        addTearDown(subscription.close);

        await container
            .read(authControllerProvider.notifier)
            .signInWithEmail(
              email: 'pilot@example.com',
              password: 'Password123',
            );

        final AuthState state = container.read(authControllerProvider);
        expect(state.status, AuthStatus.authenticated);
        expect(state.user?.email, 'pilot@example.com');
        expect(states.contains(AuthStatus.loading), isTrue);
      },
    );

    test(
      'expired session refresh recovers from unauthenticated to authenticated',
      () async {
        final _FakeAuthRepository repository = _FakeAuthRepository(
          initialSession: _expiredSession(),
        );
        final ProviderContainer container = ProviderContainer(
          overrides: [authRepositoryProvider.overrideWithValue(repository)],
        );
        addTearDown(container.dispose);

        await container.read(authControllerProvider.notifier).restoreSession();
        expect(
          container.read(authControllerProvider).status,
          AuthStatus.unauthenticated,
        );

        await repository.refreshSession();
        await Future<void>.delayed(Duration.zero);

        final AuthState recovered = container.read(authControllerProvider);
        expect(recovered.status, AuthStatus.authenticated);
        expect(recovered.session?.accessToken, 'token-refreshed');
      },
    );

    test(
      'logout to login loop transitions unauthenticated then authenticated again',
      () async {
        final _FakeAuthRepository repository = _FakeAuthRepository(
          initialSession: _activeSession(
            'loop-a',
            'loop@example.com',
            'token-a',
          ),
        );
        final ProviderContainer container = ProviderContainer(
          overrides: [authRepositoryProvider.overrideWithValue(repository)],
        );
        addTearDown(container.dispose);

        await container.read(authControllerProvider.notifier).restoreSession();
        expect(
          container.read(authControllerProvider).status,
          AuthStatus.authenticated,
        );

        await container.read(authControllerProvider.notifier).signOut();
        expect(
          container.read(authControllerProvider).status,
          AuthStatus.unauthenticated,
        );

        await container
            .read(authControllerProvider.notifier)
            .signInWithEmail(
              email: 'loop@example.com',
              password: 'Password123',
            );

        final AuthState state = container.read(authControllerProvider);
        expect(state.status, AuthStatus.authenticated);
        expect(state.user?.email, 'loop@example.com');
      },
    );

    test(
      'failed remote sign-out still leaves the controller signed out',
      () async {
        final _FakeAuthRepository repository = _FakeAuthRepository(
          initialSession: _activeSession(
            'logout-failure',
            'logout@example.com',
            'token-a',
          ),
          failSignOut: true,
        );
        final ProviderContainer container = ProviderContainer(
          overrides: [authRepositoryProvider.overrideWithValue(repository)],
        );
        addTearDown(container.dispose);

        await container.read(authControllerProvider.notifier).restoreSession();
        await container.read(authControllerProvider.notifier).signOut();

        expect(
          container.read(authControllerProvider).status,
          AuthStatus.unauthenticated,
        );
        expect(container.read(authControllerProvider).isAuthenticated, isFalse);
      },
    );
  });
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({
    required AuthSessionEntity? initialSession,
    this.failSignOut = false,
  }) : _session = initialSession;

  final StreamController<Result<AuthSessionEntity?>> _sessionStream =
      StreamController<Result<AuthSessionEntity?>>.broadcast();
  final bool failSignOut;
  AuthSessionEntity? _session;

  @override
  Stream<Result<AuthSessionEntity?>> watchSession() => _sessionStream.stream;

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
    _session = _activeSession('user-1', email.value, 'token-login');
    _sessionStream.add(Result<AuthSessionEntity?>.success(_session));
    return Result<AuthSessionEntity?>.success(_session);
  }

  @override
  Future<Result<AuthSessionEntity?>> signUpWithEmail({
    required EmailAddress email,
    required PasswordValue password,
  }) async {
    _session = _activeSession('user-signup', email.value, 'token-signup');
    _sessionStream.add(Result<AuthSessionEntity?>.success(_session));
    return Result<AuthSessionEntity?>.success(_session);
  }

  @override
  Future<Result<AuthSessionEntity?>> signInWithGoogle() async {
    _session = _activeSession(
      'user-google',
      'google@example.com',
      'token-google',
    );
    _sessionStream.add(Result<AuthSessionEntity?>.success(_session));
    return Result<AuthSessionEntity?>.success(_session);
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
    _session = _activeSession(
      'user-refresh',
      'refresh@example.com',
      'token-refreshed',
    );
    _sessionStream.add(Result<AuthSessionEntity?>.success(_session));
    return const Result<void>.success(null);
  }

  @override
  Future<Result<void>> signOut() async {
    _session = null;
    _sessionStream.add(const Result<AuthSessionEntity?>.success(null));
    if (failSignOut) {
      return Result<void>.failure(StateError('remote sign-out failed'));
    }
    return const Result<void>.success(null);
  }

  @override
  Future<Result<void>> deleteAccount({required PasswordValue password}) async {
    _session = null;
    _sessionStream.add(const Result<AuthSessionEntity?>.success(null));
    return const Result<void>.success(null);
  }
}

AuthSessionEntity _activeSession(String id, String email, String token) {
  final DateTime now = DateTime.now();
  return AuthSessionEntity(
    accessToken: token,
    refreshToken: 'refresh-$id',
    issuedAt: now,
    expiresAt: now.add(const Duration(hours: 2)),
    user: AuthUserEntity(
      id: id,
      email: email,
      displayName: 'Pilot',
      emailVerified: true,
      isAnonymous: false,
    ),
  );
}

AuthSessionEntity _expiredSession() {
  final DateTime now = DateTime.now();
  return AuthSessionEntity(
    accessToken: 'expired-token',
    refreshToken: 'expired-refresh',
    issuedAt: now.subtract(const Duration(days: 2)),
    expiresAt: now.subtract(const Duration(minutes: 1)),
    user: const AuthUserEntity(
      id: 'user-expired',
      email: 'expired@example.com',
      displayName: 'Expired',
      emailVerified: true,
      isAnonymous: false,
    ),
  );
}
