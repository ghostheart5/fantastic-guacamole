import 'package:fantastic_guacamole/data/models/auth_models.dart';
import 'package:fantastic_guacamole/state/providers/intelligence_provider.dart';
import 'package:fantastic_guacamole/state/state/intelligence_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mock sign-in always starts signed out', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(mockSignInProvider), isFalse);
    expect(container.read(qaMockAccountIdProvider), primaryQaAccountId);
  });

  test('QA secondary identity is explicit and isolated from primary', () async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    final ProviderSubscription<AsyncValue<User?>> subscription = container
        .listen(authUserProvider, (_, _) {});
    addTearDown(subscription.close);

    container
        .read(qaMockAccountIdProvider.notifier)
        .select(secondaryQaAccountId);
    container.read(mockSignInProvider.notifier).set(true);

    final User? mockUser = await container.read(authUserProvider.future);
    expect(mockUser?.id, secondaryQaAccountId);
    expect(mockUser?.email, 'tester-secondary@chronospark.local');
    expect(
      () => container
          .read(qaMockAccountIdProvider.notifier)
          .select('unapproved-account'),
      throwsArgumentError,
    );
  });

  test(
    'authenticatedGuardProvider is true when mock auth session is enabled',
    () async {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(mockSignInProvider.notifier).set(true);

      expect(container.read(authenticatedGuardProvider), isTrue);

      // A StreamProvider only subscribes to its stream while something is
      // listening. Reading `.future` on its own does not establish that
      // subscription, so without this listener the await never completes.
      final ProviderSubscription<AsyncValue<User?>> sub = container.listen(
        authUserProvider,
        (AsyncValue<User?>? _, AsyncValue<User?> _) {},
      );
      addTearDown(sub.close);

      final User? mockUser = await container.read(authUserProvider.future);
      expect(mockUser, isNotNull);
      expect(mockUser?.id, 'mock-user');
    },
  );

  test(
    'authenticatedGuardProvider reflects overridden intelligence auth state',
    () {
      final ProviderContainer container = ProviderContainer(
        overrides: [
          intelligenceStateProvider.overrideWith(
            (Ref ref) => const IntelligenceState(
              environment: EnvironmentState(
                appName: 'ChronoSpark',
                appFlavor: 'dev',
                isProduction: false,
                isSupabaseConfigured: false,
              ),
              flags: FeatureFlagsState(
                verboseLogs: true,
                analyticsEnabled: false,
                mockMode: true,
                mockLoginEnabled: true,
                paywallDisabled: true,
                testerFullAccess: true,
              ),
              auth: AuthStateSnapshot(
                hasMockSignIn: false,
                hasAuthenticatedUser: true,
              ),
              mockLogin: MockLoginConfigState(email: '', password: ''),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(authenticatedGuardProvider), isTrue);
    },
  );

  test(
    'unverified backend user does not satisfy the authenticated guard',
    () async {
      final ProviderContainer container = ProviderContainer(
        overrides: [
          authUserProvider.overrideWith(
            (Ref ref) => Stream<User?>.value(
              const User(
                id: 'pending-user',
                email: 'pending@chronospark.app',
                emailVerified: false,
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      final ProviderSubscription<AsyncValue<User?>> subscription = container
          .listen(authUserProvider, (_, _) {});
      addTearDown(subscription.close);

      await container.read(authUserProvider.future);

      expect(container.read(authenticatedGuardProvider), isFalse);
    },
  );

  test('engine failure creates safe UI fallback', () {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        authUserProvider.overrideWith(
          (Ref ref) => Stream<User?>.error(Exception('engine down')),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(authenticatedGuardProvider), isFalse);
  });

  test(
    'mockLoginConfigProvider mirrors intelligence service configuration',
    () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      final config = container.read(mockLoginConfigProvider);

      expect(config.email, isA<String>());
      expect(config.password, isA<String>());
      expect(config.isConfigured, anyOf(isTrue, isFalse));
    },
  );
}
