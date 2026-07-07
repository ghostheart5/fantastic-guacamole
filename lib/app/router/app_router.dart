import 'package:fantastic_guacamole/app/navigation_shell.dart';
import 'package:fantastic_guacamole/app/router/route_guards.dart';
import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:fantastic_guacamole/features/auth/screens/auth_gate.dart';
import 'package:fantastic_guacamole/features/notifications/ui/notification_screen.dart';
import 'package:fantastic_guacamole/features/paywall/ui/paywall_page.dart';
import 'package:fantastic_guacamole/onboarding/onboarding_screen.dart';
import 'package:fantastic_guacamole/state/controllers/app_flow_controller.dart';
import 'package:fantastic_guacamole/state/providers/intelligence_provider.dart'
    hide authenticatedGuardProvider;
import 'package:fantastic_guacamole/ui/widgets/web_page_view.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final bool isAuthenticated = ref.watch(authenticatedGuardProvider);
  final bool onboardingComplete = ref.watch(onboardingCompleteGuardProvider);
  final intelligence = ref.watch(intelligenceStateProvider);
  final mockLoginConfig = ref.watch(mockLoginConfigProvider);

  return GoRouter(
    initialLocation: RoutePaths.home,
    debugLogDiagnostics: false,
    redirect: (BuildContext context, GoRouterState state) {
      final String location = state.matchedLocation;

      if (!onboardingComplete && location != RoutePaths.onboarding) {
        return RoutePaths.onboarding;
      }

      if (location == RoutePaths.shell && isAuthenticated) {
        return RoutePaths.home;
      }

      if (location == RoutePaths.onboarding) {
        if (isAuthenticated) {
          return RoutePaths.home;
        }
        if (!onboardingComplete) {
          return null;
        }
        return RoutePaths.login;
      }

      if (!isAuthenticated &&
          onboardingComplete &&
          location != RoutePaths.login) {
        return RoutePaths.login;
      }

      if (location == RoutePaths.login && !onboardingComplete) {
        return RoutePaths.onboarding;
      }

      if (location == RoutePaths.login && isAuthenticated) {
        return RoutePaths.home;
      }

      return null;
    },
    routes: <RouteBase>[
      // Primary surfaces: Now, Plan, Add, Reflect, Settings.
      GoRoute(
        path: RoutePaths.onboarding,
        builder: (BuildContext context, GoRouterState state) =>
            const OnboardingScreen(),
      ),
      GoRoute(
        path: RoutePaths.home,
        builder: (BuildContext context, GoRouterState state) =>
            const NavigationShell(),
      ),
      GoRoute(
        path: RoutePaths.plan,
        builder: (BuildContext context, GoRouterState state) =>
            const NavigationShell(initialView: AppView.plan),
      ),
      GoRoute(
        path: RoutePaths.creator,
        builder: (BuildContext context, GoRouterState state) =>
            const NavigationShell(initialView: AppView.creator),
      ),
      GoRoute(
        path: RoutePaths.insights,
        builder: (BuildContext context, GoRouterState state) =>
            const NavigationShell(initialView: AppView.insight),
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
            const NavigationShell(initialTabIndex: 2),
      ),
      GoRoute(
        path: RoutePaths.tasks,
        builder: (BuildContext context, GoRouterState state) =>
            const NavigationShell(initialTabIndex: 1),
      ),
      GoRoute(
        path: RoutePaths.profile,
        builder: (BuildContext context, GoRouterState state) =>
            const NavigationShell(initialTabIndex: 3),
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

      // Legacy top-level routes redirect into the secondary hierarchy.
      GoRoute(
        path: RoutePaths.legacyCoach,
        redirect: (_, _) => RoutePaths.home,
      ),
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
        builder: (BuildContext context, GoRouterState state) => AuthGate(
          enableMockLogin: intelligence.flags.mockLoginEnabled || !kReleaseMode,
          mockLoginEmail: mockLoginConfig.email,
          mockLoginPassword: mockLoginConfig.password,
          child: const NavigationShell(),
        ),
      ),
      GoRoute(
        path: RoutePaths.paywall,
        builder: (BuildContext context, GoRouterState state) =>
            const PaywallPage(),
      ),
      GoRoute(
        path: RoutePaths.privacy,
        builder: (BuildContext context, GoRouterState state) =>
            const WebPageView(
              title: 'Privacy Policy',
              assetPath: 'assets/legal/privacy_policy.txt',
            ),
      ),
      GoRoute(
        path: RoutePaths.terms,
        builder: (BuildContext context, GoRouterState state) =>
            const WebPageView(
              title: 'Terms of Service',
              assetPath: 'assets/legal/terms_of_service.txt',
            ),
      ),
      GoRoute(
        path: RoutePaths.support,
        builder: (BuildContext context, GoRouterState state) =>
            const WebPageView(
              title: 'Support',
              body: 'For support, contact ghostheart131517@gmail.com',
            ),
      ),
      GoRoute(
        path: RoutePaths.about,
        builder: (BuildContext context, GoRouterState state) =>
            const WebPageView(title: 'About', body: 'ChronoSpark'),
      ),
    ],
  );
});
