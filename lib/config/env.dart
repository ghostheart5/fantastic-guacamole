import 'dart:convert';

import 'package:fantastic_guacamole/config/app_flavor.dart';
import 'package:fantastic_guacamole/config/firebase_identity.dart';
import 'package:fantastic_guacamole/config/launch_containment.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

part 'src/build_settings.dart';
part 'src/feature_flags.dart';
part 'src/readiness_policy.dart';
part 'src/service_endpoints.dart';

abstract final class Env {
  static const String appName = 'ChronoSpark';
  static const String supportEmail = 'support@chronospark.app';
  static const String expectedFirebaseProjectId =
      FirebaseIdentity.expectedProjectId;

  static String get appFlavor => _BuildSettings.appFlavor;
  static bool get enableVerboseLogs => _BuildSettings.enableVerboseLogs;
  static bool get enableCrashReporting =>
      LaunchContainment.crashReportingEnabled &&
      _BuildSettings.enableCrashReporting;
  static bool get enableAnalytics =>
      LaunchContainment.analyticsEnabled && _BuildSettings.enableAnalytics;
  static String get appLinksAndroidSha256 =>
      _BuildSettings.appLinksAndroidSha256;
  static String get appLinksIosTeamId => _BuildSettings.appLinksIosTeamId;
  static AppFlavor get flavor => _BuildSettings.flavor;
  static bool get isProduction => _BuildSettings.isProduction;

  static bool get enableMockLogin => _FeatureFlags.enableMockLogin;
  static bool get enableMockMode => _FeatureFlags.enableMockMode;
  static bool get enablePaywallDisabled => _FeatureFlags.enablePaywallDisabled;
  static bool get enableTesterFullAccess =>
      _FeatureFlags.enableTesterFullAccess;
  static bool get enableRuntimeFeatureFlags =>
      _FeatureFlags.enableRuntimeFeatureFlags;
  static String get remoteConfigDefaultsJson =>
      _FeatureFlags.remoteConfigDefaultsJson;
  static bool get enableCloudSync =>
      LaunchContainment.cloudSyncEnabled && _FeatureFlags.enableCloudSync;
  static bool get enableCloudRestore => LaunchContainment.cloudRestoreEnabled;
  static bool get subscriptionsEnabled =>
      LaunchContainment.subscriptionsEnabled;
  static bool get externalAiEnabled => LaunchContainment.externalAiEnabled;
  static bool get creditSpendingEnabled =>
      LaunchContainment.creditSpendingEnabled;
  static bool get isMockMode => _FeatureFlags.isMockMode;
  static bool get isPaywallDisabled => _FeatureFlags.isPaywallDisabled;
  static bool get isMockLoginEnabled => _FeatureFlags.isMockLoginEnabled;
  static bool get hasTesterFullAccess => _FeatureFlags.hasTesterFullAccess;

  static String get aiProxyEndpoint => _ServiceEndpoints.aiProxyEndpoint;
  static String get aiReportEndpoint => _ServiceEndpoints.aiReportEndpoint;
  static String get accountDeleteEndpoint =>
      _ServiceEndpoints.accountDeleteEndpoint;
  static String get oauthRedirectUrl => _ServiceEndpoints.oauthRedirectUrl;
  static String get githubOauthRedirectUrl =>
      _ServiceEndpoints.githubOauthRedirectUrl;
  static String get supabaseUrl => _ServiceEndpoints.supabaseUrl;
  static String get supabaseAnonKey => _ServiceEndpoints.supabaseAnonKey;
  static String get receiptVerifyEndpoint =>
      _ServiceEndpoints.receiptVerifyEndpoint;
  static bool get isSupabaseConfigured =>
      _ServiceEndpoints.isSupabaseConfigured;
  static bool get isAiProxyConfigured =>
      LaunchContainment.externalAiEnabled &&
      _ServiceEndpoints.isAiProxyConfigured;

