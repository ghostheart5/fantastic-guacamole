import 'dart:convert';

import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:fantastic_guacamole/state/core/app_providers.dart';
import 'package:fantastic_guacamole/system/notifications/notification_scheduler.dart';

enum StartupRouteGate { continueRouting, allow, redirectToBootstrap }

StartupRouteGate resolveStartupRouteGate({
  required String location,
  required Uri uri,
  required OnboardingStatus onboardingStatus,
}) {
  if (isAuthCallbackLoginRoute(location: location, uri: uri)) {
    return StartupRouteGate.allow;
  }
  if (onboardingStatus == OnboardingStatus.unknown) {
    return location == RoutePaths.bootstrap
        ? StartupRouteGate.allow
        : StartupRouteGate.redirectToBootstrap;
  }
  return StartupRouteGate.continueRouting;
}

bool isAuthCallbackLoginRoute({required String location, required Uri uri}) {
  if (location != RoutePaths.login) {
    return false;
  }
  final String mode = (uri.queryParameters['mode'] ?? '').trim().toLowerCase();
  return mode == 'recovery' ||
      mode == 'verify-email' ||
      mode == 'auth-callback';
}

bool shouldRegisterCompletionEventsRoute({
  required bool isReleaseMode,
  required bool hasAdminAccess,
}) {
  return !isReleaseMode || hasAdminAccess;
}

String resolveDeepLinkLocation(Uri uri) {
  if (_isCustomSchemeAuthCallback(uri)) {
    return _authCallbackLocation(_allLinkParams(uri));
  }

  final String appPath = _normalizeAppPath(uri.path);
  if (appPath.isEmpty) {
    return RoutePaths.unsupportedLink;
  }
  if (appPath == '/app/auth/callback') {
    return _authCallbackLocation(_allLinkParams(uri));
  }
  if (appPath == '/app' || appPath == '/app/') {
    return RoutePaths.home;
  }

  final String leaf = appPath.substring('/app/'.length);
  return switch (leaf) {
    'home' => RoutePaths.home,
    'plan' => RoutePaths.plan,
    'creator' => RoutePaths.creator,
    'insights' => RoutePaths.insights,
    'settings' => RoutePaths.settings,
    'notifications' => RoutePaths.notifications,
    'timeline' => RoutePaths.timeline,
    'tasks' => RoutePaths.tasks,
    'profile' => RoutePaths.profile,
    'progression' => RoutePaths.progression,
    'si-console' => RoutePaths.si,
    'advisor' => RoutePaths.advisor,
    'paywall' => RoutePaths.paywall,
    'paywall/compare' => RoutePaths.planComparison,
    'paywall/credits' => RoutePaths.creditStore,
    'paywall/credits/history' => RoutePaths.creditHistory,
    'paywall/manage' => RoutePaths.subscriptionManagement,
    'privacy' => RoutePaths.privacy,
    'delete-account' => RoutePaths.deleteAccount,
    'terms' => RoutePaths.terms,
    'support' => RoutePaths.support,
    'about' => RoutePaths.about,
    _ => RoutePaths.unsupportedLink,
  };
}

String resolveNotificationPayloadLocation(String payload) {
  try {
    final Object? decoded = jsonDecode(payload);
    if (decoded is Map) {
      final Object? rawDestination = decoded['destination'];
      if (rawDestination is String) {
        final NotificationDestination? destination =
            _notificationDestinationFromName(rawDestination);
        if (destination != null) {
          return switch (destination) {
            NotificationDestination.task ||
            NotificationDestination.goal => RoutePaths.creator,
            NotificationDestination.timeline => RoutePaths.timeline,
            NotificationDestination.siConsole => RoutePaths.si,
            NotificationDestination.home => RoutePaths.home,
          };
        }
      }
    }
  } on FormatException {
    // Invalid persisted payloads are kept inside the notification inbox.
  }
  return RoutePaths.notifications;
}

String _authCallbackLocation(Map<String, String> parameters) {
  final String type = (parameters['type'] ?? '').toLowerCase();
  final String mode = switch (type) {
    'recovery' => 'recovery',
    'signup' || 'email_change' || 'invite' => 'verify-email',
    _ => 'auth-callback',
  };
  return '${RoutePaths.login}?mode=$mode';
}

bool _isCustomSchemeAuthCallback(Uri uri) {
  return uri.scheme == 'chronospark' &&
      uri.host.toLowerCase() == 'auth-callback' &&
      (uri.path.isEmpty || uri.path == '/');
}

String _normalizeAppPath(String path) {
  if (path == '/app' || path == '/app/' || path.startsWith('/app/')) {
    return path;
  }
  final int appStart = path.indexOf('/app');
  if (appStart >= 0) {
    return path.substring(appStart);
  }
  return '';
}

Map<String, String> _allLinkParams(Uri uri) {
  final Map<String, String> merged = <String, String>{...uri.queryParameters};
  final String fragment = uri.fragment.trim();
  if (fragment.isNotEmpty) {
    merged.addAll(Uri.splitQueryString(fragment));
  }
  return merged;
}

NotificationDestination? _notificationDestinationFromName(String value) {
  for (final NotificationDestination destination
      in NotificationDestination.values) {
    if (destination.name == value.trim()) {
      return destination;
    }
  }
  return null;
}
