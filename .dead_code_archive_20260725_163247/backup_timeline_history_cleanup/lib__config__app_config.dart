import 'package:fantastic_guacamole/config/app_flavor.dart';
import 'package:fantastic_guacamole/config/env.dart';

class AppConfig {
  const AppConfig({
    required this.appName,
    required this.flavor,
    required this.verboseLogs,
    required this.crashReportingEnabled,
    required this.analyticsEnabled,
    required this.mockMode,
    required this.mockLoginEnabled,
    required this.paywallDisabled,
    required this.testerFullAccess,
    required this.cloudSyncEnabled,
    required this.supabaseConfigured,
  });

  final String appName;
  final AppFlavor flavor;
  final bool verboseLogs;
  final bool crashReportingEnabled;
  final bool analyticsEnabled;
  final bool mockMode;
  final bool mockLoginEnabled;
  final bool paywallDisabled;
  final bool testerFullAccess;
  final bool cloudSyncEnabled;
  final bool supabaseConfigured;

  bool get isProduction => Env.isProduction;

  factory AppConfig.fromEnv() {
    return AppConfig(
      appName: Env.appName,
      flavor: Env.flavor,
      verboseLogs: Env.enableVerboseLogs,
      crashReportingEnabled: Env.enableCrashReporting,
      analyticsEnabled: Env.enableAnalytics,
      mockMode: Env.isMockMode,
      mockLoginEnabled: Env.isMockLoginEnabled,
      paywallDisabled: Env.isPaywallDisabled,
      testerFullAccess: Env.hasTesterFullAccess,
      cloudSyncEnabled: Env.enableCloudSync,
      supabaseConfigured: Env.isSupabaseConfigured,
    );
  }
}

// Transitional compatibility for paywall implementations that are not yet
// constructed through Riverpod. UI should prefer appAccessProvider.
bool get paywallTestingMode => AppConfig.fromEnv().paywallDisabled;