  static bool get enforceProductionReadiness =>
      _ReadinessPolicy.enforceProductionReadiness;

  static AppFlavor resolveFlavor(String flavor, {required bool isReleaseMode}) {
    return _BuildSettings.resolveFlavor(flavor, isReleaseMode: isReleaseMode);
  }

  static bool resolveIsProduction(
    String flavor, {
    required bool isReleaseMode,
  }) {
    return _BuildSettings.resolveIsProduction(
      flavor,
      isReleaseMode: isReleaseMode,
    );
  }

  static bool resolveIsMockMode({
    required bool isProduction,
    required bool enableMockMode,
  }) {
    return _FeatureFlags.resolveIsMockMode(
      isProduction: isProduction,
      enableMockMode: enableMockMode,
    );
  }

  static bool resolveIsPaywallDisabled({
    required bool isProduction,
    required bool enablePaywallDisabled,
    required bool isMockMode,
  }) {
    return _FeatureFlags.resolveIsPaywallDisabled(
      isProduction: isProduction,
      enablePaywallDisabled: enablePaywallDisabled,
      isMockMode: isMockMode,
    );
  }

  static bool resolveIsMockLoginEnabled({
    required bool isProduction,
    required bool isMockMode,
    required bool enableMockLogin,
  }) {
    return _FeatureFlags.resolveIsMockLoginEnabled(
      isProduction: isProduction,
      isMockMode: isMockMode,
      enableMockLogin: enableMockLogin,
    );
  }

  static bool resolveHasTesterFullAccess({
    required bool isProduction,
    required bool enableTesterFullAccess,
  }) {
    return _FeatureFlags.resolveHasTesterFullAccess(
      isProduction: isProduction,
      enableTesterFullAccess: enableTesterFullAccess,
    );
  }

  static bool resolveIsSupabaseConfigured({
    required String url,
    required String anonKey,
  }) {
    return _ServiceEndpoints.resolveIsSupabaseConfigured(
      url: url,
      anonKey: anonKey,
    );
  }

  static bool resolveIsValidSupabaseUrl(String value) =>
      _ServiceEndpoints.resolveIsValidSupabaseUrl(value);

  static bool resolveIsValidSupabaseAnonKey(String value) =>
      _ServiceEndpoints.resolveIsValidSupabaseAnonKey(value);

  static bool resolveIsValidHttpsEndpoint(String endpoint) =>
      _ServiceEndpoints.resolveIsValidHttpsEndpoint(endpoint);

  static bool resolveIsAiProxyConfigured(String endpoint) =>
      _ServiceEndpoints.resolveIsAiProxyConfigured(endpoint);

  static String resolveReceiptVerifyEndpoint(
    String configuredValue, {
    required String supabaseUrl,
  }) {
    return _ServiceEndpoints.resolveReceiptVerifyEndpoint(
      configuredValue,
      supabaseUrl: supabaseUrl,
    );
  }

  static String resolveAiReportEndpoint(
    String configuredValue, {
    required String supabaseUrl,
  }) {
    return _ServiceEndpoints.resolveAiReportEndpoint(
      configuredValue,
      supabaseUrl: supabaseUrl,
    );
  }

  static bool resolveShouldBlockStartupForProductionReadiness({
    required bool enforceProductionReadiness,
    required bool isProduction,
    required Iterable<String> readinessIssues,
  }) {
    return _ReadinessPolicy.resolveShouldBlockStartupForProductionReadiness(
      enforceProductionReadiness: enforceProductionReadiness,
      isProduction: isProduction,
      readinessIssues: readinessIssues,
    );
  }

  static List<String> productionReadinessIssues({
    bool force = false,
    bool? firebaseInitialized,
    String? firebaseProjectId,
    TargetPlatform? targetPlatform,
    bool isWeb = kIsWeb,
  }) {
    return _ReadinessPolicy.productionReadinessIssues(
      force: force,
      firebaseInitialized: firebaseInitialized,
      firebaseProjectId: firebaseProjectId,
      targetPlatform: targetPlatform,
      isWeb: isWeb,
    );
  }

