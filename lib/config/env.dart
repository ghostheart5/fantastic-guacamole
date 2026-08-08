import 'package:fantastic_guacamole/config/app_flavor.dart';
import 'package:fantastic_guacamole/ui/constants/app_urls.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

abstract final class Env {
  static const String appName = 'ChronoSpark';

  // Legal/support URLs have a single source of truth in [AppUrls], which is
  // what every live screen opens. These forward to it; they previously
  // declared chronospark.app paths that disagreed with the URLs actually used.
  static const String privacyPolicyUrl = AppUrls.privacy;
  static const String termsOfServiceUrl = AppUrls.terms;
  static const String supportUrl = AppUrls.support;
  static const String supportEmail = 'support@chronospark.app';
  static const String _appFlavorDefine = String.fromEnvironment(
    'CHRONOSPARK_APP_FLAVOR',
    defaultValue: 'prod',
  );
  static const bool _enableVerboseLogsDefine = bool.fromEnvironment(
    'CHRONOSPARK_VERBOSE_LOGS',
    defaultValue: false,
  );
  static const bool _enableCrashReportingDefine = bool.fromEnvironment(
    'CHRONOSPARK_ENABLE_CRASH_REPORTING',
    defaultValue: true,
  );
  static const bool _enableAnalyticsDefine = bool.fromEnvironment(
    'CHRONOSPARK_ENABLE_ANALYTICS',
    defaultValue: true,
  );
  static const bool _enableMockLoginDefine = bool.fromEnvironment(
    'CHRONOSPARK_ENABLE_MOCK_LOGIN',
    // Fail closed. Every other risk flag defaults to false; this one used to
    // default to true, which made MockAuthService (accepts any password) the
    // default for any build that was not BOTH release mode AND prod flavor.
    defaultValue: false,
  );
  static const bool _enableMockModeDefine = bool.fromEnvironment(
    'CHRONOSPARK_ENABLE_MOCK_MODE',
    defaultValue: false,
  );
  static const bool _enablePaywallDisabledDefine = bool.fromEnvironment(
    'CHRONOSPARK_PAYWALL_DISABLED',
    defaultValue: false,
  );
  static const bool _enableTesterFullAccessDefine = bool.fromEnvironment(
    'CHRONOSPARK_ENABLE_TESTER_FULL_ACCESS',
    defaultValue: false,
  );
  static const String _mockLoginEmailDefine = String.fromEnvironment(
    'CHRONOSPARK_MOCK_LOGIN_EMAIL',
    defaultValue: 'mock@chronospark.app',
  );
  static const String _mockLoginPasswordDefine = String.fromEnvironment(
    'CHRONOSPARK_MOCK_LOGIN_PASSWORD',
    defaultValue: 'ChronoSpark123!',
  );
  static const String _receiptVerifyEndpointOverrideDefine =
      String.fromEnvironment(
        'CHRONOSPARK_RECEIPT_VERIFY_ENDPOINT',
        defaultValue: '',
      );
  static const String _aiProxyEndpointDefine = String.fromEnvironment(
    'CHRONOSPARK_AI_PROXY_ENDPOINT',
    defaultValue: '',
  );
  static const String _accountDeleteEndpointDefine = String.fromEnvironment(
    'CHRONOSPARK_ACCOUNT_DELETE_ENDPOINT',
    defaultValue: '',
  );
  static const String _oauthRedirectUrlDefine = String.fromEnvironment(
    'CHRONOSPARK_OAUTH_REDIRECT_URL',
    defaultValue: 'https://chronospark.app/app/auth/callback',
  );
  static const String _githubOauthRedirectUrlDefine = String.fromEnvironment(
    'CHRONOSPARK_GITHUB_OAUTH_REDIRECT_URL',
    defaultValue: _oauthRedirectUrlDefine,
  );
  static const bool _enableRuntimeFeatureFlagsDefine = bool.fromEnvironment(
    'CHRONOSPARK_ENABLE_RUNTIME_FEATURE_FLAGS',
    defaultValue: true,
  );
  static const String _remoteConfigDefaultsJsonDefine = String.fromEnvironment(
    'CHRONOSPARK_REMOTE_CONFIG_JSON',
    defaultValue: '',
  );
  static const String _supabaseUrlDefine = String.fromEnvironment(
    'CHRONOSPARK_SUPABASE_URL',
    defaultValue: '',
  );
  static const String _supabaseAnonKeyDefine = String.fromEnvironment(
    'CHRONOSPARK_SUPABASE_ANON_KEY',
    defaultValue: '',
  );
  static const bool _enableCloudSyncDefine = bool.fromEnvironment(
    'CHRONOSPARK_ENABLE_CLOUD_SYNC',
    defaultValue: false,
  );
  static const String _appLinksAndroidSha256Define = String.fromEnvironment(
    'CHRONOSPARK_ANDROID_SHA256_CERT',
    defaultValue: '',
  );
  static const String _appLinksIosTeamIdDefine = String.fromEnvironment(
    'CHRONOSPARK_IOS_TEAM_ID',
    defaultValue: '',
  );
  static const bool _enforceProductionReadinessDefine = bool.fromEnvironment(
    'CHRONOSPARK_ENFORCE_PROD_READINESS',
    defaultValue: false,
  );

