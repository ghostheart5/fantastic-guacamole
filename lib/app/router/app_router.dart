import 'package:fantastic_guacamole/app/navigation_shell.dart';
import 'package:fantastic_guacamole/app/router/app_route_registry.dart';
import 'package:fantastic_guacamole/app/router/deep_link_service.dart';
import 'package:fantastic_guacamole/app/router/info_pages.dart';
import 'package:fantastic_guacamole/app/router/route_access_policy.dart';
import 'package:fantastic_guacamole/app/router/route_guards.dart';
import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:fantastic_guacamole/config/launch_containment.dart';
import 'package:fantastic_guacamole/config/env.dart';
import 'package:fantastic_guacamole/features/admin/ui/product_advisor_screen.dart';
import 'package:fantastic_guacamole/features/auth/screens/auth_gate.dart';
import 'package:fantastic_guacamole/features/auth/ui/account_deletion_status_panel.dart';
import 'package:fantastic_guacamole/features/notifications/ui/notification_screen.dart';
import 'package:fantastic_guacamole/features/onboarding/ui/onboarding_screen.dart';
import 'package:fantastic_guacamole/features/paywall/ui/paywall_page.dart';
import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
import 'package:fantastic_guacamole/state/controllers/app_flow_controller.dart';
import 'package:fantastic_guacamole/state/providers/access_provider.dart';
import 'package:fantastic_guacamole/state/providers/auth_provider.dart';
import 'package:fantastic_guacamole/state/providers/intelligence_provider.dart'
    hide authenticatedGuardProvider;
