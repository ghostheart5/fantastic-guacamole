import 'package:fantastic_guacamole/config/app_flavor.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

abstract final class Env {
  static const String appName = 'ChronoSpark';
  static const String publicWebsiteUrl =
      'https://ghostheart5.github.io/fantastic-guacamole';
  static const String privacyPolicyUrl = '$publicWebsiteUrl/privacy/';
  static const String termsOfServiceUrl = '$publicWebsiteUrl/terms/';
  static const String supportUrl = '$publicWebsiteUrl/support/';
  static const String deleteAccountUrl = '$publicWebsiteUrl/delete-account/';
  static const String productionAppLinkHost = 'chronospark.app';
  static const String productionAppLinkOrigin =
      'https://$productionAppLinkHost';
  static const String productionAuthCallbackUrl =
      '$productionAppLinkOrigin/app/auth/callback';
  static const String customSchemeAuthCallbackUrl =
      'chronospark://auth-callback';
  static const String _appFlavorDefine = String.fromEnvironment(
    'CHRONOSPARK_APP_FLAVOR',
    defaultValue: 'dev',
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
    defaultValue: customSchemeAuthCallbackUrl,
  );
  static const String _passwordRecoveryRedirectUrlDefine =
      String.fromEnvironment(
        'CHRONOSPARK_PASSWORD_RECOVERY_REDIRECT_URL',
        defaultValue: _oauthRedirectUrlDefine,
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
  static const bool _enableSupabaseAutoQueueFlushDefine = bool.fromEnvironment(
    'CHRONOSPARK_ENABLE_SUPABASE_AUTO_QUEUE_FLUSH',
    defaultValue: false,
  );
  static const bool _enableLegacyRoutineEntryPointsDefine =
      bool.fromEnvironment(
        'CHRONOSPARK_ENABLE_LEGACY_ROUTINE_ENTRY_POINTS',
        defaultValue: false,
      );
  static const bool _enableCompletionEventTrackingDefine = bool.fromEnvironment(
    'CHRONOSPARK_ENABLE_COMPLETION_EVENT_TRACKING',
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
  static const bool _maestroModeDefine = bool.fromEnvironment(
    'CHRONOSPARK_MAESTRO_MODE',
    defaultValue: false,
  );

  static String get appFlavor =>
      _readString('CHRONOSPARK_APP_FLAVOR', _appFlavorDefine);
  static bool get enableVerboseLogs =>
      _readBool('CHRONOSPARK_VERBOSE_LOGS', _enableVerboseLogsDefine);
  static bool get enableCrashReporting => _readBool(
    'CHRONOSPARK_ENABLE_CRASH_REPORTING',
    _enableCrashReportingDefine,
  );
  static bool get enableAnalytics =>
      _readBool('CHRONOSPARK_ENABLE_ANALYTICS', _enableAnalyticsDefine);
  static bool get enableMockLogin =>
      _readBool('CHRONOSPARK_ENABLE_MOCK_LOGIN', _enableMockLoginDefine);
  static bool get enableMockMode =>
      _readBool('CHRONOSPARK_ENABLE_MOCK_MODE', _enableMockModeDefine);
  static bool get enablePaywallDisabled =>
      _readBool('CHRONOSPARK_PAYWALL_DISABLED', _enablePaywallDisabledDefine);
  static bool get enableTesterFullAccess => _readBool(
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
    resolveAccountDeleteEndpoint(
      _accountDeleteEndpointDefine,
      supabaseUrl: supabaseUrl,
    ),
  );
  static String get oauthRedirectUrl =>
      _readString('CHRONOSPARK_OAUTH_REDIRECT_URL', _oauthRedirectUrlDefine);
  static String get passwordRecoveryRedirectUrl => _readString(
    'CHRONOSPARK_PASSWORD_RECOVERY_REDIRECT_URL',
    _passwordRecoveryRedirectUrlDefine,
  );
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
  static bool get enableSupabaseAutoQueueFlush => _readBool(
    'CHRONOSPARK_ENABLE_SUPABASE_AUTO_QUEUE_FLUSH',
    _enableSupabaseAutoQueueFlushDefine,
  );
  static bool get enableLegacyRoutineEntryPoints => _readBool(
    'CHRONOSPARK_ENABLE_LEGACY_ROUTINE_ENTRY_POINTS',
    _enableLegacyRoutineEntryPointsDefine,
  );
  static bool get enableCompletionEventTracking => _readBool(
    'CHRONOSPARK_ENABLE_COMPLETION_EVENT_TRACKING',
    _enableCompletionEventTrackingDefine,
  );
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
  static bool get maestroMode =>
      !kReleaseMode &&
      !isProduction &&
      _readBool('CHRONOSPARK_MAESTRO_MODE', _maestroModeDefine);

  static AppFlavor get flavor => AppFlavor.parse(appFlavor);

  static bool resolveIsProduction(
    String flavor, {
    required bool isReleaseMode,
  }) {
    // Production hardening is enabled only for release + production flavor.
    // QA/testing release builds can still exercise tester-only access paths.
    return isReleaseMode && AppFlavor.parse(flavor).isProduction;
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
    return !kReleaseMode && !isProduction && (isMockMode || enableMockLogin);
  }

  static bool resolveHasTesterFullAccess({
    required bool isProduction,
    required bool enableTesterFullAccess,
  }) {
    return !kReleaseMode && !isProduction && enableTesterFullAccess;
  }

  static bool get isProduction =>
      resolveIsProduction(appFlavor, isReleaseMode: kReleaseMode);

  static bool get hasSupabaseCredentialsPresent =>
      supabaseUrl.trim().isNotEmpty && supabaseAnonKey.trim().isNotEmpty;

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

  static bool get isSupabaseConfigured => resolveIsSupabaseConfigured(
    supabaseUrl: supabaseUrl,
    supabaseAnonKey: supabaseAnonKey,
  );

  static bool resolveIsSupabaseConfigured({
    required String supabaseUrl,
    required String supabaseAnonKey,
  }) {
    final String url = supabaseUrl.trim();
    final String key = supabaseAnonKey.trim();
    if (url.isEmpty || key.isEmpty) {
      return false;
    }
    final Uri? uri = Uri.tryParse(url);
    return uri != null && uri.hasAuthority && uri.scheme == 'https';
  }

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

  static String resolveAccountDeleteEndpoint(
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
      return supabaseUri.resolve('/functions/v1/account-delete').toString();
    }

    return '';
  }

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
      return supabaseUri
          .resolve('/functions/v1/monetization-verify')
          .toString();
    }