  static String? resolveFirebaseFeatureFlagReadinessIssue({
    required bool isMockMode,
    required bool enableRuntimeFeatureFlags,
    required bool? firebaseInitialized,
    required String? firebaseProjectId,
  }) {
    return _ReadinessPolicy.resolveFirebaseFeatureFlagReadinessIssue(
      isMockMode: isMockMode,
      enableRuntimeFeatureFlags: enableRuntimeFeatureFlags,
      firebaseInitialized: firebaseInitialized,
      firebaseProjectId: firebaseProjectId,
    );
  }

  static bool resolveShouldUseFirebaseFeatureFlags({
    required bool isMockMode,
    required bool enableRuntimeFeatureFlags,
    required bool firebaseInitialized,
    required String? firebaseProjectId,
  }) {
    return _ReadinessPolicy.resolveShouldUseFirebaseFeatureFlags(
      isMockMode: isMockMode,
      enableRuntimeFeatureFlags: enableRuntimeFeatureFlags,
      firebaseInitialized: firebaseInitialized,
      firebaseProjectId: firebaseProjectId,
    );
  }

  /// Resolves configuration without allowing a bundled `.env` value to
  /// override an explicit define or any value compiled into a release build.
  static String resolveConfiguredString({
    required String defineValue,
    required bool defineProvided,
    required String? dotenvValue,
    required bool isReleaseMode,
  }) {
    if (isReleaseMode || defineProvided) {
      return defineValue;
    }
    final String? normalized = dotenvValue?.trim();
    return normalized == null || normalized.isEmpty ? defineValue : normalized;
  }

  static bool resolveConfiguredBool({
    required String key,
    required bool defineValue,
    required bool defineProvided,
    required String? rawDefineValue,
    required String? dotenvValue,
    required bool isReleaseMode,
  }) {
    if (defineProvided) {
      if (rawDefineValue == null || rawDefineValue.trim().isEmpty) {
        throw FormatException('Raw configuration value for $key is missing.');
      }
      return _parseConfiguredBool(key, rawDefineValue);
    }
    if (isReleaseMode || dotenvValue == null) {
      return defineValue;
    }
    return _parseConfiguredBool(key, dotenvValue);
  }

  static bool _parseConfiguredBool(String key, String value) {
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
        throw FormatException(
          'Configuration value for $key must be a boolean.',
        );
    }
  }

  static String _readString(
    String key,
    String fallback, {
    bool defineProvided = false,
  }) {
    return resolveConfiguredString(
      defineValue: fallback,
      defineProvided: defineProvided,
      dotenvValue: _dotenvValue(key),
      isReleaseMode: kReleaseMode,
    );
  }

  static bool _readBool(
    String key,
    bool fallback, {
    bool defineProvided = false,
    required String rawDefineValue,
  }) {
    return resolveConfiguredBool(
      key: key,
      defineValue: fallback,
      defineProvided: defineProvided,
      rawDefineValue: rawDefineValue,
      dotenvValue: _dotenvValue(key),
      isReleaseMode: kReleaseMode,
    );
  }

  static String? _dotenvValue(String key) {
    try {
      return dotenv.maybeGet(key);
    } on Object {
      return null;
    }
  }

  // Security-relevant reads use the same release-safe precedence as all
  // configuration values while keeping risk-sensitive call sites explicit.
  static bool _readRiskBool(
    String key,
    bool fallback, {
    required bool defineProvided,
    required String rawDefineValue,
  }) {
    return _readBool(
      key,
      fallback,
      defineProvided: defineProvided,
      rawDefineValue: rawDefineValue,
    );
  }

  /// String counterpart of [_readRiskBool] for the app flavor gate.
  static String _readRiskString(
    String key,
    String fallback, {
    required bool defineProvided,
  }) {
    return _readString(key, fallback, defineProvided: defineProvided);
  }
}
