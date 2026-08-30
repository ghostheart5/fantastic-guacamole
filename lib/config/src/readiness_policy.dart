part of '../env.dart';

abstract final class _ReadinessPolicy {
  static const bool _enforceProductionReadinessDefine = bool.fromEnvironment(
    'CHRONOSPARK_ENFORCE_PROD_READINESS',
    defaultValue: false,
  );
  static const String _enforceProductionReadinessRawDefine =
      String.fromEnvironment('CHRONOSPARK_ENFORCE_PROD_READINESS');
  static const bool _hasEnforceProductionReadinessDefine = bool.hasEnvironment(
    'CHRONOSPARK_ENFORCE_PROD_READINESS',
  );

  static bool get enforceProductionReadiness => Env._readBool(
    'CHRONOSPARK_ENFORCE_PROD_READINESS',
    _enforceProductionReadinessDefine,
    defineProvided: _hasEnforceProductionReadinessDefine,
    rawDefineValue: _enforceProductionReadinessRawDefine,
  );

  static bool resolveShouldBlockStartupForProductionReadiness({
    required bool enforceProductionReadiness,
    required bool isProduction,
    required Iterable<String> readinessIssues,
  }) {
    return enforceProductionReadiness &&
        isProduction &&
        readinessIssues.isNotEmpty;
  }

  static List<String> productionReadinessIssues({
    bool force = false,
    bool? firebaseInitialized,
    String? firebaseProjectId,
    TargetPlatform? targetPlatform,
    bool isWeb = kIsWeb,
  }) {
    if (!force && !enforceProductionReadiness && !_BuildSettings.isProduction) {
      return const <String>[];
    }

    final List<String> issues = <String>[];
    if (_BuildSettings.enableCrashReporting) {
      issues.add(
        'Crash reporting must remain disabled until telemetry consent passes.',
      );
    }
    if (_BuildSettings.enableAnalytics) {
      issues.add(
        'Analytics must remain disabled until telemetry consent passes.',
      );
    }
    if (_FeatureFlags.enableMockLogin) {
      issues.add('Mock login bypass is enabled.');
    }
    if (_FeatureFlags.enableMockMode) {
      issues.add('Global mock mode is enabled.');
    }
    if (_FeatureFlags.enablePaywallDisabled) {
      issues.add('Paywall-disabled development override is enabled.');
    }
    if (_FeatureFlags.enableTesterFullAccess) {
      issues.add('Tester full-access override is enabled.');
    }
    if (!_ServiceEndpoints.resolveIsValidSupabaseUrl(
      _ServiceEndpoints.supabaseUrl,
    )) {
      issues.add('Supabase URL must be a valid root HTTPS URL.');
    }
    if (!_ServiceEndpoints.resolveIsValidSupabaseAnonKey(
      _ServiceEndpoints.supabaseAnonKey,
    )) {
      issues.add('Supabase publishable key is missing or malformed.');
    }
    if (LaunchContainment.subscriptionsEnabled) {
      _validateHttpsEndpoint(
        _ServiceEndpoints.receiptVerifyEndpoint,
        label: 'Receipt verification endpoint',
        issues: issues,
      );
    }
    if (LaunchContainment.externalAiEnabled) {
      _validateHttpsEndpoint(
        _ServiceEndpoints.aiProxyEndpoint,
        label: 'AI proxy endpoint',
        issues: issues,
      );
      _validateHttpsEndpoint(
        _ServiceEndpoints.aiReportEndpoint,
        label: 'AI report endpoint',
        issues: issues,
      );
    }
    _validateHttpsEndpoint(
      _ServiceEndpoints.accountDeleteEndpoint,
      label: 'Account deletion endpoint',
      issues: issues,
    );
    final String? firebaseRuntimeIssue =
        resolveFirebaseFeatureFlagReadinessIssue(
          isMockMode: _FeatureFlags.isMockMode,
          enableRuntimeFeatureFlags: _FeatureFlags.enableRuntimeFeatureFlags,
          firebaseInitialized: firebaseInitialized,
          firebaseProjectId: firebaseProjectId,
        );
    if (firebaseRuntimeIssue != null) {
      issues.add(firebaseRuntimeIssue);
    }
    final TargetPlatform platform = targetPlatform ?? defaultTargetPlatform;
    if (!isWeb &&
        platform == TargetPlatform.android &&
        _BuildSettings.appLinksAndroidSha256.trim().isEmpty) {
      issues.add('Android App Links SHA-256 fingerprint is not configured.');
    }
    if (!isWeb &&
        (platform == TargetPlatform.iOS || platform == TargetPlatform.macOS) &&
        _BuildSettings.appLinksIosTeamId.trim().isEmpty) {
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
    if (!_ServiceEndpoints.resolveIsValidHttpsEndpoint(endpoint)) {
      issues.add(
        '$label must be a credential-free HTTPS URL without a query or fragment.',
      );
    }
  }

  static String? resolveFirebaseFeatureFlagReadinessIssue({
    required bool isMockMode,
    required bool enableRuntimeFeatureFlags,
    required bool? firebaseInitialized,
    required String? firebaseProjectId,
  }) {
    if (firebaseInitialized == null ||
        !enableRuntimeFeatureFlags ||
        isMockMode) {
      return null;
    }
    if (!firebaseInitialized) {
      return 'Runtime feature flags require Firebase core to initialize successfully.';
    }
    if (!FirebaseIdentity.matchesExpectedProjectId(firebaseProjectId)) {
      return 'Runtime feature flags require the expected ChronoSpark Firebase project.';
    }
    return null;
  }

  static bool resolveShouldUseFirebaseFeatureFlags({
    required bool isMockMode,
    required bool enableRuntimeFeatureFlags,
    required bool firebaseInitialized,
    required String? firebaseProjectId,
  }) {
    return !isMockMode &&
        enableRuntimeFeatureFlags &&
        firebaseInitialized &&
        FirebaseIdentity.matchesExpectedProjectId(firebaseProjectId);
  }
}
