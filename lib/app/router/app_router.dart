import 'package:fantastic_guacamole/app/navigation_shell.dart';
import 'package:fantastic_guacamole/app/router/route_guards.dart';
import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:fantastic_guacamole/features/auth/screens/auth_gate.dart';
import 'package:fantastic_guacamole/features/coach/ui/coach_screen.dart';
import 'package:fantastic_guacamole/features/creator/ui/creator_screen.dart';
import 'package:fantastic_guacamole/features/focus/ui/focus_screen.dart';
import 'package:fantastic_guacamole/features/insights/ui/insight_screen.dart';
import 'package:fantastic_guacamole/features/logs/ui/logs_screen.dart';
import 'package:fantastic_guacamole/features/nexus/ui/nexus_screen.dart';
import 'package:fantastic_guacamole/features/notifications/ui/notification_screen.dart';
import 'package:fantastic_guacamole/features/paywall/ui/paywall_page.dart';
import 'package:fantastic_guacamole/features/plan/ui/plan_screen.dart';
import 'package:fantastic_guacamole/features/profile/ui/profile_screen.dart';
import 'package:fantastic_guacamole/features/progression/ui/progression_screen.dart';
import 'package:fantastic_guacamole/features/reflect/ui/reflect_screen.dart';
import 'package:fantastic_guacamole/features/settings/ui/settings_screen.dart';
import 'package:fantastic_guacamole/features/si_console/ui/si_console_screen.dart';
import 'package:fantastic_guacamole/features/tasks/ui/task_screen.dart';
import 'package:fantastic_guacamole/onboarding/onboarding_screen.dart';
import 'package:fantastic_guacamole/ui/widgets/web_page_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final bool onboardingComplete = ref.watch(onboardingCompleteGuardProvider);
  final bool isAuthenticated = ref.watch(authenticatedGuardProvider);
  final bool hasPremiumAccess = ref.watch(premiumAccessGuardProvider);
  final intelligence = ref.watch(intelligenceStateProvider);
  final mockLoginConfig = ref.watch(mockLoginConfigProvider);

  return GoRouter(
    initialLocation: RoutePaths.home,
    debugLogDiagnostics: false,
    redirect: (BuildContext context, GoRouterState state) {
      final String location = state.matchedLocation;

      if (location == RoutePaths.shell &&
          onboardingComplete &&
          isAuthenticated) {
        return RoutePaths.home;
      }

      if (location == RoutePaths.onboarding && onboardingComplete) {
        return isAuthenticated ? RoutePaths.home : RoutePaths.login;
      }

      if (!onboardingComplete && location != RoutePaths.onboarding) {
        return RoutePaths.onboarding;
      }

      if (!isAuthenticated &&
          location != RoutePaths.login &&
          location != RoutePaths.onboarding) {
        return RoutePaths.login;
      }

      if (location == RoutePaths.login && isAuthenticated) {
        return RoutePaths.home;
      }

      if (!hasPremiumAccess &&
          (location == RoutePaths.feature1 ||
              location == RoutePaths.feature2 ||
              location == RoutePaths.feature3)) {
        return RoutePaths.paywall;
      }

      return null;
    },
    routes: <RouteBase>[
      ShellRoute(
        builder: (BuildContext context, GoRouterState state, Widget child) {
          return Scaffold(body: child);
        },
        routes: <RouteBase>[
          GoRoute(
            path: RoutePaths.home,
            builder: (BuildContext context, GoRouterState state) =>
                const NavigationShell(),
          ),
        ],
      ),
      GoRoute(
        path: RoutePaths.coach,
        builder: (BuildContext context, GoRouterState state) =>
            const CoachScreen(),
      ),
      GoRoute(
        path: RoutePaths.focus,
        builder: (BuildContext context, GoRouterState state) =>
            const FocusScreen(),
      ),
      GoRoute(
        path: RoutePaths.plan,
        builder: (BuildContext context, GoRouterState state) =>
            const PlanScreen(),
      ),
      GoRoute(
        path: RoutePaths.create,
        builder: (BuildContext context, GoRouterState state) =>
            const CreatorScreen(),
      ),
      GoRoute(
        path: RoutePaths.creator,
        builder: (BuildContext context, GoRouterState state) =>
            const CreatorScreen(),
      ),
      GoRoute(
        path: RoutePaths.reflect,
        builder: (BuildContext context, GoRouterState state) =>
            const ReflectScreen(),
      ),
      GoRoute(
        path: RoutePaths.insights,
        builder: (BuildContext context, GoRouterState state) =>
            const InsightScreen(),
      ),
      GoRoute(
        path: RoutePaths.logs,
        builder: (BuildContext context, GoRouterState state) =>
            const LogsScreen(),
      ),
      GoRoute(
        path: RoutePaths.nexus,
        builder: (BuildContext context, GoRouterState state) =>
            const NexusScreen(),
      ),
      GoRoute(
        path: RoutePaths.notifications,
        builder: (BuildContext context, GoRouterState state) =>
            const NotificationsPage(),
      ),
      GoRoute(
        path: RoutePaths.progression,
        builder: (BuildContext context, GoRouterState state) =>
            const ProgressionScreen(),
      ),
      GoRoute(
        path: RoutePaths.temporal,
        builder: (BuildContext context, GoRouterState state) =>
            const ProgressionScreen(),
      ),
      GoRoute(
        path: RoutePaths.si,
        builder: (BuildContext context, GoRouterState state) =>
            hasPremiumAccess ? const SIConsoleScreen() : const PaywallPage(),
      ),
      GoRoute(
        path: RoutePaths.tasks,
        builder: (BuildContext context, GoRouterState state) =>
            const TaskScreen(),
      ),
      GoRoute(
        path: RoutePaths.profile,
        builder: (BuildContext context, GoRouterState state) =>
            const ProfileScreen(),
      ),
      GoRoute(
        path: RoutePaths.onboarding,
        builder: (BuildContext context, GoRouterState state) =>
            const OnboardingScreen(),
      ),
      GoRoute(
        path: RoutePaths.login,
        builder: (BuildContext context, GoRouterState state) => AuthGate(
          enableMockLogin: intelligence.flags.mockLoginEnabled,
          mockLoginEmail: mockLoginConfig.email,
          mockLoginPassword: mockLoginConfig.password,
          child: const NavigationShell(),
        ),
      ),
      GoRoute(
        path: RoutePaths.settings,
        builder: (BuildContext context, GoRouterState state) =>
            const SettingsScreen(),
      ),
      GoRoute(
        path: RoutePaths.paywall,
        builder: (BuildContext context, GoRouterState state) =>
            const PaywallPage(),
      ),
      GoRoute(
        path: RoutePaths.privacy,
        builder: (BuildContext context, GoRouterState state) =>
            const WebPageView(title: 'Privacy', body: 'Privacy route scaffold'),
      ),
      GoRoute(
        path: RoutePaths.terms,
        builder: (BuildContext context, GoRouterState state) =>
            const WebPageView(title: 'Terms', body: 'Terms route scaffold'),
      ),
      GoRoute(
        path: RoutePaths.support,
        builder: (BuildContext context, GoRouterState state) =>
            const WebPageView(title: 'Support', body: 'Support route scaffold'),
      ),
      GoRoute(
        path: RoutePaths.about,
        builder: (BuildContext context, GoRouterState state) =>
            const WebPageView(title: 'About', body: 'About route scaffold'),
      ),
      GoRoute(
        path: RoutePaths.feature1,
        builder: (BuildContext context, GoRouterState state) =>
            const WebPageView(title: 'Feature 1', body: 'Feature 1 scaffold'),
      ),
      GoRoute(
        path: RoutePaths.feature2,
        builder: (BuildContext context, GoRouterState state) =>
            const WebPageView(title: 'Feature 2', body: 'Feature 2 scaffold'),
      ),
      GoRoute(
        path: RoutePaths.feature3,
        builder: (BuildContext context, GoRouterState state) =>
            const WebPageView(
              title: 'Feature 3',
              body: 'Premium route scaffold',
            ),
      ),
    ],
  );
});
