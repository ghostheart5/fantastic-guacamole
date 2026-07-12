import 'package:fantastic_guacamole/app/router/route_guards.dart';
import 'package:fantastic_guacamole/state/providers/intelligence_provider.dart'
    show intelligenceStateProvider;
import 'package:fantastic_guacamole/state/state/intelligence_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('available mock login does not authenticate before sign in', () {
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
              verboseLogs: false,
              analyticsEnabled: false,
              mockMode: false,
              mockLoginEnabled: true,
              paywallDisabled: false,
              testerFullAccess: false,
            ),
            auth: AuthStateSnapshot(hasMockSession: false, hasAuthenticatedUser: false),
            mockLogin: MockLoginConfigState(
              email: 'mock@chronospark.app',
              password: 'ChronoSpark123!',
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read<bool>(authenticatedGuardProvider), isFalse);
  });
}
