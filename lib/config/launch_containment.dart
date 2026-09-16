/// Fail-closed feature state for the 2040 launch-readiness repair.
///
/// These switches are intentionally not environment-overridable. A feature
/// moves to `true` only in a reviewed checkpoint after its mandatory gate is
/// recorded as PASS in the launch-readiness tracker.
abstract final class LaunchContainment {
  static const bool cloudSyncEnabled = false;
  static const bool cloudRestoreEnabled = false;
  static const bool subscriptionsEnabled = false;
  static const bool externalAiEnabled = false;
  static const bool creditSpendingEnabled = false;
  // Verified 2026-09-11: actual API organization, 30-day default retention,
  // global inference, no ZDR, feedback off; disclosures reconciled in
  // docs/engineering/FINAL_FOUR_GATES_20260911.md. Reassess on provider changes.
  static const bool externalAiProviderRetentionVerified = true;
  static const bool externalAiSafetyReviewApproved = false;
  static const bool paidCreditPlansEnabled =
      subscriptionsEnabled &&
      externalAiEnabled &&
      creditSpendingEnabled &&
      externalAiProviderRetentionVerified &&
      externalAiSafetyReviewApproved;
  static const bool analyticsEnabled = false;
  static const bool crashReportingEnabled = false;
  static const bool inferredIdentityEnabled = false;

  static bool resolvePaidCreditPlansEnabled({
    required bool subscriptionsEnabled,
    required bool externalAiEnabled,
    required bool creditSpendingEnabled,
    required bool providerRetentionVerified,
    required bool safetyReviewApproved,
  }) {
    return subscriptionsEnabled &&
        externalAiEnabled &&
        creditSpendingEnabled &&
        providerRetentionVerified &&
        safetyReviewApproved;
  }
}

final class LaunchContainedException implements Exception {
  const LaunchContainedException(this.feature);

  final String feature;

  @override
  String toString() => '$feature is unavailable during launch-readiness work.';
}
