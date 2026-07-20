import 'package:fantastic_guacamole/app/navigation_shell.dart';
import 'package:fantastic_guacamole/app/router/info_pages.dart';
import 'package:fantastic_guacamole/app/router/route_guards.dart';
import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:fantastic_guacamole/features/admin/ui/product_advisor_screen.dart';
import 'package:fantastic_guacamole/features/auth/screens/auth_gate.dart';
import 'package:fantastic_guacamole/features/monetization/presentation/screens/credit_history_screen.dart';
import 'package:fantastic_guacamole/features/monetization/presentation/screens/credit_store_screen.dart';
import 'package:fantastic_guacamole/features/monetization/presentation/screens/paywall_screen.dart';
import 'package:fantastic_guacamole/features/monetization/presentation/plan_comparison_screen.dart';
import 'package:fantastic_guacamole/features/monetization/presentation/screens/subscription_management_screen.dart';
import 'package:fantastic_guacamole/features/notifications/ui/notification_screen.dart';
import 'package:fantastic_guacamole/features/onboarding/ui/onboarding_screen.dart';
import 'package:fantastic_guacamole/features/permissions/notification_permission_recovery_screen.dart';
import 'package:fantastic_guacamole/state/core/app_providers.dart'
  show OnboardingStatus;
import 'package:fantastic_guacamole/state/controllers/app_flow_controller.dart';
import 'package:fantastic_guacamole/state/providers/intelligence_provider.dart'
    hide authenticatedGuardProvider;
import 'package:fantastic_guacamole/system/notifications/notification_scheduler.dart';
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

class _AppRouterRefreshListenable extends ChangeNotifier {
  _AppRouterRefreshListenable(this._ref) {
    _ref.listen<bool>(authenticatedGuardProvider, (_, _) => notifyListeners());
    _ref.listen<bool>(
      onboardingCompleteGuardProvider,
      (_, _) => notifyListeners(),
    );
    _ref.listen<OnboardingStatus>(
      onboardingStatusGuardProvider,
      (_, _) => notifyListeners(),
    );
    _ref.listen<bool>(profileCompleteGuardProvider, (_, _) => notifyListeners());
    _ref.listen(intelligenceStateProvider, (_, _) => notifyListeners());
    _ref.listen(mockLoginConfigProvider, (_, _) => notifyListeners());
  }

  final Ref _ref;

  bool get isAuthenticated => _ref.read(authenticatedGuardProvider);
  bool get onboardingComplete => _ref.read(onboardingCompleteGuardProvider);
  OnboardingStatus get onboardingStatus => _ref.read(onboardingStatusGuardProvider);
  bool get hasValidProfile => _ref.read(profileCompleteGuardProvider);
}

