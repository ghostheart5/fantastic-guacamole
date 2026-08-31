import 'package:fantastic_guacamole/app/router/route_guards.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
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
            auth: AuthStateSnapshot(
              hasMockSignIn: false,
              hasAuthenticatedUser: false,
            ),
            mockLogin: MockLoginConfigState(
              email: 'tester@chronospark.local',
              password: '',
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read<bool>(authenticatedGuardProvider), isFalse);
  });

  test('tester access does not keep a signed-out QA session authenticated', () {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        intelligenceStateProvider.overrideWith(
          (Ref ref) => const IntelligenceState(
            environment: EnvironmentState(
              appName: 'ChronoSpark',
              appFlavor: 'qa',
              isProduction: false,
              isSupabaseConfigured: false,
            ),
            flags: FeatureFlagsState(
              verboseLogs: false,
              analyticsEnabled: false,
              mockMode: true,
              mockLoginEnabled: true,
              paywallDisabled: true,
              testerFullAccess: true,
            ),
            auth: AuthStateSnapshot(
              hasMockSignIn: false,
              hasAuthenticatedUser: false,
            ),
            mockLogin: MockLoginConfigState(email: '', password: ''),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read<bool>(authenticatedGuardProvider), isFalse);
  });

  test('authenticated identity is blocked while account storage is unsafe', () {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        intelligenceStateProvider.overrideWithValue(
          _authenticatedIntelligenceState,
        ),
        accountStorageScopeProvider.overrideWithValue(
          const AccountStorageScope.unsafe(),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read<bool>(authenticatedGuardProvider), isFalse);
  });

  test('authenticated identity opens after account storage is writable', () {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        intelligenceStateProvider.overrideWithValue(
          _authenticatedIntelligenceState,
        ),
        accountStorageScopeProvider.overrideWithValue(
          AccountStorageScope.authenticated('account-a'),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read<bool>(authenticatedGuardProvider), isTrue);
  });
}

const IntelligenceState _authenticatedIntelligenceState = IntelligenceState(
  environment: EnvironmentState(
    appName: 'ChronoSpark',
    appFlavor: 'qa',
    isProduction: false,
    isSupabaseConfigured: false,
  ),
  flags: FeatureFlagsState(
    verboseLogs: false,
    analyticsEnabled: false,
    mockMode: true,
    mockLoginEnabled: true,
    paywallDisabled: true,
    testerFullAccess: true,
  ),
  auth: AuthStateSnapshot(hasMockSignIn: true, hasAuthenticatedUser: false),
  mockLogin: MockLoginConfigState(email: '', password: ''),
);
