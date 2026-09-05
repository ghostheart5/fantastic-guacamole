import 'package:fantastic_guacamole/config/env.dart';
import 'package:fantastic_guacamole/config/launch_containment.dart';
import 'package:fantastic_guacamole/state/providers/entitlement_provider.dart';
import 'package:fantastic_guacamole/state/providers/intelligence_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppAccessState {
  const AppAccessState({
    required this.hasPremiumAccess,
    required this.hasTesterFullAccess,
    required this.paywallDisabled,
    this.isLocalMode = false,
  });

  final bool hasPremiumAccess;
  final bool hasTesterFullAccess;
  final bool paywallDisabled;
  final bool isLocalMode;

  bool get paywallEnabled =>
      !isLocalMode &&
      LaunchContainment.subscriptionsEnabled &&
      !paywallDisabled &&
      !hasTesterFullAccess;

  String get subscriptionStatusLabel {
    if (isLocalMode) return 'Local profile';
    if (!LaunchContainment.subscriptionsEnabled) {
      return 'Plans unavailable';
    }
    if (paywallDisabled || hasTesterFullAccess) {
      return 'Unlocked for testing';
    }
    if (hasPremiumAccess) {
      return 'Premium active';
    }
    return 'Premium locked';
  }

  String get subscriptionStatusDetail {
    if (isLocalMode) {
      return 'Your profile and plans are stored on this device. No subscription is required.';
    }
    if (!LaunchContainment.subscriptionsEnabled) {
      return 'Subscriptions are disabled while launch-readiness work is completed.';
    }
    if (paywallDisabled || hasTesterFullAccess) {
      return 'This QA build bypasses premium restrictions and does not use live billing.';
    }
    if (hasPremiumAccess) {
      return 'Premium features are currently unlocked for this account.';
    }
    return 'Premium access is not yet provisioned in this build.';
  }
}

/// Read-only view of [entitlementProvider].
///
/// Kept as a compatibility alias for existing call sites. It is deliberately
/// *derived* rather than settable: a separately-writable premium flag was the
/// cause of paid access being lost on relaunch, because it always rebuilt to
/// false and nothing rehydrated it from the persisted subscription.
final runtimePremiumAccessProvider = Provider<bool>((ref) {
  if (Env.isLocalMode) return false;
  return ref.watch(entitlementProvider).asData?.value.isPremium ?? false;
});

final appAccessProvider = Provider<AppAccessState>((ref) {
  if (Env.isLocalMode) {
    return const AppAccessState(
      hasPremiumAccess: false,
      hasTesterFullAccess: false,
      paywallDisabled: false,
      isLocalMode: true,
    );
  }
  final intelligence = ref.watch(intelligenceStateProvider);
  final bool testerFullAccess =
      intelligence.flags.testerFullAccess ||
      intelligence.flags.mockMode ||
      intelligence.flags.paywallDisabled;
  // Unresolved entitlement reads as not premium, so access fails closed while
  // the persisted subscription is still being read.
  final bool entitled =
      ref.watch(entitlementProvider).asData?.value.isPremium ?? false;

  return AppAccessState(
    hasPremiumAccess: testerFullAccess || entitled,
    hasTesterFullAccess: testerFullAccess,
    paywallDisabled: intelligence.flags.paywallDisabled,
  );
});

/// Trusted Product Advisor authorization.
///
/// This intentionally reads only server-controlled auth app metadata propagated
/// from Supabase. User-editable profile/user metadata, premium entitlement,
/// tester-full-access, and mock-login flags must not grant access to internal
/// Product Advisor diagnostics.
final internalAdvisorAccessProvider = Provider<bool>((ref) {
  final user = ref.watch(authUserProvider).asData?.value;
  return user?.hasInternalAdvisorAccess ?? false;
});
