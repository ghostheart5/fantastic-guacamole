import 'package:fantastic_guacamole/data/services/unavailable_auth_service.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/state/services/auth_gateway_support.dart';
import 'package:fantastic_guacamole/state/state/intelligence_state.dart';
import 'package:flutter_test/flutter_test.dart';

IntelligenceState configuration({
  required bool local,
  bool mock = false,
  bool configured = false,
}) => IntelligenceState(
  environment: EnvironmentState(
    appName: 'ChronoSpark',
    appFlavor: 'production',
    isProduction: true,
    isSupabaseConfigured: configured,
    isLocalMode: local,
  ),
  flags: FeatureFlagsState(
    verboseLogs: false,
    analyticsEnabled: false,
    mockMode: mock,
    mockLoginEnabled: mock,
    paywallDisabled: false,
    testerFullAccess: false,
  ),
  auth: const AuthStateSnapshot(
    hasMockSignIn: false,
    hasAuthenticatedUser: false,
  ),
  mockLogin: const MockLoginConfigState(email: '', password: ''),
);

void main() {
  test(
    'explicit local mode selects real profile service before mock/backend branches',
    () async {
      final store = SecureStore(backend: InMemorySecureStoreBackend());
      final local = LocalProfileAuthService(
        store: store,
        onProfileDeleted: (_) async {},
        onBeforeClosed: (_) async {},
      );
      final selected = createAuthService(
        store: store,
        supabaseClient: null,
        intelligence: configuration(local: true, mock: true),
        localProfileService: local,
      );
      expect(selected, same(local));
      expect(selected.currentUser, isNull);
      final profile = await local.createProfile();
      expect(profile.isLocalProfile, isTrue);
      expect(profile.emailVerified, isFalse);
      await local.dispose();
    },
  );
  test(
    'missing local storage never silently falls back to mock or cloud auth',
    () {
      final service = createAuthService(
        store: SecureStore(backend: InMemorySecureStoreBackend()),
        supabaseClient: null,
        intelligence: configuration(local: true, mock: true, configured: true),
      );
      expect(service, isA<UnavailableAuthService>());
    },
  );
  test('cloud production still fails closed without a configured client', () {
    final store = SecureStore(backend: InMemorySecureStoreBackend());
    for (final configured in <bool>[false, true]) {
      expect(
        createAuthService(
          store: store,
          supabaseClient: null,
          intelligence: configuration(local: false, configured: configured),
        ),
        isA<UnavailableAuthService>(),
      );
    }
  });
}
