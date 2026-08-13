import 'package:fantastic_guacamole/state/core/app_providers.dart';
import 'package:fantastic_guacamole/config/env.dart';
import 'package:fantastic_guacamole/state/controllers/profile_controller.dart';
import 'package:fantastic_guacamole/state/providers/access_provider.dart';
import 'package:fantastic_guacamole/state/providers/intelligence_provider.dart'
    show intelligenceStateProvider;
import 'package:fantastic_guacamole/state/providers/authenticated_data_readiness_provider.dart';
import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final onboardingStatusGuardProvider = Provider<OnboardingStatus>((ref) {
  return ref.watch(onboardingStatusProvider);
});

final onboardingCompleteGuardProvider = Provider<bool>((ref) {
  return ref.watch(onboardingStatusGuardProvider) == OnboardingStatus.complete;
});

final onboardingResolvedGuardProvider = Provider<bool>((ref) {
  return ref.watch(onboardingStatusGuardProvider) != OnboardingStatus.unknown;
});

final creatorFirstItemCreatedGuardProvider = Provider<bool>((ref) {
  return ref.watch(creatorFirstItemCreatedProvider);
});

final timelineFirstActionCompletedGuardProvider = Provider<bool>((ref) {
  return ref.watch(timelineFirstActionCompletedProvider);
});

final authenticatedGuardProvider = Provider<bool>((ref) {
  final intelligence = ref.watch(intelligenceStateProvider);
  return intelligence.auth.isAuthenticated;
});

final profileCompleteGuardProvider = Provider<bool>((ref) {
  if (Env.maestroMode) {
    return true;
  }
  final profile = ref.watch(profileProvider);
  return profile.hasValidProfile;
});

final premiumAccessGuardProvider = Provider<bool>((ref) {
  final access = ref.watch(appAccessProvider);
  return access.hasPremiumAccess || !access.paywallEnabled;
});

final adminAccessGuardProvider = Provider<bool>((ref) {
  final intelligence = ref.watch(intelligenceStateProvider);
  return intelligence.flags.testerFullAccess;
});

/// Authenticated domain destinations that require a ready user-data boundary.
/// Legal, bootstrap, onboarding, and login routes intentionally remain outside
/// this set so their existing redirect ordering is preserved.
bool requiresAuthenticatedDataReadiness(String location) {
  return <String>{
    RoutePaths.shell,
    RoutePaths.home,
    RoutePaths.plan,
    RoutePaths.creator,
    RoutePaths.insights,
    RoutePaths.settings,
    RoutePaths.notifications,
    RoutePaths.notificationPermissionRecovery,
    RoutePaths.timeline,
    RoutePaths.tasks,
    RoutePaths.profile,
    RoutePaths.progression,
    RoutePaths.si,
    RoutePaths.advisor,
    RoutePaths.completionEvents,
    RoutePaths.paywall,
    RoutePaths.planComparison,
    RoutePaths.creditStore,
    RoutePaths.creditHistory,
    RoutePaths.subscriptionManagement,
    RoutePaths.legacyCoach,
    RoutePaths.legacyTimeline,
    RoutePaths.legacyNotifications,
    RoutePaths.legacyProgression,
    RoutePaths.legacySi,
    RoutePaths.legacyTasks,
    RoutePaths.legacyProfile,
  }.contains(location);
}

String? resolveAuthenticatedDataRouteRedirect({
  required bool isAuthenticated,
  required AuthenticatedDataReadiness readiness,
  required String location,
}) {
  if (!isAuthenticated || !requiresAuthenticatedDataReadiness(location)) {
    return null;
  }
  if (isAuthenticatedDataReady(readiness)) {
    return null;
  }
  return readiness == AuthenticatedDataReadiness.blocked
      ? RoutePaths.sessionBlocked
      : RoutePaths.bootstrap;
}