  static String get appFlavor =>
      _readRiskString('CHRONOSPARK_APP_FLAVOR', _appFlavorDefine);
  static bool get enableVerboseLogs =>
      _readRiskBool('CHRONOSPARK_VERBOSE_LOGS', _enableVerboseLogsDefine);
  static bool get enableCrashReporting => _readBool(
    'CHRONOSPARK_ENABLE_CRASH_REPORTING',
    _enableCrashReportingDefine,
  );
  static bool get enableAnalytics =>
      _readBool('CHRONOSPARK_ENABLE_ANALYTICS', _enableAnalyticsDefine);
  static bool get enableMockLogin =>
      _readRiskBool('CHRONOSPARK_ENABLE_MOCK_LOGIN', _enableMockLoginDefine);
  static bool get enableMockMode =>
      _readRiskBool('CHRONOSPARK_ENABLE_MOCK_MODE', _enableMockModeDefine);
  static bool get enablePaywallDisabled => _readRiskBool(
    'CHRONOSPARK_PAYWALL_DISABLED',
    _enablePaywallDisabledDefine,
  );
  static bool get enableTesterFullAccess => _readRiskBool(
    'CHRONOSPARK_ENABLE_TESTER_FULL_ACCESS',
    _enableTesterFullAccessDefine,
  );
  static String get mockLoginEmail =>
      _readString('CHRONOSPARK_MOCK_LOGIN_EMAIL', _mockLoginEmailDefine);
  static String get mockLoginPassword =>
      _readString('CHRONOSPARK_MOCK_LOGIN_PASSWORD', _mockLoginPasswordDefine);
  static String get _receiptVerifyEndpointOverride => _readString(
    'CHRONOSPARK_RECEIPT_VERIFY_ENDPOINT',
    _receiptVerifyEndpointOverrideDefine,
  );
  static String get aiProxyEndpoint =>
      _readString('CHRONOSPARK_AI_PROXY_ENDPOINT', _aiProxyEndpointDefine);
  static String get accountDeleteEndpoint => _readString(
    'CHRONOSPARK_ACCOUNT_DELETE_ENDPOINT',
    _accountDeleteEndpointDefine,
  );
  static String get oauthRedirectUrl =>
      _readString('CHRONOSPARK_OAUTH_REDIRECT_URL', _oauthRedirectUrlDefine);
  static String get githubOauthRedirectUrl => _readString(
    'CHRONOSPARK_GITHUB_OAUTH_REDIRECT_URL',
    _githubOauthRedirectUrlDefine,
  );
  static bool get enableRuntimeFeatureFlags => _readBool(
    'CHRONOSPARK_ENABLE_RUNTIME_FEATURE_FLAGS',
    _enableRuntimeFeatureFlagsDefine,
  );
  static String get remoteConfigDefaultsJson => _readString(
    'CHRONOSPARK_REMOTE_CONFIG_JSON',
    _remoteConfigDefaultsJsonDefine,
  );
  static String get supabaseUrl =>
      _readString('CHRONOSPARK_SUPABASE_URL', _supabaseUrlDefine);
  static String get supabaseAnonKey =>
      _readString('CHRONOSPARK_SUPABASE_ANON_KEY', _supabaseAnonKeyDefine);
  static bool get enableCloudSync =>
      _readBool('CHRONOSPARK_ENABLE_CLOUD_SYNC', _enableCloudSyncDefine);
  static String get appLinksAndroidSha256 => _readString(
    'CHRONOSPARK_ANDROID_SHA256_CERT',
    _appLinksAndroidSha256Define,
  );
  static String get appLinksIosTeamId =>
      _readString('CHRONOSPARK_IOS_TEAM_ID', _appLinksIosTeamIdDefine);
  static bool get enforceProductionReadiness => _readBool(
    'CHRONOSPARK_ENFORCE_PROD_READINESS',
    _enforceProductionReadinessDefine,
  );