import 'package:fantastic_guacamole/ui/constants/app_assets.dart';
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
const ValueKey<String> _navigationShellPageKey = ValueKey<String>(
  'chronospark-navigation-shell',
);

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
    _ref.listen(internalAdvisorAccessProvider, (_, _) => notifyListeners());
    _ref.listen(passwordRecoveryStateProvider, (_, _) => notifyListeners());
  }

  final Ref _ref;

  bool get isAuthenticated => _ref.read(authenticatedGuardProvider);
  bool get onboardingComplete => _ref.read(onboardingCompleteGuardProvider);
  bool get welcomeComplete => _ref.read(onboardingWelcomeCompleteGuardProvider);
  bool get hasInternalAdvisorAccess => _ref.read(internalAdvisorAccessProvider);
  bool get passwordRecoveryPending =>
      _ref.read(passwordRecoveryStateProvider).asData?.value.isPending ?? false;
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
  bool passwordRecoveryPending = false,
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

  // Only SDK-verified state grants recovery. A URL mode is merely a hint.
  // Keep the recovery form reachable before ordinary signed-in/onboarding rules.
  if (passwordRecoveryPending) {
    if (effectiveLocation == RoutePaths.login) return null;
    return Uri(
      path: RoutePaths.login,
      queryParameters: const <String, String>{'mode': 'recovery'},
    ).toString();
  }

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
        passwordRecoveryPending: refresh.passwordRecoveryPending,
      );
    },
    routes: <RouteBase>[
      // Entry and primary surfaces: onboarding, Nexus, Creator, and Settings.
      GoRoute(
        path: RoutePaths.onboarding,
        builder: (BuildContext context, GoRouterState state) {
          final String? returnTo = RouteAccessPolicy.validatedReturnTo(
            state.uri.queryParameters[RouteAccessPolicy.returnToQueryParameter],
          );
          return OnboardingScreen(
            loginLocation: RouteAccessPolicy.withReturnTo(
              RoutePaths.login,
              returnTo,
            ),
            // A validated deep link remains authoritative. With no pending
            // intent, onboarding chooses Smart Planner or Nexus from the
            // person's explicit final-step action.
            completedLocation: returnTo,
          );
        },
      ),
      GoRoute(
        path: RoutePaths.nexus,
        pageBuilder: (BuildContext context, GoRouterState state) =>
            _navigationShellPageForRoute(state),
      ),
      GoRoute(
        path: RoutePaths.creator,
        pageBuilder: (BuildContext context, GoRouterState state) =>
            _navigationShellPageForRoute(state),
      ),
      GoRoute(
        path: RoutePaths.creatorGoals,
        pageBuilder: (BuildContext context, GoRouterState state) =>
            _navigationShellPageForRoute(state),
      ),
      GoRoute(
        path: RoutePaths.settings,
        pageBuilder: (BuildContext context, GoRouterState state) =>
            _navigationShellPageForRoute(state),
      ),

      // Secondary and advanced routes.
      GoRoute(
        path: RoutePaths.notifications,
        builder: (BuildContext context, GoRouterState state) =>
            const NotificationsPage(),
      ),
      GoRoute(
        path: RoutePaths.logs,
        pageBuilder: (BuildContext context, GoRouterState state) =>
            _navigationShellPageForRoute(state, fallback: AppView.timeline),
      ),
      GoRoute(
        path: RoutePaths.tasks,
        pageBuilder: (BuildContext context, GoRouterState state) =>
            _navigationShellPageForRoute(state, fallback: AppView.creator),
      ),
      GoRoute(
        path: RoutePaths.profile,
        pageBuilder: (BuildContext context, GoRouterState state) =>
            _navigationShellPageForRoute(state),
      ),
      GoRoute(
        path: RoutePaths.progression,
        pageBuilder: (BuildContext context, GoRouterState state) =>
            _navigationShellPageForRoute(state),
      ),
      GoRoute(
        path: RoutePaths.si,
        pageBuilder: (BuildContext context, GoRouterState state) =>
            _navigationShellPageForRoute(state),
      ),
      GoRoute(
        path: RoutePaths.timeline,
        pageBuilder: (BuildContext context, GoRouterState state) =>
            _navigationShellPageForRoute(state),
      ),
      GoRoute(
        path: RoutePaths.smartPlanner,
        pageBuilder: (BuildContext context, GoRouterState state) =>
            _navigationShellPageForRoute(state),
      ),
      GoRoute(
        path: RoutePaths.trajectoryEngine,
        pageBuilder: (BuildContext context, GoRouterState state) =>
            _navigationShellPageForRoute(state),
      ),
      GoRoute(
        path: RoutePaths.advisor,
        redirect: (_, _) => kDebugMode && refresh.hasInternalAdvisorAccess
            ? null
            : RoutePaths.settings,
        builder: (BuildContext context, GoRouterState state) =>
            const ProductAdvisorScreen(),
      ),

      // Compatibility paths remain registered separately from canonical routes.
      for (final AppRouteCompatibility alias
          in AppRouteRegistry.routerCompatibilityRedirects)
        GoRoute(path: alias.path!, redirect: (_, _) => alias.targetPath),

      GoRoute(
        path: RoutePaths.login,
        builder: (BuildContext context, GoRouterState state) {
          final intelligence = ref.read(intelligenceStateProvider);
          final String? returnTo = RouteAccessPolicy.validatedReturnTo(
            state.uri.queryParameters[RouteAccessPolicy.returnToQueryParameter],
          );
          return AuthGate(
            enableMockLogin: intelligence.flags.mockLoginEnabled,
            deepLinkMode: parseDeepLinkMode(state.uri.queryParameters['mode']),
            onboardingLocation: RouteAccessPolicy.withReturnTo(
              RoutePaths.onboarding,
              returnTo,
            ),
            child: _navigationShellForRoute(state),
          );
        },
      ),
      GoRoute(
        path: RoutePaths.paywall,
        redirect: (_, _) =>
            LaunchContainment.subscriptionsEnabled ? null : RoutePaths.settings,
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
            assetPath: AppAssets.legalPrivacyTxt,
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
          if (Env.isLocalMode) {
            final bool spanish =
                Localizations.localeOf(context).languageCode == 'es';
            return WebPageView(
              title: spanish ? 'Eliminar perfil local' : 'Delete local profile',
              body: spanish
                  ? 'Abre tu perfil local y ve a Ajustes > Datos y cuenta > Eliminar perfil local. Confirma para eliminar permanentemente el perfil y sus datos de este dispositivo. Si una eliminación anterior no terminó, usa Reintentar eliminación en la pantalla de perfil. No se crea ninguna cuenta en la nube en este modo.'
                  : 'Open your local profile, then go to Settings > Data & account > Delete Local Profile. Confirm to permanently remove that profile and its data from this device. If a previous deletion did not finish, use Retry deletion on the profile screen. No cloud account is created in this mode.',
            );
          }
          final ChronoSparkLocalizations l10n = ChronoSparkLocalizations.of(
            context,
          );
          return WebPageView(
            title: l10n.text(ChronoSparkString.deleteAccountTitle),
            body: l10n.text(ChronoSparkString.deleteAccountBody),
            assetPath: AppAssets.legalDeleteAccountTxt,
            externalUrl: AppUrls.deleteAccount,
            callToActionLabel: l10n.text(
              ChronoSparkString.openHostedDeleteAccountPage,
            ),
            additionalContent: const AccountDeletionStatusPanel(),
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
            assetPath: AppAssets.legalTermsTxt,
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
            assetPath: AppAssets.legalSupportTxt,
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

Page<void> _navigationShellPageForRoute(
  GoRouterState state, {
  AppView fallback = AppView.nexus,
}) {
  return NoTransitionPage<void>(
    key: _navigationShellPageKey,
    child: _navigationShellForRoute(state, fallback: fallback),
  );
}
