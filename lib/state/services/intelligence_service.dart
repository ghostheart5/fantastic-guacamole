import 'package:fantastic_guacamole/config/env.dart';
import 'package:fantastic_guacamole/state/state/intelligence_state.dart';

class IntelligenceService {
  const IntelligenceService();

  IntelligenceState fromRuntime({
    required bool hasMockSignIn,
    required bool hasAuthenticatedUser,
  }) {
    final bool isProduction = Env.isProduction;
    final bool isMockMode = Env.resolveIsMockMode(
      isProduction: isProduction,
      enableMockMode: Env.enableMockMode,
    );
    final bool isPaywallDisabled = Env.resolveIsPaywallDisabled(
      isProduction: isProduction,
      enablePaywallDisabled: Env.enablePaywallDisabled,
      isMockMode: isMockMode,
    );
    final bool isMockLoginEnabled = Env.resolveIsMockLoginEnabled(
      isProduction: isProduction,
      isMockMode: isMockMode,
      enableMockLogin: Env.enableMockLogin,
    );
    final bool hasTesterFullAccess = Env.resolveHasTesterFullAccess(
      isProduction: isProduction,
      enableTesterFullAccess: Env.enableTesterFullAccess,
    );
    final bool effectiveMockTesting = !isProduction && hasMockSignIn;
    final bool effectivePaywallDisabled =
        isPaywallDisabled || effectiveMockTesting;
    final bool effectiveTesterFullAccess =
        hasTesterFullAccess || isMockMode || effectivePaywallDisabled;

    return IntelligenceState(
      environment: EnvironmentState(
        appName: Env.appName,
        appFlavor: Env.appFlavor,
        isProduction: isProduction,
        isSupabaseConfigured: Env.isSupabaseConfigured,
      ),
      flags: FeatureFlagsState(
        verboseLogs: Env.enableVerboseLogs,
        analyticsEnabled: Env.enableAnalytics,
        mockMode: isMockMode,
        mockLoginEnabled: isMockLoginEnabled,
        paywallDisabled: effectivePaywallDisabled,
        testerFullAccess: effectiveTesterFullAccess,
      ),
      auth: AuthStateSnapshot(
        hasMockSignIn: hasMockSignIn,
        hasAuthenticatedUser: hasAuthenticatedUser,
      ),
      mockLogin: mockLoginConfig(),
    );
  }

  IntelligenceState environmentOnly() {
    return fromRuntime(hasMockSignIn: false, hasAuthenticatedUser: false);
  }

  MockLoginConfigState mockLoginConfig() {
    return const MockLoginConfigState(
      email: 'tester@chronospark.local',
      password: '',
    );
  }

  List<String> productionReadinessIssues({
    bool force = false,
    bool? firebaseInitialized,
    String? firebaseProjectId,
  }) {
    return Env.productionReadinessIssues(
      force: force,
      firebaseInitialized: firebaseInitialized,
      firebaseProjectId: firebaseProjectId,
    );
  }
}
