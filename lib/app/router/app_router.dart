import 'package:fantastic_guacamole/app/navigation_shell.dart';
import 'package:fantastic_guacamole/app/router/deep_link_service.dart';
import 'package:fantastic_guacamole/app/router/info_pages.dart';
import 'package:fantastic_guacamole/app/router/route_guards.dart';
import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:fantastic_guacamole/features/admin/ui/product_advisor_screen.dart';
import 'package:fantastic_guacamole/features/auth/screens/auth_gate.dart';
import 'package:fantastic_guacamole/features/notifications/ui/notification_screen.dart';
import 'package:fantastic_guacamole/features/onboarding/ui/onboarding_screen.dart';
import 'package:fantastic_guacamole/features/paywall/ui/paywall_page.dart';
import 'package:fantastic_guacamole/state/controllers/app_flow_controller.dart';
import 'package:fantastic_guacamole/state/providers/intelligence_provider.dart'
    hide authenticatedGuardProvider;
import 'package:fantastic_guacamole/ui/constants/app_urls.dart';
import 'package:fantastic_guacamole/ui/widgets/web_page_view.dart';
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
  }

  final Ref _ref;

  bool get isAuthenticated => _ref.read(authenticatedGuardProvider);
  bool get onboardingComplete => _ref.read(onboardingCompleteGuardProvider);
  bool get welcomeComplete => _ref.read(onboardingWelcomeCompleteGuardProvider);
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
  return RoutePaths.nexus;
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
}) {
  if (!welcomeComplete && location != RoutePaths.onboarding) {
    return RoutePaths.onboarding;
  }

  if (welcomeComplete && !isAuthenticated && location != RoutePaths.login) {
    return RoutePaths.login;
  }

  if (welcomeComplete && isAuthenticated && !onboardingComplete) {
    return location == RoutePaths.onboarding ? null : RoutePaths.onboarding;
  }

  if (location == RoutePaths.shell && isAuthenticated) {
    return RoutePaths.nexus;
  }

  if (location == RoutePaths.home && isAuthenticated) {
    return RoutePaths.nexus;
  }

  if (location == RoutePaths.onboarding) {
    if (!welcomeComplete || (isAuthenticated && !onboardingComplete)) {
      return null;
    }
    if (isAuthenticated) {
      return RoutePaths.nexus;
    }
    return RoutePaths.login;
  }

  if (location == RoutePaths.login && !welcomeComplete) {
    return RoutePaths.onboarding;
  }

  if (location == RoutePaths.login && isAuthenticated) {
    return onboardingComplete ? RoutePaths.nexus : RoutePaths.onboarding;
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

  return GoRouter(
    initialLocation: initialLocation,
    debugLogDiagnostics: false,
    refreshListenable: refresh,
    redirect: (BuildContext context, GoRouterState state) {
      return computeAppRedirect(
        isAuthenticated: refresh.isAuthenticated,
        welcomeComplete: refresh.welcomeComplete,
        onboardingComplete: refresh.onboardingComplete,
        location: state.matchedLocation,
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
            const NavigationShell(),
      ),
      GoRoute(path: RoutePaths.plan, redirect: (_, _) => RoutePaths.timeline),
      GoRoute(
        path: RoutePaths.creator,
        builder: (BuildContext context, GoRouterState state) =>
            const NavigationShell(initialView: AppView.creator),
      ),
      GoRoute(
        path: RoutePaths.settings,
        builder: (BuildContext context, GoRouterState state) =>
            const NavigationShell(initialView: AppView.settings),
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
            const NavigationShell(initialView: AppView.timeline),
      ),
      GoRoute(
        path: RoutePaths.tasks,
        builder: (BuildContext context, GoRouterState state) =>
            const NavigationShell(initialView: AppView.creator),
      ),
      GoRoute(
        path: RoutePaths.profile,
        builder: (BuildContext context, GoRouterState state) =>
            const NavigationShell(initialView: AppView.profile),
      ),
      GoRoute(
        path: RoutePaths.progression,
        builder: (BuildContext context, GoRouterState state) =>
            const NavigationShell(initialView: AppView.progression),
      ),
      GoRoute(
        path: RoutePaths.si,
        builder: (BuildContext context, GoRouterState state) =>
            const NavigationShell(initialView: AppView.console),
      ),
      GoRoute(
        path: RoutePaths.timeline,
        builder: (BuildContext context, GoRouterState state) =>
            const NavigationShell(initialView: AppView.timeline),
      ),
      GoRoute(
        path: RoutePaths.smartPlanner,
        builder: (BuildContext context, GoRouterState state) =>
            const NavigationShell(initialView: AppView.smartPlanner),
      ),
      GoRoute(
        path: RoutePaths.trajectoryEngine,
        builder: (BuildContext context, GoRouterState state) =>
            const NavigationShell(initialView: AppView.trajectoryEngine),
      ),
      GoRoute(
        path: RoutePaths.advisor,
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
            child: const NavigationShell(),
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
        builder: (BuildContext context, GoRouterState state) => const WebPageView(
          title: 'Privacy Policy',
          body:
              'ChronoSpark publishes its authoritative privacy policy at the public HTTPS URL below. Use the hosted policy for the current data handling, retention, and support terms reviewed for release.',
          externalUrl: AppUrls.privacy,
          callToActionLabel: 'Open Hosted Privacy Policy',
        ),
      ),
      GoRoute(
        path: RoutePaths.deleteAccount,
        builder: (BuildContext context, GoRouterState state) => const WebPageView(
          title: 'Delete Account',
          body:
              'ChronoSpark publishes account deletion steps at the public HTTPS URL below. Use the hosted page to submit a deletion request and review deletion/retention details.',
          externalUrl: AppUrls.deleteAccount,
          callToActionLabel: 'Open Hosted Delete Account Page',
        ),
      ),
      GoRoute(
        path: RoutePaths.terms,
        builder: (BuildContext context, GoRouterState state) => const WebPageView(
          title: 'Terms of Service',
          body:
              'ChronoSpark maintains its current Terms of Service on the public HTTPS page below so release builds and store listings reference the same source of truth.',
          externalUrl: AppUrls.terms,
          callToActionLabel: 'Open Hosted Terms',
        ),
      ),
      GoRoute(
        path: RoutePaths.support,
        builder: (BuildContext context, GoRouterState state) => const WebPageView(
          title: 'Support',
          body:
              'ChronoSpark publishes release-facing support and account assistance at the public HTTPS URL below so store reviewers and users can reach the current support process from every build.',
          externalUrl: AppUrls.support,
          callToActionLabel: 'Open Hosted Support Page',
        ),
      ),
      GoRoute(
        path: RoutePaths.about,
        builder: (BuildContext context, GoRouterState state) =>
            const AboutPage(),
      ),
    ],
  );
});
