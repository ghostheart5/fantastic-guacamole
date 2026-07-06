import 'package:fantastic_guacamole/config/app_flavor.dart';
import 'package:flutter/foundation.dart';

abstract final class Env {
  static const String appName = 'ChronoSpark';
  static const String appFlavor = String.fromEnvironment(
    'CHRONOSPARK_APP_FLAVOR',
    defaultValue: 'prod',
  );
  static const bool enableVerboseLogs = bool.fromEnvironment(
    'CHRONOSPARK_VERBOSE_LOGS',
    defaultValue: false,
  );
  static const bool enableCrashReporting = bool.fromEnvironment(
    'CHRONOSPARK_ENABLE_CRASH_REPORTING',
    defaultValue: true,
  );
  static const bool enableAnalytics = bool.fromEnvironment(
    'CHRONOSPARK_ENABLE_ANALYTICS',
    defaultValue: false,
  );
  static const bool enableMockLogin = bool.fromEnvironment(
    'CHRONOSPARK_ENABLE_MOCK_LOGIN',
    defaultValue: false,
  );
  static const bool enableMockMode = bool.fromEnvironment(
    'CHRONOSPARK_ENABLE_MOCK_MODE',
    defaultValue: false,
  );
  static const bool enablePaywallDisabled = bool.fromEnvironment(
    'CHRONOSPARK_PAYWALL_DISABLED',
    defaultValue: false,
  );
  static const bool enableTesterFullAccess = bool.fromEnvironment(
    'CHRONOSPARK_ENABLE_TESTER_FULL_ACCESS',
    defaultValue: false,
  );
  static const String mockLoginEmail = String.fromEnvironment(
    'CHRONOSPARK_MOCK_LOGIN_EMAIL',
    defaultValue: 'mock@chronospark.app',
  );
  static const String mockLoginPassword = String.fromEnvironment(
    'CHRONOSPARK_MOCK_LOGIN_PASSWORD',
    defaultValue: '',
  );
  static const String receiptVerifyEndpoint = String.fromEnvironment(
    'CHRONOSPARK_RECEIPT_VERIFY_ENDPOINT',
    defaultValue: '',
  );
  static const String aiProxyEndpoint = String.fromEnvironment(
    'CHRONOSPARK_AI_PROXY_ENDPOINT',
    defaultValue: '',
  );
  static const String accountDeleteEndpoint = String.fromEnvironment(
    'CHRONOSPARK_ACCOUNT_DELETE_ENDPOINT',
    defaultValue: '',
  );
  static const String supabaseUrl = String.fromEnvironment(
    'CHRONOSPARK_SUPABASE_URL',
    defaultValue: '',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'CHRONOSPARK_SUPABASE_ANON_KEY',
    defaultValue: '',
  );
  static const bool enableCloudSync = bool.fromEnvironment(
    'CHRONOSPARK_ENABLE_CLOUD_SYNC',
    defaultValue: false,
  );
  static const String appLinksAndroidSha256 = String.fromEnvironment(
    'CHRONOSPARK_ANDROID_SHA256_CERT',
    defaultValue: '',
  );
  static const String appLinksIosTeamId = String.fromEnvironment(
    'CHRONOSPARK_IOS_TEAM_ID',
    defaultValue: '',
  );
  static const bool enforceProductionReadiness = bool.fromEnvironment(
    'CHRONOSPARK_ENFORCE_PROD_READINESS',
    defaultValue: false,
  );

  static AppFlavor get flavor => AppFlavor.parse(appFlavor);

  static bool resolveIsProduction(
    String flavor, {
    required bool isReleaseMode,
  }) {
    // Release artifacts always use production security rules. A missing or
    // mistyped flavor must never enable QA authentication or entitlement
    // bypasses in a distributable build.
    return isReleaseMode;
  }

  static bool resolveIsMockMode({
    required bool isProduction,
    required bool enableMockMode,
  }) {
    return !isProduction && enableMockMode;
  }

  static bool resolveIsPaywallDisabled({
    required bool isProduction,
    required bool enablePaywallDisabled,
    required bool isMockMode,
  }) {
    return !isProduction && (enablePaywallDisabled || isMockMode);
  }

  static bool resolveIsMockLoginEnabled({
    required bool isProduction,
    required bool isMockMode,
    required bool enableMockLogin,
  }) {
    return !isProduction && (isMockMode || enableMockLogin);
  }

  static bool resolveHasTesterFullAccess({
    required bool isProduction,
    required bool enableTesterFullAccess,
  }) {
    return !isProduction && enableTesterFullAccess;
  }

  static bool get isProduction =>
      resolveIsProduction(appFlavor, isReleaseMode: kReleaseMode);

  static bool get isMockMode => resolveIsMockMode(
    isProduction: isProduction,
    enableMockMode: enableMockMode,
  );

  static bool get isPaywallDisabled => resolveIsPaywallDisabled(
    isProduction: isProduction,
    enablePaywallDisabled: enablePaywallDisabled,
    isMockMode: isMockMode,
  );

  static bool get isMockLoginEnabled => resolveIsMockLoginEnabled(
    isProduction: isProduction,
    isMockMode: isMockMode,
    enableMockLogin: enableMockLogin,
  );

  static bool get hasTesterFullAccess => resolveHasTesterFullAccess(
    isProduction: isProduction,
    enableTesterFullAccess: enableTesterFullAccess,
  );

  static bool get isSupabaseConfigured =>
      supabaseUrl.trim().isNotEmpty && supabaseAnonKey.trim().isNotEmpty;

  static List<String> productionReadinessIssues({bool force = false}) {
    if (!force && !enforceProductionReadiness && !isProduction) {
      return const <String>[];
    }

    final List<String> issues = <String>[];
    if (enableCrashReporting == false) {
      issues.add('Crash reporting is disabled.');
    }
    if (enableMockLogin) {
      issues.add('Mock login bypass is enabled.');
    }
    if (enableMockMode) {
      issues.add('Global mock mode is enabled.');
    }
    if (enablePaywallDisabled) {
      issues.add('Paywall-disabled development override is enabled.');
    }
    if (enableTesterFullAccess) {
      issues.add('Tester full-access override is enabled.');
    }
    if (!isSupabaseConfigured) {
      issues.add('Supabase authentication is not configured.');
    }
    _validateHttpsEndpoint(
      receiptVerifyEndpoint,
      label: 'Receipt verification endpoint',
      issues: issues,
    );
    _validateHttpsEndpoint(
      aiProxyEndpoint,
      label: 'AI proxy endpoint',
      issues: issues,
    );
    _validateHttpsEndpoint(
      accountDeleteEndpoint,
      label: 'Account deletion endpoint',
      issues: issues,
    );
    if (appLinksAndroidSha256.trim().isEmpty) {
      issues.add('Android App Links SHA-256 fingerprint is not configured.');
    }
    if (appLinksIosTeamId.trim().isEmpty) {
      issues.add('iOS associated domains team ID is not configured.');
    }
    return issues;
  }

  static void _validateHttpsEndpoint(
    String value, {
    required String label,
    required List<String> issues,
  }) {
    final String endpoint = value.trim();
    if (endpoint.isEmpty) {
      issues.add('$label is not configured.');
      return;
    }
    final Uri? uri = Uri.tryParse(endpoint);
    if (uri == null || !uri.hasAuthority || uri.scheme != 'https') {
      issues.add('$label must be a valid HTTPS URL.');
    }
  }
}
