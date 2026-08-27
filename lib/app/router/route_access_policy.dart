import 'package:fantastic_guacamole/app/router/deep_link_service.dart';
import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:flutter/foundation.dart';

enum RouteAccessClass {
  welcome,
  authentication,
  publicInformation,
  accountSensitiveInformation,
  protectedApplication,
  commercial,
  privilegedInternal,
}

@immutable
class RouteAccessDecision {
  const RouteAccessDecision({
    required this.accessClass,
    required this.requiresAuthentication,
    required this.requiresCompletedOnboarding,
    required this.allowsSignedOutAccess,
    required this.isDeveloperOnly,
    required this.reason,
  });

  final RouteAccessClass accessClass;
  final bool requiresAuthentication;
  final bool requiresCompletedOnboarding;
  final bool allowsSignedOutAccess;
  final bool isDeveloperOnly;
  final String reason;
}

abstract final class RouteAccessPolicy {
  static const String returnToQueryParameter = 'returnTo';

  static const Set<String> publicInformationRoutes = <String>{
    RoutePaths.privacy,
    RoutePaths.terms,
    RoutePaths.support,
    RoutePaths.about,
  };

  static const Set<String> protectedApplicationRoutes = <String>{
    RoutePaths.shell,
    RoutePaths.home,
    RoutePaths.nexus,
    RoutePaths.plan,
    RoutePaths.creator,
    RoutePaths.settings,
    RoutePaths.notifications,
    RoutePaths.logs,
    RoutePaths.tasks,
    RoutePaths.profile,
    RoutePaths.progression,
    RoutePaths.si,
    RoutePaths.timeline,
    RoutePaths.smartPlanner,
    RoutePaths.trajectoryEngine,
    RoutePaths.legacyLogs,
    RoutePaths.legacyNotifications,
    RoutePaths.legacyProgression,
    RoutePaths.legacySi,
    RoutePaths.legacyTasks,
    RoutePaths.legacyProfile,
    RoutePaths.legacyInsights,
  };

  static RouteAccessDecision classify(String location) {
    if (location == RoutePaths.onboarding) {
      return const RouteAccessDecision(
        accessClass: RouteAccessClass.welcome,
        requiresAuthentication: false,
        requiresCompletedOnboarding: false,
        allowsSignedOutAccess: true,
        isDeveloperOnly: false,
        reason:
            'Welcome and profile setup may gate app entry, but must not interrupt authentication callbacks.',
      );
    }

    if (location == RoutePaths.login) {
      return const RouteAccessDecision(
        accessClass: RouteAccessClass.authentication,
        requiresAuthentication: false,
        requiresCompletedOnboarding: false,
        allowsSignedOutAccess: true,
        isDeveloperOnly: false,
        reason:
            'Login owns recovery, verification, and auth-callback modes and must remain reachable while signed out.',
      );
    }

    if (publicInformationRoutes.contains(location)) {
      return const RouteAccessDecision(
        accessClass: RouteAccessClass.publicInformation,
        requiresAuthentication: false,
        requiresCompletedOnboarding: false,
        allowsSignedOutAccess: true,
        isDeveloperOnly: false,
        reason:
            'Public legal and support information must remain reachable before sign-in.',
      );
    }

    if (location == RoutePaths.deleteAccount) {
      return const RouteAccessDecision(
        accessClass: RouteAccessClass.accountSensitiveInformation,
        requiresAuthentication: false,
        requiresCompletedOnboarding: false,
        allowsSignedOutAccess: true,
        isDeveloperOnly: false,
        reason:
            'Deletion instructions are public information; destructive account deletion remains authenticated on the backend/support path.',
      );
    }

    if (location == RoutePaths.paywall) {
      return const RouteAccessDecision(
        accessClass: RouteAccessClass.commercial,
        requiresAuthentication: true,
        requiresCompletedOnboarding: false,
        allowsSignedOutAccess: false,
        isDeveloperOnly: false,
        reason:
            'Purchases, restoration, and entitlement checks are account-bound.',
      );
    }

    if (location == RoutePaths.advisor) {
      return const RouteAccessDecision(
        accessClass: RouteAccessClass.privilegedInternal,
        requiresAuthentication: true,
        requiresCompletedOnboarding: true,
        allowsSignedOutAccess: false,
        isDeveloperOnly: true,
        reason:
            'Advisor diagnostics are internal developer/admin tooling, not a premium user-facing capability.',
      );
    }

    return RouteAccessDecision(
      accessClass: RouteAccessClass.protectedApplication,
      requiresAuthentication: true,
      requiresCompletedOnboarding: true,
      allowsSignedOutAccess: false,
      isDeveloperOnly: false,
      reason: protectedApplicationRoutes.contains(location)
          ? 'Application surface or compatibility redirect.'
          : 'Unknown routes fail closed behind application access gates.',
    );
  }

  static bool isAuthenticationCallback(DeepLinkMode? mode) {
    return mode == DeepLinkMode.recovery ||
        mode == DeepLinkMode.verifyEmail ||
        mode == DeepLinkMode.authCallback;
  }

  static String? validatedReturnTo(String? raw) {
    final String value = raw?.trim() ?? '';
    if (value.isEmpty) {
      return null;
    }

    Uri candidate;
    try {
      candidate = Uri.parse(value);
    } on FormatException {
      return null;
    }

    if (candidate.hasScheme || candidate.hasAuthority) {
      return null;
    }

    final String path = candidate.path;
    if (path.isEmpty || !path.startsWith('/')) {
      return null;
    }

    if (candidate.queryParameters.containsKey(returnToQueryParameter)) {
      return null;
    }

    if (!_isAllowedReturnPath(path)) {
      return null;
    }

    return candidate.toString();
  }

  static String? returnToForRequestedUri(Uri uri) {
    if (uri.hasScheme || uri.hasAuthority) {
      return null;
    }

    final String path = uri.path;
    if (!_isAllowedReturnPath(path)) {
      return null;
    }

    if (uri.queryParameters.containsKey(returnToQueryParameter)) {
      final Map<String, String> sanitizedQuery = Map<String, String>.of(
        uri.queryParameters,
      )..remove(returnToQueryParameter);
      return Uri(
        path: path,
        queryParameters: sanitizedQuery.isEmpty ? null : sanitizedQuery,
        fragment: uri.fragment.isEmpty ? null : uri.fragment,
      ).toString();
    }

    return uri.toString();
  }

  static String withReturnTo(String route, String? returnTo) {
    final String? validated = validatedReturnTo(returnTo);
    if (validated == null) {
      return route;
    }
    return Uri(
      path: route,
      queryParameters: <String, String>{returnToQueryParameter: validated},
    ).toString();
  }

  static bool _isAllowedReturnPath(String path) {
    if (path == RoutePaths.login ||
        path == RoutePaths.onboarding ||
        path == RoutePaths.advisor) {
      return false;
    }

    return protectedApplicationRoutes.contains(path) ||
        path == RoutePaths.paywall;
  }
}
