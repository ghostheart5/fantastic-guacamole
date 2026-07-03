import 'package:flutter/foundation.dart';

class Env {
  static const String appName = 'ChronoSpark';
  static const String appFlavor = String.fromEnvironment(
    'CHRONOSPARK_APP_FLAVOR',
    defaultValue: 'dev',
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
    defaultValue: true,
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
    defaultValue: 'B9:09:A5:09:56:08:DE:F7:91:EF:B5:A1:C0:D8:28:54:15:8B:45:0A:82:BF:9F:B2:90:84:BB:78:4A:52:17:2F',
  );
  static const String appLinksIosTeamId = String.fromEnvironment(
    'CHRONOSPARK_IOS_TEAM_ID',
    defaultValue: 'REPLACE_WITH_TEAM_ID',
  );
  static const bool enforceProductionReadiness = bool.fromEnvironment(
    'CHRONOSPARK_ENFORCE_PROD_READINESS',
    defaultValue: false,
  );

  static bool resolveIsProduction(String flavor, {required bool isReleaseMode}) {
    return isReleaseMode && flavor.toLowerCase() == 'prod';
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
    return !isProduction || enableTesterFullAccess;
  }

  static bool get isProduction => resolveIsProduction(appFlavor, isReleaseMode: kReleaseMode);

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
    if (enableAnalytics == false) {
      issues.add('Analytics is disabled.');
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
    final String endpoint = receiptVerifyEndpoint.trim();
    if (endpoint.isEmpty) {
      issues.add('Receipt verification endpoint is not configured.');
    } else {
      final Uri? uri = Uri.tryParse(endpoint);
      if (uri == null || !uri.hasAuthority || uri.scheme != 'https') {
        issues.add('Receipt verification endpoint must be a valid HTTPS URL.');
      }
    }
    final String aiEndpoint = aiProxyEndpoint.trim();
    if (aiEndpoint.isEmpty) {
      issues.add('AI proxy endpoint is not configured.');
    } else {
      final Uri? uri = Uri.tryParse(aiEndpoint);
      if (uri == null || !uri.hasAuthority || uri.scheme != 'https') {
        issues.add('AI proxy endpoint must be a valid HTTPS URL.');
      }
    }
    if (appLinksAndroidSha256.contains('REPLACE_WITH_')) {
      issues.add('Android App Links SHA-256 fingerprint is a placeholder.');
    }
    if (appLinksIosTeamId.contains('REPLACE_WITH_')) {
      issues.add('iOS associated domains team ID is a placeholder.');
    }
    return issues;
  }
}
