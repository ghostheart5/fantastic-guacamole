/// Reviewed source capabilities for the public-build acceptance checkpoint.
///
/// These switches are intentionally not environment-overridable. A feature
/// moves to `true` only after source/configuration validation. Final artifact
/// acceptance and production activation remain separate gates. See
/// docs/engineering/PUBLIC_CAPABILITY_CHECKPOINT_20260926.md.
abstract final class LaunchContainment {
  static const bool cloudSyncEnabled = true;
  static const bool cloudRestoreEnabled = true;
  static const bool subscriptionsEnabled = true;
  static const bool externalAiEnabled = true;
  static const bool creditSpendingEnabled = true;
  // Refreshed September 26: intended API organization, 30-day default retention,
  // global inference, no ZDR, feedback off and corrected-key live acceptance.
  // See the public capability checkpoint; reassess on provider changes.
  static const bool externalAiProviderRetentionVerified = true;
  // Product validation by the release owner/team; not mandatory professional
  // certification. Evidence must cover the actual source/configuration scope.
  static const bool externalAiPrivacyValidationPassed = true;
  static const bool externalAiSafetyValidationPassed = true;
  static const bool paidCreditPlansEnabled =
      subscriptionsEnabled &&
      externalAiEnabled &&
      creditSpendingEnabled &&
      externalAiProviderRetentionVerified &&
      externalAiPrivacyValidationPassed &&
      externalAiSafetyValidationPassed;
  // Source approval alone must not activate default/private builds.
  static const String publicBuildValue = String.fromEnvironment(
    'CHRONOSPARK_PUBLIC_RELEASE',
    defaultValue: 'false',
  );
  static const bool publicBuildRequested = publicBuildValue == 'true';
  static const bool publicCloudBuildRequested =
      publicBuildRequested &&
      String.fromEnvironment(
            'CHRONOSPARK_BACKEND_MODE',
            defaultValue: 'cloud',
          ) ==
          'cloud';
  static const bool publicCloudSyncEnabled =
      publicCloudBuildRequested && cloudSyncEnabled;
  static const bool publicCloudRestoreEnabled =
      publicCloudBuildRequested && cloudRestoreEnabled;
  static const bool publicSubscriptionsEnabled =
      publicCloudBuildRequested && subscriptionsEnabled;
  static const bool publicExternalAiEnabled =
      publicCloudBuildRequested && externalAiEnabled;
  static const bool publicCreditSpendingEnabled =
      publicCloudBuildRequested && creditSpendingEnabled;
  static const bool publicPaidCreditPlansEnabled =
      publicCloudBuildRequested && paidCreditPlansEnabled;
  static const bool analyticsEnabled = false;
  static const bool crashReportingEnabled = false;
  static const bool inferredIdentityEnabled = false;

  static bool resolvePaidCreditPlansEnabled({
    required bool subscriptionsEnabled,
    required bool externalAiEnabled,
    required bool creditSpendingEnabled,
    required bool providerRetentionVerified,
    required bool privacyValidationPassed,
    required bool safetyValidationPassed,
  }) {
    return subscriptionsEnabled &&
        externalAiEnabled &&
        creditSpendingEnabled &&
        providerRetentionVerified &&
        privacyValidationPassed &&
        safetyValidationPassed;
  }
}

final class LaunchContainedException implements Exception {
  const LaunchContainedException(this.feature);

  final String feature;

  @override
  String toString() => '$feature is unavailable during launch-readiness work.';
}
