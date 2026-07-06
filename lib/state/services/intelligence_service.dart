import 'package:fantastic_guacamole/config/env.dart';
import 'package:fantastic_guacamole/state/state/intelligence_state.dart';

class IntelligenceService {
  const IntelligenceService();

  IntelligenceState fromRuntime({
    required bool hasMockSession,
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
    final bool effectiveMockTesting = !isProduction && hasMockSession;
    final bool effectivePaywallDisabled = isPaywallDisabled || effectiveMockTesting;
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
        hasMockSession: hasMockSession,
        hasAuthenticatedUser: hasAuthenticatedUser,
      ),
      mockLogin: mockLoginConfig(),
    );
  }

  IntelligenceState environmentOnly() {
    return fromRuntime(hasMockSession: false, hasAuthenticatedUser: false);
  }

  MockLoginConfigState mockLoginConfig() {
    return MockLoginConfigState(email: Env.mockLoginEmail.trim(), password: Env.mockLoginPassword);
  }

  List<String> productionReadinessIssues({bool force = false}) {
    return Env.productionReadinessIssues(force: force);
  }
}
