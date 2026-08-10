import 'dart:async';

import 'package:fantastic_guacamole/features/auth/application/auth_providers.dart';
import 'package:fantastic_guacamole/features/auth/application/auth_state.dart';
import 'package:fantastic_guacamole/features/auth/domain/core/result.dart';
import 'package:fantastic_guacamole/features/auth/domain/entities/auth_session_entity.dart';
import 'package:fantastic_guacamole/features/auth/domain/entities/auth_user_entity.dart';
import 'package:fantastic_guacamole/features/auth/domain/repositories/auth_repository.dart';
import 'package:fantastic_guacamole/features/auth/domain/value_objects/email_address.dart';
import 'package:fantastic_guacamole/features/auth/domain/value_objects/password_value.dart';
import 'package:fantastic_guacamole/features/monetization/integration/monetization_actions_compat.dart';
import 'package:fantastic_guacamole/features/monetization/providers/monetization_compat_providers.dart';
import 'package:fantastic_guacamole/state/providers/app_integration_actions_provider.dart';
import 'package:fantastic_guacamole/state/providers/si_pipeline_provider.dart';
import 'package:fantastic_guacamole/state/providers/supabase_backend_provider.dart';
import 'package:fantastic_guacamole/state/providers/sync_provider.dart';
import 'package:fantastic_guacamole/state/services/app_integration_actions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('provider behavior matrix', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('auth: initial empty session resolves to unauthenticated', () async {
      final _MatrixAuthRepository repository = _MatrixAuthRepository(
        initialSession: null,
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
    });

    test('auth: sign-in transitions to authenticated success state', () async {
      final _MatrixAuthRepository repository = _MatrixAuthRepository(
        initialSession: null,
      );
      final ProviderContainer container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      await container
          .read(authControllerProvider.notifier)
          .signInWithEmail(
            email: 'matrix@example.com',
            password: 'Password123',
          );

      final AuthState state = container.read(authControllerProvider);
      expect(state.status, AuthStatus.authenticated);
      expect(state.user?.email, 'matrix@example.com');
    });

    test('auth: invalid login input transitions to error state', () async {
      final _MatrixAuthRepository repository = _MatrixAuthRepository(
        initialSession: null,
      );
      final ProviderContainer container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      await container.read(authControllerProvider.notifier).restoreSession();

      await container
          .read(authControllerProvider.notifier)
          .signInWithEmail(email: 'not-an-email', password: 'weak');

      final AuthState state = container.read(authControllerProvider);
      expect(state.status, AuthStatus.error);
      expect(state.failure, isNotNull);
    });

    test(
      'auth: sign-out transitions authenticated to unauthenticated',
      () async {
        final _MatrixAuthRepository repository = _MatrixAuthRepository(
          initialSession: _matrixSession(
            'stateful@example.com',
            'token-stateful',
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
      },
    );

    test('sync: error message notifier starts as null', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(syncErrorMessageProvider), isNull);
    });

    test('sync: error message notifier transitions null warning null', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(syncErrorMessageProvider.notifier).set('queue stalled');
      expect(container.read(syncErrorMessageProvider), 'queue stalled');

      container.read(syncErrorMessageProvider.notifier).set(null);
      expect(container.read(syncErrorMessageProvider), isNull);
    });

    test(
      'sync: actions fallback safely when sync service is unavailable',
      () async {
        final ProviderContainer container = ProviderContainer(
          overrides: [
            syncServiceProvider.overrideWithValue(null),
            monetizationActionsCompatProvider.overrideWithValue(
              const _FakeMonetizationActionsCompat(),
            ),
          ],
        );
        addTearDown(container.dispose);

        final AppIntegrationActions actions = container.read(
          appIntegrationActionsProvider,
        );
        expect(await actions.syncToCloud(), isFalse);
        expect(await actions.syncDelta(), isFalse);
        expect(await actions.restoreFromCloud(), isFalse);
      },
    );

    test('si pipeline: banner emits healthy success surface', () {
      const AppIntegrationSnapshot snapshot = AppIntegrationSnapshot(
        currentUserId: 'user_abcdef',
        supabaseHealth: SupabaseBackendHealth(
          configured: true,
          initialized: true,
          authenticated: true,
          databaseReachable: true,
          storageReachable: true,
          realtimeConfigured: true,
          badge: SupabaseHealthBadge.healthy,
          message: 'ok',
        ),
        syncErrorMessage: null,
        offlineQueueCount: 0,
        monetizationStatus: MonetizationStatusSnapshot(
          planId: 'premium',
          isPremium: true,
          isActive: true,
          walletBalance: 100,
          stackType: MonetizationStackType.feature,
        ),
      );

      final String banner = buildIntegrationSurfaceSnapshot(snapshot);
      expect(banner, contains('SUPABASE HEALTHY'));
      expect(banner, contains('SYNC OK'));
    });

    test('si pipeline: banner emits warning surface for stale sync state', () {
      const AppIntegrationSnapshot snapshot = AppIntegrationSnapshot(
        currentUserId: null,
        supabaseHealth: SupabaseBackendHealth(
          configured: true,
          initialized: true,
          authenticated: false,
          databaseReachable: false,
          storageReachable: false,
          realtimeConfigured: false,
          badge: SupabaseHealthBadge.connectivityIssue,
          message: 'network',
        ),
        syncErrorMessage: 'stale',
        offlineQueueCount: 2,
        monetizationStatus: MonetizationStatusSnapshot(
          planId: '__none__',
          isPremium: false,
          isActive: false,
          walletBalance: 0,
          stackType: MonetizationStackType.legacy,
        ),
      );

      final String banner = buildIntegrationSurfaceSnapshot(snapshot);
      expect(banner, contains('SUPABASE CONNECTIVITY ISSUE'));
      expect(banner, contains('SYNC WARN'));
      expect(banner, contains('Q 2'));
    });

    test('si pipeline: stale warning clears after refresh success', () async {
      final ProviderContainer container = ProviderContainer(
        overrides: [
          syncServiceProvider.overrideWithValue(null),
          monetizationActionsCompatProvider.overrideWithValue(
            const _FakeMonetizationActionsCompat(),
          ),
        ],
      );
      addTearDown(container.dispose);

      container.read(syncErrorMessageProvider.notifier).set('stale');
      final AppIntegrationActions actions = container.read(
        appIntegrationActionsProvider,
      );

      final AppIntegrationSnapshot staleSnapshot = await actions
          .fetchIntegrationSnapshot();
      expect(staleSnapshot.syncErrorMessage, 'stale');

      container.read(syncErrorMessageProvider.notifier).set(null);
      final AppIntegrationSnapshot refreshedSnapshot = await actions
          .fetchIntegrationSnapshot();
      expect(refreshedSnapshot.syncErrorMessage, isNull);
    });

    test('si pipeline: banner keeps user id shortening stable', () {
      const AppIntegrationSnapshot snapshot = AppIntegrationSnapshot(
        currentUserId: 'abcdef1234567890',
        supabaseHealth: SupabaseBackendHealth(
          configured: true,
          initialized: true,
          authenticated: true,
          databaseReachable: true,
          storageReachable: true,
          realtimeConfigured: true,
          badge: SupabaseHealthBadge.healthy,
          message: 'ok',
        ),
        syncErrorMessage: null,
        offlineQueueCount: 1,
        monetizationStatus: MonetizationStatusSnapshot(
          planId: 'plus',
          isPremium: true,
          isActive: true,
          walletBalance: 4,
          stackType: MonetizationStackType.feature,
        ),
      );

      final String banner = buildIntegrationSurfaceSnapshot(snapshot);
      expect(banner.startsWith('USER abcdef'), isTrue);
    });
  });
}

