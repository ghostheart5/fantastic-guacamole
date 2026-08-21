import 'package:fantastic_guacamole/app/navigation_shell.dart';
import 'package:fantastic_guacamole/app/router/deep_link_service.dart';
import 'package:fantastic_guacamole/app/router/info_pages.dart';
import 'package:fantastic_guacamole/app/router/route_access_policy.dart';
import 'package:fantastic_guacamole/app/router/route_guards.dart';
import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:fantastic_guacamole/features/admin/ui/product_advisor_screen.dart';
import 'package:fantastic_guacamole/features/auth/screens/auth_gate.dart';
import 'package:fantastic_guacamole/features/notifications/ui/notification_screen.dart';
import 'package:fantastic_guacamole/features/onboarding/ui/onboarding_screen.dart';
import 'package:fantastic_guacamole/features/paywall/ui/paywall_page.dart';
import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
import 'package:fantastic_guacamole/state/controllers/app_flow_controller.dart';
import 'package:fantastic_guacamole/state/providers/access_provider.dart';
import 'package:fantastic_guacamole/state/providers/intelligence_provider.dart'
    hide authenticatedGuardProvider;
import 'package:fantastic_guacamole/ui/constants/app_urls.dart';
import 'package:fantastic_guacamole/ui/widgets/web_page_view.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final _appRouterRefreshListenableProvider =
    Provider<_AppRouterRefreshListenable>((ref) {
      final _AppRouterRefreshListenable listenable =
          _AppRouterRefreshListenable(ref);
      ref.onDispose(listenable.dispose);
      return listenable;
    });

const String restoreSavedTabQueryParameter = 'restoreSavedTab';

class _AppRouterRefreshListenable extends ChangeNotifier {
  _AppRouterRefreshListenable(this._ref) {
    _ref.listen<bool>(authenticatedGuardProvider, (_, _) => notifyListeners());
    _ref.listen<bool>(
      onboardingCompleteGuardProvider,
      (_, _) => notifyListeners(),
    );
    _ref.listen<bool>(
      onboardingWelcomeCompleteGuardProvider,
      (_, _) => notifyListeners(),
    );
    _ref.listen(intelligenceStateProvider, (_, _) => notifyListeners());
    _ref.listen(mockLoginConfigProvider, (_, _) => notifyListeners());
    _ref.listen(internalAdvisorAccessProvider, (_, _) => notifyListeners());
  }

  final Ref _ref;

  bool get isAuthenticated => _ref.read(authenticatedGuardProvider);
  bool get onboardingComplete => _ref.read(onboardingCompleteGuardProvider);
  bool get welcomeComplete => _ref.read(onboardingWelcomeCompleteGuardProvider);
  bool get hasInternalAdvisorAccess => _ref.read(internalAdvisorAccessProvider);
}

String _resolveInitialLocation({
  required bool isAuthenticated,
  required bool welcomeComplete,
  required bool onboardingComplete,
}) {
  if (!welcomeComplete) {
    return RoutePaths.onboarding;
  }
  if (!isAuthenticated) {
    return RoutePaths.login;
  }
  if (!onboardingComplete) {
    return RoutePaths.onboarding;
  }
  return Uri(
    path: RoutePaths.nexus,
    queryParameters: <String, String>{restoreSavedTabQueryParameter: 'true'},
  ).toString();
}

