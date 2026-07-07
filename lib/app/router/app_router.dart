import 'package:fantastic_guacamole/app/navigation_shell.dart';
import 'package:fantastic_guacamole/app/router/info_pages.dart';
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
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final _appRouterRefreshListenableProvider = Provider<_AppRouterRefreshListenable>((ref) {
  final _AppRouterRefreshListenable listenable = _AppRouterRefreshListenable(ref);
  ref.onDispose(listenable.dispose);
  return listenable;
});

class _AppRouterRefreshListenable extends ChangeNotifier {
  _AppRouterRefreshListenable(this._ref) {
    _ref.listen<bool>(authenticatedGuardProvider, (_, _) => notifyListeners());
    _ref.listen<bool>(onboardingCompleteGuardProvider, (_, _) => notifyListeners());
    _ref.listen(intelligenceStateProvider, (_, _) => notifyListeners());
    _ref.listen(mockLoginConfigProvider, (_, _) => notifyListeners());
  }

  final Ref _ref;

  bool get isAuthenticated => _ref.read(authenticatedGuardProvider);
  bool get onboardingComplete => _ref.read(onboardingCompleteGuardProvider);
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final _AppRouterRefreshListenable refresh = ref.read(_appRouterRefreshListenableProvider);

  return GoRouter(
    initialLocation: RoutePaths.home,
    debugLogDiagnostics: false,
    refreshListenable: refresh,
    redirect: (BuildContext context, GoRouterState state) {
      final bool isAuthenticated = refresh.isAuthenticated;
      final bool onboardingComplete = refresh.onboardingComplete;
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

      if (!isAuthenticated && onboardingComplete && location != RoutePaths.login) {
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
        builder: (BuildContext context, GoRouterState state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: RoutePaths.home,
        builder: (BuildContext context, GoRouterState state) => const NavigationShell(),
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
        builder: (BuildContext context, GoRouterState state) => const NotificationsPage(),
      ),
      GoRoute(
        path: RoutePaths.logs,
        builder: (BuildContext context, GoRouterState state) =>
            const NavigationShell(initialView: AppView.logs),
      ),
      GoRoute(
        path: RoutePaths.tasks,
        builder: (BuildContext context, GoRouterState state) =>
            const NavigationShell(initialView: AppView.tasks),
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

      // Legacy top-level routes redirect into the secondary hierarchy.
      // Sunset target is tracked in docs/LEGACY_ROUTE_SUNSET.md and reviewed by 2026-10-01.
      GoRoute(path: RoutePaths.legacyCoach, redirect: (_, _) => RoutePaths.home),
      GoRoute(path: RoutePaths.legacyLogs, redirect: (_, _) => RoutePaths.logs),
      GoRoute(path: RoutePaths.legacyNotifications, redirect: (_, _) => RoutePaths.notifications),
      GoRoute(path: RoutePaths.legacyProgression, redirect: (_, _) => RoutePaths.progression),
      GoRoute(path: RoutePaths.legacySi, redirect: (_, _) => RoutePaths.si),
      GoRoute(path: RoutePaths.legacyTasks, redirect: (_, _) => RoutePaths.tasks),
      GoRoute(path: RoutePaths.legacyProfile, redirect: (_, _) => RoutePaths.profile),

      GoRoute(
        path: RoutePaths.login,
        builder: (BuildContext context, GoRouterState state) {
          final intelligence = ref.read(intelligenceStateProvider);
          final mockLoginConfig = ref.read(mockLoginConfigProvider);
          return AuthGate(
            enableMockLogin: intelligence.flags.mockLoginEnabled,
            mockLoginEmail: mockLoginConfig.email,
            mockLoginPassword: mockLoginConfig.password,
            child: const NavigationShell(),
          );
        },
      ),
      GoRoute(
        path: RoutePaths.paywall,
        builder: (BuildContext context, GoRouterState state) => const PaywallPage(),
      ),
      GoRoute(
        path: RoutePaths.privacy,
        builder: (BuildContext context, GoRouterState state) => const WebPageView(
          title: 'Privacy Policy',
          assetPath: 'assets/legal/privacy_policy.txt',
        ),
      ),
      GoRoute(
        path: RoutePaths.terms,
        builder: (BuildContext context, GoRouterState state) => const WebPageView(
          title: 'Terms of Service',
          assetPath: 'assets/legal/terms_of_service.txt',
        ),
      ),
      GoRoute(
        path: RoutePaths.support,
        builder: (BuildContext context, GoRouterState state) => const SupportPage(),
      ),
      GoRoute(
        path: RoutePaths.about,
        builder: (BuildContext context, GoRouterState state) => const AboutPage(),
      ),
    ],
  );
});