class _MatrixAuthRepository implements AuthRepository {
  _MatrixAuthRepository({required AuthSessionEntity? initialSession})
    : _session = initialSession;

  final StreamController<Result<AuthSessionEntity?>> _stream =
      StreamController<Result<AuthSessionEntity?>>.broadcast();
  AuthSessionEntity? _session;

  @override
  Stream<Result<AuthSessionEntity?>> watchSession() => _stream.stream;

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
    _session = _matrixSession(email.value, 'token-login');
    _stream.add(Result<AuthSessionEntity?>.success(_session));
    return Result<AuthSessionEntity?>.success(_session);
  }

  @override
  Future<Result<AuthSessionEntity?>> signUpWithEmail({
    required EmailAddress email,
    required PasswordValue password,
  }) async {
    _session = _matrixSession(email.value, 'token-signup');
    _stream.add(Result<AuthSessionEntity?>.success(_session));
    return Result<AuthSessionEntity?>.success(_session);
  }

  @override
  Future<Result<AuthSessionEntity?>> signInWithGoogle() async {
    _session = _matrixSession('google@example.com', 'token-google');
    _stream.add(Result<AuthSessionEntity?>.success(_session));
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
    _session = _matrixSession('refresh@example.com', 'token-refresh');
    _stream.add(Result<AuthSessionEntity?>.success(_session));
    return const Result<void>.success(null);
  }

  @override
  Future<Result<void>> signOut() async {
    _session = null;
    _stream.add(const Result<AuthSessionEntity?>.success(null));
    return const Result<void>.success(null);
  }

  @override
  Future<Result<void>> deleteAccount({required PasswordValue password}) async {
    _session = null;
    _stream.add(const Result<AuthSessionEntity?>.success(null));
    return const Result<void>.success(null);
  }
}

AuthSessionEntity _matrixSession(String email, String token) {
  final DateTime now = DateTime.now();
  return AuthSessionEntity(
    accessToken: token,
    refreshToken: 'refresh-$token',
    expiresAt: now.add(const Duration(hours: 1)),
    issuedAt: now,
    user: AuthUserEntity(
      id: 'id-$token',
      email: email,
      displayName: 'Matrix User',
      emailVerified: true,
      isAnonymous: false,
    ),
  );
}

class _FakeMonetizationActionsCompat implements MonetizationActionsCompat {
  const _FakeMonetizationActionsCompat();

  @override
  MonetizationStackType get stackType => MonetizationStackType.feature;

  @override
  Future<List<MonetizationCreditOption>> fetchCreditOptions() async {
    return const <MonetizationCreditOption>[];
  }

  @override
  Future<List<MonetizationPlanOption>> fetchPlanOptions() async {
    return const <MonetizationPlanOption>[];
  }

  @override
  Future<MonetizationStatusSnapshot> fetchStatus() async {
    return const MonetizationStatusSnapshot(
      planId: '__none__',
      isPremium: false,
      isActive: false,
      walletBalance: 0,
      stackType: MonetizationStackType.feature,
    );
  }

  @override
  Future<MonetizationPurchaseOutcome> purchaseCreditsByProductId(
    String productId,
  ) async {
    return MonetizationPurchaseOutcome(
      success: true,
      productId: productId,
      message: 'ok',
    );
  }

  @override
  Future<MonetizationPurchaseOutcome> purchaseSubscriptionByProductId(
    String productId,
  ) async {
    return MonetizationPurchaseOutcome(
      success: true,
      productId: productId,
      message: 'ok',
    );
  }

  @override
  Future<MonetizationPurchaseOutcome> restorePurchases() async {
    return const MonetizationPurchaseOutcome(
      success: true,
      productId: '__restore__',
      message: 'restored',
    );
  }
}