/// Pure decision logic for the top-level go_router redirect. Extracted so it
/// can be unit-tested (including fuzzed across input combinations) without
/// spinning up a [GoRouter]/widget tree. Returning `null` means "no top-level
/// redirect" — the request falls through to route matching, where a
/// per-route `redirect` (e.g. the legacy aliases below) may still apply.
String? computeAppRedirect({
  required bool isAuthenticated,
  required bool welcomeComplete,
  required bool onboardingComplete,
  required String location,
  Uri? uri,
  DeepLinkMode? deepLinkMode,
  bool isDebugBuild = kDebugMode,
  bool hasInternalAdvisorAccess = false,
}) {
  final Uri requestUri = uri ?? Uri(path: location);
  final String effectiveLocation = location.isEmpty
      ? requestUri.path
      : location;
  final DeepLinkMode? effectiveDeepLinkMode =
      deepLinkMode ?? parseDeepLinkMode(requestUri.queryParameters['mode']);
  final String? currentReturnTo = RouteAccessPolicy.validatedReturnTo(
    requestUri.queryParameters[RouteAccessPolicy.returnToQueryParameter],
  );
  final String? requestedReturnTo =
      currentReturnTo ?? RouteAccessPolicy.returnToForRequestedUri(requestUri);
  final RouteAccessDecision decision = RouteAccessPolicy.classify(
    effectiveLocation,
  );

  if (decision.accessClass == RouteAccessClass.authentication) {
    if (RouteAccessPolicy.isAuthenticationCallback(effectiveDeepLinkMode)) {
      if (!isAuthenticated) {
        return null;
      }
      if (!welcomeComplete || !onboardingComplete) {
        return RouteAccessPolicy.withReturnTo(
          RoutePaths.onboarding,
          currentReturnTo,
        );
      }
      return currentReturnTo ?? RoutePaths.nexus;
    }
    if (!welcomeComplete) {
      return RouteAccessPolicy.withReturnTo(
        RoutePaths.onboarding,
        currentReturnTo,
      );
    }
    if (isAuthenticated) {
      if (!onboardingComplete) {
        return RouteAccessPolicy.withReturnTo(
          RoutePaths.onboarding,
          currentReturnTo,
        );
      }
      return currentReturnTo ?? RoutePaths.nexus;
    }
    return null;
  }

  if (decision.allowsSignedOutAccess &&
      decision.accessClass != RouteAccessClass.welcome) {
    return null;
  }

  if (decision.accessClass == RouteAccessClass.welcome) {
    if (!welcomeComplete || (isAuthenticated && !onboardingComplete)) {
      return null;
    }
    if (isAuthenticated) {
      return currentReturnTo ?? RoutePaths.nexus;
    }
    return RouteAccessPolicy.withReturnTo(RoutePaths.login, currentReturnTo);
  }

  if (!welcomeComplete) {
    return RouteAccessPolicy.withReturnTo(
      RoutePaths.onboarding,
      requestedReturnTo,
    );
  }

  if (decision.requiresAuthentication && !isAuthenticated) {
    return RouteAccessPolicy.withReturnTo(RoutePaths.login, requestedReturnTo);
  }

  if (decision.requiresCompletedOnboarding && !onboardingComplete) {
    return RouteAccessPolicy.withReturnTo(
      RoutePaths.onboarding,
      requestedReturnTo,
    );
  }

  if (decision.accessClass == RouteAccessClass.privilegedInternal &&
      (!isDebugBuild || !hasInternalAdvisorAccess)) {
    return RoutePaths.settings;
  }

  if (effectiveLocation == RoutePaths.shell ||
      effectiveLocation == RoutePaths.home) {
    return RoutePaths.nexus;
  }

  return null;
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final _AppRouterRefreshListenable refresh = ref.read(
    _appRouterRefreshListenableProvider,
  );
  final String initialLocation = _resolveInitialLocation(
    isAuthenticated: refresh.isAuthenticated,
    welcomeComplete: refresh.welcomeComplete,
    onboardingComplete: refresh.onboardingComplete,
  );

  final GoRouter router = GoRouter(
    initialLocation: initialLocation,
    debugLogDiagnostics: false,
    refreshListenable: refresh,
    errorBuilder: (BuildContext context, GoRouterState state) => RouteErrorPage(
      location: state.uri.toString(),
      error: state.error,
      isAuthenticated: refresh.isAuthenticated,
      welcomeComplete: refresh.welcomeComplete,
      onboardingComplete: refresh.onboardingComplete,
    ),
    redirect: (BuildContext context, GoRouterState state) {
      return computeAppRedirect(
        isAuthenticated: refresh.isAuthenticated,
        welcomeComplete: refresh.welcomeComplete,
        onboardingComplete: refresh.onboardingComplete,
        location: state.matchedLocation,
        uri: state.uri,
        hasInternalAdvisorAccess: refresh.hasInternalAdvisorAccess,
      );
    },
    routes: <RouteBase>[
      // Primary surfaces: Nexus, Timeline, Creator, and Settings.
      GoRoute(
        path: RoutePaths.onboarding,
        builder: (BuildContext context, GoRouterState state) =>
            const OnboardingScreen(),
      ),
      GoRoute(
        path: RoutePaths.nexus,
        builder: (BuildContext context, GoRouterState state) =>
            _navigationShellForRoute(state),
      ),
      GoRoute(path: RoutePaths.plan, redirect: (_, _) => RoutePaths.timeline),
      GoRoute(
        path: RoutePaths.creator,
        builder: (BuildContext context, GoRouterState state) =>
            _navigationShellForRoute(state),
      ),
      GoRoute(
        path: RoutePaths.settings,
        builder: (BuildContext context, GoRouterState state) =>
            _navigationShellForRoute(state),
      ),

      // Secondary and advanced routes.
      GoRoute(
        path: RoutePaths.notifications,
        builder: (BuildContext context, GoRouterState state) =>
            const NotificationsPage(),
      ),
      GoRoute(
        path: RoutePaths.logs,
        builder: (BuildContext context, GoRouterState state) =>
            _navigationShellForRoute(state, fallback: AppView.timeline),
      ),
      GoRoute(
        path: RoutePaths.tasks,
        builder: (BuildContext context, GoRouterState state) =>
            _navigationShellForRoute(state, fallback: AppView.creator),
      ),
      GoRoute(
        path: RoutePaths.profile,
        builder: (BuildContext context, GoRouterState state) =>
            _navigationShellForRoute(state),
      ),
      GoRoute(
        path: RoutePaths.progression,
        builder: (BuildContext context, GoRouterState state) =>
            _navigationShellForRoute(state),
      ),
      GoRoute(
        path: RoutePaths.si,
        builder: (BuildContext context, GoRouterState state) =>
            _navigationShellForRoute(state),
      ),
      GoRoute(
        path: RoutePaths.timeline,
        builder: (BuildContext context, GoRouterState state) =>
            _navigationShellForRoute(state),
      ),
      GoRoute(
        path: RoutePaths.smartPlanner,
        builder: (BuildContext context, GoRouterState state) =>
            _navigationShellForRoute(state),
      ),
      GoRoute(
        path: RoutePaths.trajectoryEngine,
        builder: (BuildContext context, GoRouterState state) =>
            _navigationShellForRoute(state),
      ),
      GoRoute(
        path: RoutePaths.advisor,
        redirect: (_, _) => kDebugMode && refresh.hasInternalAdvisorAccess
            ? null
            : RoutePaths.settings,
        builder: (BuildContext context, GoRouterState state) =>
            const ProductAdvisorScreen(),
      ),

      // Legacy top-level routes redirect into the secondary hierarchy.
      // Sunset target is tracked in docs/LEGACY_ROUTE_SUNSET.md and reviewed by 2026-10-01.
      GoRoute(path: RoutePaths.legacyLogs, redirect: (_, _) => RoutePaths.logs),
      GoRoute(
        path: RoutePaths.legacyNotifications,
        redirect: (_, _) => RoutePaths.notifications,
      ),
      GoRoute(
        path: RoutePaths.legacyProgression,
        redirect: (_, _) => RoutePaths.progression,
      ),
      GoRoute(path: RoutePaths.legacySi, redirect: (_, _) => RoutePaths.si),
      GoRoute(
        path: RoutePaths.legacyTasks,
        redirect: (_, _) => RoutePaths.tasks,
      ),
      GoRoute(
        path: RoutePaths.legacyProfile,
        redirect: (_, _) => RoutePaths.profile,
      ),
      GoRoute(
        path: RoutePaths.legacyInsights,
        redirect: (_, _) => RoutePaths.smartPlanner,
      ),

      GoRoute(
        path: RoutePaths.login,
        builder: (BuildContext context, GoRouterState state) {
          final intelligence = ref.read(intelligenceStateProvider);
          final mockLoginConfig = ref.read(mockLoginConfigProvider);
          return AuthGate(
            enableMockLogin:
                intelligence.flags.mockLoginEnabled ||
                intelligence.flags.testerFullAccess,
            mockLoginEmail: mockLoginConfig.email,
            mockLoginPassword: mockLoginConfig.password,
            deepLinkMode: parseDeepLinkMode(state.uri.queryParameters['mode']),
            child: _navigationShellForRoute(state),
          );
        },
      ),
      GoRoute(
        path: RoutePaths.paywall,
        builder: (BuildContext context, GoRouterState state) =>
            const PaywallPage(),
      ),
      GoRoute(
        path: RoutePaths.privacy,
        builder: (BuildContext context, GoRouterState state) {
          final ChronoSparkLocalizations l10n = ChronoSparkLocalizations.of(
            context,
          );
          return WebPageView(
            title: l10n.text(ChronoSparkString.privacyPolicyTitle),
            body: l10n.text(ChronoSparkString.privacyPolicyBody),
            externalUrl: AppUrls.privacy,
            callToActionLabel: l10n.text(
              ChronoSparkString.openHostedPrivacyPolicy,
            ),
          );
        },
      ),
      GoRoute(
        path: RoutePaths.deleteAccount,
        builder: (BuildContext context, GoRouterState state) {
          final ChronoSparkLocalizations l10n = ChronoSparkLocalizations.of(
            context,
          );
          return WebPageView(
            title: l10n.text(ChronoSparkString.deleteAccountTitle),
            body: l10n.text(ChronoSparkString.deleteAccountBody),
            externalUrl: AppUrls.deleteAccount,
            callToActionLabel: l10n.text(
              ChronoSparkString.openHostedDeleteAccountPage,
            ),
          );
        },
      ),
      GoRoute(
        path: RoutePaths.terms,
        builder: (BuildContext context, GoRouterState state) {
          final ChronoSparkLocalizations l10n = ChronoSparkLocalizations.of(
            context,
          );
          return WebPageView(
            title: l10n.text(ChronoSparkString.termsTitle),
            body: l10n.text(ChronoSparkString.termsBody),
            externalUrl: AppUrls.terms,
            callToActionLabel: l10n.text(ChronoSparkString.openHostedTerms),
          );
        },
      ),
      GoRoute(
        path: RoutePaths.support,
        builder: (BuildContext context, GoRouterState state) {
          final ChronoSparkLocalizations l10n = ChronoSparkLocalizations.of(
            context,
          );
          return WebPageView(
            title: l10n.text(ChronoSparkString.supportTitle),
            body: l10n.text(ChronoSparkString.supportBody),
            externalUrl: AppUrls.support,
            callToActionLabel: l10n.text(
              ChronoSparkString.openHostedSupportPage,
            ),
          );
        },
      ),
      GoRoute(
        path: RoutePaths.about,
        builder: (BuildContext context, GoRouterState state) =>
            const AboutPage(),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

NavigationShell _navigationShellForRoute(
  GoRouterState state, {
  AppView fallback = AppView.nexus,
}) {
  return NavigationShell(
    initialView: appViewFromRoutePath(state.matchedLocation) ?? fallback,
    allowSavedTabRestore:
        state.matchedLocation == RoutePaths.nexus &&
        state.uri.queryParameters[restoreSavedTabQueryParameter] == 'true',
  );
}