String _resolveInitialLocation({
  required bool isAuthenticated,
  required OnboardingStatus onboardingStatus,
  required bool hasValidProfile,
}) {
  if (onboardingStatus == OnboardingStatus.unknown) {
    return RoutePaths.onboarding;
  }
  final bool onboardingComplete = onboardingStatus == OnboardingStatus.complete;
  if (!onboardingComplete) {
    return RoutePaths.onboarding;
  }
  if (!isAuthenticated) {
    return RoutePaths.login;
  }
  if (!hasValidProfile) {
    return RoutePaths.onboarding;
  }
  return RoutePaths.home;
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final _AppRouterRefreshListenable refresh = ref.read(
    _appRouterRefreshListenableProvider,
  );
  final String initialLocation = _resolveInitialLocation(
    isAuthenticated: refresh.isAuthenticated,
    onboardingStatus: refresh.onboardingStatus,
    hasValidProfile: refresh.hasValidProfile,
  );

  return GoRouter(
    initialLocation: initialLocation,
    debugLogDiagnostics: false,
    refreshListenable: refresh,
    errorBuilder: (BuildContext context, GoRouterState state) {
      return Scaffold(
        appBar: AppBar(title: const Text('Route not found')),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text('Unknown route: ${state.uri}'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.go(RoutePaths.home),
                child: const Text('Go to Home'),
              ),
            ],
          ),
        ),
      );
    },
    redirect: (BuildContext context, GoRouterState state) {
      final bool isAuthenticated = refresh.isAuthenticated;
      final OnboardingStatus onboardingStatus = refresh.onboardingStatus;
      if (onboardingStatus == OnboardingStatus.unknown) {
        return state.matchedLocation == RoutePaths.onboarding
            ? null
            : RoutePaths.onboarding;
      }

      final bool onboardingComplete =
          onboardingStatus == OnboardingStatus.complete;
        final bool hasValidProfile = ref.read(profileCompleteGuardProvider);
      final bool mockLoginEnabled = ref
          .read(intelligenceStateProvider)
          .flags
          .mockLoginEnabled;
      final bool hasPremiumAccess = ref.read(premiumAccessGuardProvider);
      final bool hasAdminAccess = ref.read(adminAccessGuardProvider);
      final String location = state.matchedLocation;
      final bool qaSkipOnboarding =
          !kReleaseMode && state.uri.queryParameters['qa_skip_onboarding'] == '1';
      final String loginMode = (state.uri.queryParameters['mode'] ?? '')
          .trim()
          .toLowerCase();
      final bool allowLoginDuringOnboarding =
          location == RoutePaths.login &&
          (loginMode == 'recovery' ||
              loginMode == 'verify-email' ||
              loginMode == 'auth-callback');

      final bool premiumOnlyLocation = location == RoutePaths.advisor;
      if (premiumOnlyLocation && !hasPremiumAccess) {
        return RoutePaths.paywall;
      }

      if (location == RoutePaths.advisor && !hasAdminAccess) {
        return RoutePaths.settings;
      }

      if (location == RoutePaths.notificationPermissionRecovery &&
          NotificationScheduler.permissionGrantedListenable.value == true) {
        return RoutePaths.notifications;
      }

      if (!onboardingComplete && location != RoutePaths.onboarding) {
        if (allowLoginDuringOnboarding) {
          return null;
        }
        if (qaSkipOnboarding && mockLoginEnabled && location == RoutePaths.login) {
          return null;
        }
        return RoutePaths.onboarding;
      }

      if (isAuthenticated && onboardingComplete && !hasValidProfile) {
        if (location == RoutePaths.onboarding) {
          return null;
        }
        return RoutePaths.onboarding;
      }

      if (location == RoutePaths.shell && isAuthenticated) {
        return RoutePaths.home;
      }

      if (location == RoutePaths.onboarding) {
        if (!onboardingComplete || (isAuthenticated && !hasValidProfile)) {
          return null;
        }
        if (isAuthenticated) {
          return RoutePaths.home;
        }
        return RoutePaths.login;
      }

      if (!isAuthenticated &&
          onboardingComplete &&
          location != RoutePaths.login) {
        return RoutePaths.login;
      }

      if (location == RoutePaths.login &&
          !onboardingComplete &&
          !mockLoginEnabled) {
        return RoutePaths.onboarding;
      }

      if (location == RoutePaths.login && isAuthenticated) {
        return RoutePaths.home;
      }

      return null;
    },
    routes: <RouteBase>[
      GoRoute(path: RoutePaths.shell, redirect: (_, _) => RoutePaths.home),

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
        path: RoutePaths.notificationPermissionRecovery,
        builder: (BuildContext context, GoRouterState state) =>
            const NotificationPermissionRecoveryScreen(),
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
      GoRoute(
        path: RoutePaths.advisor,
        builder: (BuildContext context, GoRouterState state) =>
            const ProductAdvisorScreen(),
      ),

      // Legacy top-level routes redirect into the secondary hierarchy.
      // Sunset target is tracked in docs/LEGACY_ROUTE_SUNSET.md and reviewed by 2026-10-01.
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
        builder: (BuildContext context, GoRouterState state) {
          final intelligence = ref.read(intelligenceStateProvider);
          final mockLoginConfig = ref.read(mockLoginConfigProvider);
          return AuthGate(
            enableMockLogin:
                intelligence.flags.mockLoginEnabled ||
                intelligence.flags.testerFullAccess,
            mockLoginEmail: mockLoginConfig.email,
            mockLoginPassword: mockLoginConfig.password,
            deepLinkMode: state.uri.queryParameters['mode'],
            child: const NavigationShell(),
          );
        },
      ),
      GoRoute(
        path: RoutePaths.paywall,
        builder: (BuildContext context, GoRouterState state) =>
            const PaywallScreen(),
      ),
      GoRoute(
        path: RoutePaths.planComparison,
        builder: (BuildContext context, GoRouterState state) =>
            const PlanComparisonScreen(),
      ),
      GoRoute(
        path: RoutePaths.creditStore,
        builder: (BuildContext context, GoRouterState state) =>
            const CreditStoreScreen(),
      ),
      GoRoute(
        path: RoutePaths.creditHistory,
        builder: (BuildContext context, GoRouterState state) =>
            const CreditHistoryScreen(),
      ),
      GoRoute(
        path: RoutePaths.subscriptionManagement,
        builder: (BuildContext context, GoRouterState state) =>
            const SubscriptionManagementScreen(),
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
