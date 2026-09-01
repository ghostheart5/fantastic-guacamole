import 'package:fantastic_guacamole/app/router/app_route_registry.dart';
import 'package:fantastic_guacamole/app/router/deep_link_service.dart';
import 'package:flutter/foundation.dart';

export 'package:fantastic_guacamole/app/router/app_route_registry.dart'
    show RouteAccessClass;

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

  static final Set<String> publicInformationRoutes = Set<String>.unmodifiable(
    AppRouteRegistry.canonical
        .where(
          (AppRouteDefinition route) =>
              route.accessClass == RouteAccessClass.publicInformation,
        )
        .map((AppRouteDefinition route) => route.path),
  );

  static final Set<String> protectedApplicationRoutes =
      Set<String>.unmodifiable(<String>{
        for (final AppRouteDefinition route in AppRouteRegistry.canonical)
          if (route.accessClass == RouteAccessClass.protectedApplication)
            route.path,
        for (final AppRouteCompatibility alias
            in AppRouteRegistry.compatibility)
          if (alias.path != null &&
              AppRouteRegistry.accessClassForPath(alias.path!) ==
                  RouteAccessClass.protectedApplication)
            alias.path!,
      });

  static RouteAccessDecision classify(String location) {
    final RouteAccessClass accessClass =
        AppRouteRegistry.accessClassForPath(location) ??
        RouteAccessClass.protectedApplication;
    return switch (accessClass) {
      RouteAccessClass.welcome => const RouteAccessDecision(
        accessClass: RouteAccessClass.welcome,
        requiresAuthentication: false,
        requiresCompletedOnboarding: false,
        allowsSignedOutAccess: true,
        isDeveloperOnly: false,
        reason:
            'Welcome and profile setup may gate app entry, but must not interrupt authentication callbacks.',
      ),
      RouteAccessClass.authentication => const RouteAccessDecision(
        accessClass: RouteAccessClass.authentication,
        requiresAuthentication: false,
        requiresCompletedOnboarding: false,
        allowsSignedOutAccess: true,
        isDeveloperOnly: false,
        reason:
            'Login owns recovery, verification, and auth-callback modes and must remain reachable while signed out.',
      ),
      RouteAccessClass.publicInformation => const RouteAccessDecision(
        accessClass: RouteAccessClass.publicInformation,
        requiresAuthentication: false,
        requiresCompletedOnboarding: false,
        allowsSignedOutAccess: true,
        isDeveloperOnly: false,
        reason:
            'Public legal and support information must remain reachable before sign-in.',
      ),
      RouteAccessClass.accountSensitiveInformation => const RouteAccessDecision(
        accessClass: RouteAccessClass.accountSensitiveInformation,
        requiresAuthentication: false,
        requiresCompletedOnboarding: false,
        allowsSignedOutAccess: true,
        isDeveloperOnly: false,
        reason:
            'Deletion instructions are public information; destructive account deletion remains authenticated on the backend/support path.',
      ),
      RouteAccessClass.commercial => const RouteAccessDecision(
        accessClass: RouteAccessClass.commercial,
        requiresAuthentication: true,
        requiresCompletedOnboarding: false,
        allowsSignedOutAccess: false,
        isDeveloperOnly: false,
        reason:
            'Purchases, restoration, and entitlement checks are account-bound.',
      ),
      RouteAccessClass.privilegedInternal => const RouteAccessDecision(
        accessClass: RouteAccessClass.privilegedInternal,
        requiresAuthentication: true,
        requiresCompletedOnboarding: true,
        allowsSignedOutAccess: false,
        isDeveloperOnly: true,
        reason:
            'Advisor diagnostics are internal developer/admin tooling, not a premium user-facing capability.',
      ),
      RouteAccessClass.protectedApplication => RouteAccessDecision(
        accessClass: RouteAccessClass.protectedApplication,
        requiresAuthentication: true,
        requiresCompletedOnboarding: true,
        allowsSignedOutAccess: false,
        isDeveloperOnly: false,
        reason: AppRouteRegistry.accessClassForPath(location) == null
            ? 'Unknown routes fail closed behind application access gates.'
            : 'Application surface or compatibility redirect.',
      ),
    };
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
    final RouteAccessClass? accessClass = AppRouteRegistry.accessClassForPath(
      path,
    );
    return accessClass == RouteAccessClass.protectedApplication ||
        accessClass == RouteAccessClass.commercial;
  }
}