    return '';
  }

  static bool resolveIsAllowedAuthRedirect(
    String value, {
    bool requireHttpsAppLink = false,
  }) {
    final Uri? uri = Uri.tryParse(value.trim());
    if (uri == null || uri.userInfo.isNotEmpty) {
      return false;
    }

    final bool hasUnexpectedPayload =
        uri.query.isNotEmpty || uri.fragment.isNotEmpty;
    if (hasUnexpectedPayload) {
      return false;
    }

    if (uri.scheme == 'chronospark') {
      return !requireHttpsAppLink &&
          uri.host == 'auth-callback' &&
          (uri.path.isEmpty || uri.path == '/');
    }

    return uri.scheme == 'https' &&
        uri.host == productionAppLinkHost &&
        uri.path == '/app/auth/callback';
  }

  static bool resolveIsTrustedEdgeFunctionEndpoint({
    required String endpoint,
    required String supabaseUrl,
    required String functionName,
  }) {
    final Uri? endpointUri = Uri.tryParse(endpoint.trim());
    final Uri? supabaseUri = Uri.tryParse(supabaseUrl.trim());
    if (endpointUri == null ||
        supabaseUri == null ||
        endpointUri.scheme != 'https' ||
        supabaseUri.scheme != 'https' ||
        !endpointUri.hasAuthority ||
        !supabaseUri.hasAuthority ||
        endpointUri.userInfo.isNotEmpty ||
        supabaseUri.userInfo.isNotEmpty ||
        endpointUri.query.isNotEmpty ||
        endpointUri.fragment.isNotEmpty) {
      return false;
    }

    return endpointUri.origin == supabaseUri.origin &&
        endpointUri.path == '/functions/v1/$functionName';
  }

  static bool resolveIsValidAndroidSha256CertificateDigest(String value) {
    return RegExp(
      r'^(?:[0-9A-Fa-f]{2}:){31}[0-9A-Fa-f]{2}$',
    ).hasMatch(value.trim());
  }

  static List<String> productionReadinessIssues({bool force = false}) {
    if (!force &&
        !enforceProductionReadiness &&
        !isProduction &&
        !kReleaseMode) {
      return const <String>[];
    }

    final List<String> issues = <String>[];
    final bool requireHttpsAppLink =
        force || enforceProductionReadiness || isProduction || kReleaseMode;
    if (kReleaseMode && !AppFlavor.parse(appFlavor).isProduction) {
      issues.add('Release builds must use CHRONOSPARK_APP_FLAVOR=prod.');
    }
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
    if (_readBool('CHRONOSPARK_MAESTRO_MODE', _maestroModeDefine)) {
      issues.add('Maestro test mode is enabled.');
    }
    if (!hasSupabaseCredentialsPresent) {
      issues.add('Supabase authentication is not configured.');
    } else if (!isSupabaseConfigured) {
      issues.add('Supabase URL must be a valid HTTPS URL.');
    }
    _validateTrustedEdgeFunctionEndpoint(
      receiptVerifyEndpoint,
      label: 'Receipt verification endpoint',
      functionName: 'monetization-verify',
      issues: issues,
    );
    _validateTrustedEdgeFunctionEndpoint(
      aiProxyEndpoint,
      label: 'AI proxy endpoint',
      functionName: 'ai-proxy',
      issues: issues,
    );
    _validateTrustedEdgeFunctionEndpoint(
      accountDeleteEndpoint,
      label: 'Account deletion endpoint',
      functionName: 'account-delete',
      issues: issues,
    );
    _validateAuthRedirect(
      oauthRedirectUrl,
      label: 'OAuth redirect URL',
      requireHttpsAppLink: requireHttpsAppLink,
      issues: issues,
    );
    _validateAuthRedirect(
      passwordRecoveryRedirectUrl,
      label: 'Password recovery redirect URL',
      requireHttpsAppLink: requireHttpsAppLink,
      issues: issues,
    );
    _validateAuthRedirect(
      githubOauthRedirectUrl,
      label: 'GitHub OAuth redirect URL',
      requireHttpsAppLink: requireHttpsAppLink,
      issues: issues,
    );
    if (enableRuntimeFeatureFlags && !isFirebaseFeatureFlagRuntimeReady) {
      issues.add('Runtime feature flags require Firebase to be configured.');
    }
    if (!resolveIsValidAndroidSha256CertificateDigest(appLinksAndroidSha256)) {
      issues.add(
        'Android App Links SHA-256 fingerprint must contain 32 colon-separated bytes.',
      );
    }
    if (defaultTargetPlatform == TargetPlatform.iOS &&
        appLinksIosTeamId.trim().isEmpty) {
      issues.add('iOS associated domains team ID is not configured.');
    }
    return issues;
  }

  static void _validateTrustedEdgeFunctionEndpoint(
    String value, {
    required String label,
    required String functionName,
    required List<String> issues,
  }) {
    final String endpoint = value.trim();
    if (endpoint.isEmpty) {
      issues.add('$label is not configured.');
      return;
    }
    if (!resolveIsTrustedEdgeFunctionEndpoint(
      endpoint: endpoint,
      supabaseUrl: supabaseUrl,
      functionName: functionName,
    )) {
      issues.add(
        '$label must be the HTTPS /functions/v1/$functionName endpoint on the configured Supabase origin.',
      );
    }
  }

  static void _validateAuthRedirect(
    String value, {
    required String label,
    required bool requireHttpsAppLink,
    required List<String> issues,
  }) {
    if (!resolveIsAllowedAuthRedirect(
      value,
      requireHttpsAppLink: requireHttpsAppLink,
    )) {
      issues.add(
        requireHttpsAppLink
            ? '$label must be the verified production App Link $productionAuthCallbackUrl.'
            : '$label must be $customSchemeAuthCallbackUrl or $productionAuthCallbackUrl.',
      );
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
}