  static AppFlavor get flavor => AppFlavor.parse(appFlavor);

  static bool resolveIsProduction(
    String flavor, {
    required bool isReleaseMode,
  }) {
    // Production hardening is enabled only for release + production flavor.
    // QA/testing release builds can still exercise tester-only access paths.
    //
    // Fail closed on an unrecognised flavor string in a release build: a typo
    // such as "production" (the enum value is "prod") previously parsed to
    // `development`, which silently disabled every production gate in a build
    // that was otherwise shipping. An unknown flavor in a release binary is a
    // misconfiguration, and the safe interpretation is "this is production".
    final AppFlavor? parsed = AppFlavor.tryParse(flavor);
    if (parsed == null) {
      return isReleaseMode;
    }
    return isReleaseMode && parsed.isProduction;
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

  static bool get isAiProxyConfigured =>
      resolveIsAiProxyConfigured(aiProxyEndpoint);

  static bool resolveIsAiProxyConfigured(String endpoint) {
    final String trimmed = endpoint.trim();
    if (trimmed.isEmpty) {
      return false;
    }
    final Uri? uri = Uri.tryParse(trimmed);
    return uri != null && uri.hasAuthority && uri.scheme == 'https';
  }

  static String get receiptVerifyEndpoint => resolveReceiptVerifyEndpoint(
    _receiptVerifyEndpointOverride,
    supabaseUrl: supabaseUrl,
  );

  static String resolveReceiptVerifyEndpoint(
    String configuredValue, {
    required String supabaseUrl,
  }) {
    final String configured = configuredValue.trim();
    if (configured.isNotEmpty) {
      return configured;
    }

    final Uri? supabaseUri = Uri.tryParse(supabaseUrl.trim());
    if (supabaseUri != null &&
        supabaseUri.hasAuthority &&
        supabaseUri.scheme == 'https') {
      return supabaseUri.resolve('/functions/v1/verify-receipt').toString();
    }

    return 'https://chronospark.app/verify-receipt';
  }

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
    if (enableRuntimeFeatureFlags && !isFirebaseFeatureFlagRuntimeReady) {
      issues.add('Runtime feature flags require Firebase to be configured.');
    }
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

  static bool get isFirebaseFeatureFlagRuntimeReady =>
      !isMockMode && enableRuntimeFeatureFlags && _hasFirebaseRuntime;

  static bool get _hasFirebaseRuntime => true;

  static String _readString(String key, String fallback) {
    final String? value = _dotenvValue(key);
    if (value != null && value.trim().isNotEmpty) {
      return value.trim();
    }
    return fallback;
  }

  static bool _readBool(String key, bool fallback) {
    final String? value = _dotenvValue(key);
    if (value == null) {
      return fallback;
    }
    switch (value.trim().toLowerCase()) {
      case 'true':
      case '1':
      case 'yes':
      case 'on':
        return true;
      case 'false':
      case '0':
      case 'no':
      case 'off':
        return false;
      default:
        return fallback;
    }
  }

  static String? _dotenvValue(String key) {
    try {
      return dotenv.maybeGet(key);
    } on Object {
      return null;
    }
  }

  /// Reads a security-relevant flag.
  ///
  /// In a release build the bundled `.env` is ignored entirely and only the
  /// compile-time `--dart-define` is honoured. `.env` ships inside the app
  /// bundle (see `pubspec.yaml` assets), so treating it as authoritative for
  /// risk flags meant a stray `CHRONOSPARK_ENABLE_MOCK_LOGIN=true` — or a
  /// repackaged bundle — could enable mock authentication in a shipped binary,
  /// and a `--dart-define` could not override it. Debug/profile builds keep the
  /// `.env` convenience.
  static bool _readRiskBool(String key, bool fallback) {
    if (kReleaseMode) {
      return fallback;
    }
    return _readBool(key, fallback);
  }

  /// String counterpart of [_readRiskBool]. Used for the app flavor, which
  /// gates every other production check.
  static String _readRiskString(String key, String fallback) {
    if (kReleaseMode) {
      return fallback;
    }
    return _readString(key, fallback);
  }
}
