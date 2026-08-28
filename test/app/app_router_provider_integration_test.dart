import 'package:fantastic_guacamole/app/navigation_shell.dart';
import 'package:fantastic_guacamole/app/router/app_route_registry.dart';
import 'package:fantastic_guacamole/app/router/app_router.dart';
import 'package:fantastic_guacamole/app/router/info_pages.dart';
import 'package:fantastic_guacamole/app/router/route_guards.dart' as guards;
import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/notification_entity.dart';
import 'package:fantastic_guacamole/features/admin/ui/product_advisor_screen.dart';
import 'package:fantastic_guacamole/features/auth/screens/auth_gate.dart';
import 'package:fantastic_guacamole/features/nexus/ui/nexus_screen.dart';
import 'package:fantastic_guacamole/features/notifications/ui/notification_screen.dart';
import 'package:fantastic_guacamole/features/onboarding/ui/onboarding_screen.dart';
import 'package:fantastic_guacamole/features/paywall/ui/paywall_page.dart';
import 'package:fantastic_guacamole/features/timeline/ui/timeline_screen.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/system/notifications/notification_scheduler.dart';
import 'package:fantastic_guacamole/ui/widgets/web_page_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _authenticatedStateProvider = NotifierProvider<_TestBoolNotifier, bool>(
  _TestBoolNotifier.new,
);
final _welcomeCompleteStateProvider = NotifierProvider<_TestBoolNotifier, bool>(
  _TestBoolNotifier.new,
);
final _onboardingCompleteStateProvider =
    NotifierProvider<_TestBoolNotifier, bool>(_TestBoolNotifier.new);

class _TestBoolNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

void _setGuardState(
  ProviderContainer container, {
  required bool authenticated,
  required bool welcomeComplete,
  required bool onboardingComplete,
}) {
  container.read(_authenticatedStateProvider.notifier).set(authenticated);
  container.read(_welcomeCompleteStateProvider.notifier).set(welcomeComplete);
  container
      .read(_onboardingCompleteStateProvider.notifier)
      .set(onboardingComplete);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    NotificationScheduler.tappedPayloadListenable.value = null;
  });
  tearDown(() => NotificationScheduler.tappedPayloadListenable.value = null);

  group('appRouterProvider integration', () {
    testWidgets('selects initial location for all guard combinations', (
      WidgetTester tester,
    ) async {
      for (final _GuardCase item in _initialLocationCases) {
        final _RouterHarness harness = await _pumpRealRouter(
          tester,
          authenticated: item.authenticated,
          welcomeComplete: item.welcomeComplete,
          onboardingComplete: item.onboardingComplete,
        );
        await tester.pump();
        await tester.pump();

        _expectUri(harness, item.expectedPath);
        expect(find.byType(item.expectedWidget), findsWidgets);

        await tester.pumpWidget(const SizedBox.shrink());
        harness.dispose();
      }
    });

    testWidgets(
      'renders every registered canonical route through appRouterProvider',
      (WidgetTester tester) async {
        for (final _RouteExpectation item in _canonicalRouteExpectations) {
          final _RouterHarness harness = await _pumpRealRouter(
            tester,
            initialLocation: item.requestedPath,
            authenticated: true,
            welcomeComplete: true,
            onboardingComplete: true,
            internalAdvisorAccess: item.requestedPath == RoutePaths.advisor,
          );
          await tester.pump();
          await tester.pump();

          _expectUri(harness, item.finalPath);
          expect(find.byType(item.expectedWidget), findsWidgets);
          if (item.shellView != null) {
            expect(harness.container.read(appFlowProvider), item.shellView);
            expect(appViewFromRoutePath(item.finalPath), item.shellView);
          }

          await tester.pumpWidget(const SizedBox.shrink());
          harness.dispose();
        }
      },
    );

    testWidgets('direct advisor URL requires trusted internal authorization', (
      WidgetTester tester,
    ) async {
      final _RouterHarness denied = await _pumpRealRouter(
        tester,
        initialLocation: RoutePaths.advisor,
        authenticated: true,
        welcomeComplete: true,
        onboardingComplete: true,
        internalAdvisorAccess: false,
      );
      await tester.pump();
      await tester.pump();

      _expectUri(denied, RoutePaths.settings);
      expect(find.byType(NavigationShell), findsOneWidget);
      expect(find.byType(ProductAdvisorScreen), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      denied.dispose();

      final _RouterHarness allowed = await _pumpRealRouter(
        tester,
        initialLocation: RoutePaths.advisor,
        authenticated: true,
        welcomeComplete: true,
        onboardingComplete: true,
        internalAdvisorAccess: true,
      );
      await tester.pump();
      await tester.pump();

      _expectUri(allowed, RoutePaths.advisor);
      expect(find.byType(ProductAdvisorScreen), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      allowed.dispose();
    });

    testWidgets(
      'all registered compatibility redirects end at canonical routes',
      (WidgetTester tester) async {
        for (final _LegacyRouteExpectation item in _legacyRouteExpectations) {
          final _RouterHarness harness = await _pumpRealRouter(
            tester,
            initialLocation: item.legacyPath,
            authenticated: true,
            welcomeComplete: true,
            onboardingComplete: true,
          );
          await tester.pump();
          await tester.pump();

          _expectUri(harness, item.canonical.finalPath);
          expect(find.byType(item.canonical.expectedWidget), findsWidgets);
          if (item.canonical.shellView != null) {
            expect(
              harness.container.read(appFlowProvider),
              item.canonical.shellView,
            );
          }

          await tester.pumpWidget(const SizedBox.shrink());
          harness.dispose();
        }
      },
    );

    testWidgets('preserves full callback URIs and query parameters', (
      WidgetTester tester,
    ) async {
      for (final String mode in <String>[
        'recovery',
        'verify-email',
        'auth-callback',
      ]) {
        final String callbackUri = Uri(
          path: RoutePaths.login,
          queryParameters: <String, String>{
            'mode': mode,
            'returnTo': '${RoutePaths.timeline}?day=2026-08-19#block-7',
          },
        ).toString();
        final _RouterHarness harness = await _pumpRealRouter(
          tester,
          initialLocation: callbackUri,
          authenticated: false,
          welcomeComplete: false,
          onboardingComplete: false,
        );
        await tester.pump();
        await tester.pump();

        _expectUri(harness, RoutePaths.login);
        expect(
          harness
              .router
              .routeInformationProvider
              .value
              .uri
              .queryParameters['mode'],
          mode,
        );
        expect(
          harness
              .router
              .routeInformationProvider
              .value
              .uri
              .queryParameters['returnTo'],
          '${RoutePaths.timeline}?day=2026-08-19#block-7',
        );
        expect(find.byType(AuthGate), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
        harness.dispose();
      }
    });

    testWidgets('handles signed-out public and protected paths', (
      WidgetTester tester,
    ) async {
      for (final _RouteExpectation publicRoute in _signedOutPublicRoutes) {
        final _RouterHarness harness = await _pumpRealRouter(
          tester,
          initialLocation: publicRoute.requestedPath,
          authenticated: false,
          welcomeComplete: false,
          onboardingComplete: false,
        );
        await tester.pump();
        await tester.pump();

        _expectUri(harness, publicRoute.finalPath);
        expect(find.byType(publicRoute.expectedWidget), findsWidgets);

        await tester.pumpWidget(const SizedBox.shrink());
        harness.dispose();
      }

      for (final String protectedPath in <String>[
        RoutePaths.nexus,
        RoutePaths.creator,
        RoutePaths.timeline,
        RoutePaths.trajectoryEngine,
      ]) {
        final _RouterHarness harness = await _pumpRealRouter(
          tester,
          initialLocation: protectedPath,
          authenticated: false,
          welcomeComplete: true,
          onboardingComplete: true,
        );
        await tester.pump();
        await tester.pump();

        _expectUri(harness, RoutePaths.login);
        expect(_returnTo(harness), protectedPath);
        expect(find.byType(AuthGate), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
        harness.dispose();
      }
    });

    testWidgets('restores validated return destinations', (
      WidgetTester tester,
    ) async {
      final _RouterHarness harness = await _pumpRealRouter(
        tester,
        initialLocation:
            '${RoutePaths.login}?returnTo=%2Ftimeline%3Fday%3D2026-08-19%23block-7',
        authenticated: true,
        welcomeComplete: true,
        onboardingComplete: true,
      );
      await tester.pump();
      await tester.pump();

      _expectUri(harness, RoutePaths.timeline);
      expect(
        harness
            .router
            .routeInformationProvider
            .value
            .uri
            .queryParameters['day'],
        '2026-08-19',
      );
      expect(
        harness.router.routeInformationProvider.value.uri.fragment,
        'block-7',
      );
      expect(find.byType(NavigationShell), findsOneWidget);
      expect(harness.container.read(appFlowProvider), AppView.timeline);

      harness.dispose();
    });

    testWidgets(
      'removed and unknown authenticated paths render the router error destination',
      (WidgetTester tester) async {
        for (final String removedOrUnknownPath in <String>[
          '/coach',
          '/signals',
          '/unknown-route',
        ]) {
          final _RouterHarness harness = await _pumpRealRouter(
            tester,
            initialLocation: removedOrUnknownPath,
            authenticated: true,
            welcomeComplete: true,
            onboardingComplete: true,
          );
          await tester.pump();
          await tester.pump();

          _expectUri(harness, removedOrUnknownPath);
          expect(find.byType(NavigationShell), findsNothing);
          expect(find.byType(OnboardingScreen), findsNothing);
          expect(find.byType(AuthGate), findsNothing);

          await tester.pumpWidget(const SizedBox.shrink());
          harness.dispose();
        }
      },
    );

    testWidgets('repeated provider container disposal releases router state', (
      WidgetTester tester,
    ) async {
      for (int index = 0; index < 3; index++) {
        final _RouterHarness harness = await _pumpRealRouter(
          tester,
          authenticated: true,
          welcomeComplete: true,
          onboardingComplete: true,
        );
        await tester.pump();

        _expectUri(harness, RoutePaths.nexus);
        await tester.pumpWidget(const SizedBox.shrink());
        expect(harness.dispose, returnsNormally);
      }

      final _RouterHarness fresh = await _pumpRealRouter(
        tester,
        initialLocation: RoutePaths.timeline,
        authenticated: true,
        welcomeComplete: true,
        onboardingComplete: true,
      );
      await tester.pump();

      _expectUri(fresh, RoutePaths.timeline);
      expect(find.byType(NavigationShell), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      expect(fresh.dispose, returnsNormally);
    });

    testWidgets('primary routes retain one shell-owned service lifecycle', (
      WidgetTester tester,
    ) async {
      final _RouterHarness harness = await _pumpRealRouter(
        tester,
        initialLocation: RoutePaths.nexus,
        authenticated: true,
        welcomeComplete: true,
        onboardingComplete: true,
      );
      await tester.pump();

      final State<NavigationShell> originalShellState = tester.state(
        find.byType(NavigationShell),
      );

      for (final String route in <String>[
        RoutePaths.timeline,
        RoutePaths.trajectoryEngine,
        RoutePaths.profile,
        RoutePaths.nexus,
      ]) {
        harness.router.go(route);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        _expectUri(harness, route);
        expect(
          tester.state<State<NavigationShell>>(
            find.byType(NavigationShell).last,
          ),
          same(originalShellState),
          reason:
              'Primary route changes must not restart shell-owned services.',
        );
      }

      await tester.pumpWidget(const SizedBox.shrink());
      harness.dispose();
    });

    testWidgets('primary tab widget state survives URL-driven tab changes', (
      WidgetTester tester,
    ) async {
      final _RouterHarness harness = await _pumpRealRouter(
        tester,
        initialLocation: RoutePaths.nexus,
        authenticated: true,
        welcomeComplete: true,
        onboardingComplete: true,
      );
      await tester.pump();

      final Element originalNexusElement = tester.element(
        find.byType(NexusScreen),
      );

      harness.router.go(RoutePaths.timeline);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      _expectUri(harness, RoutePaths.timeline);
      expect(find.byType(TimelineScreen), findsOneWidget);
      expect(find.byType(NexusScreen, skipOffstage: false), findsOneWidget);
      final Element timelineElement = tester.element(
        find.byType(TimelineScreen),
      );
      expect(
        tester.element(find.byType(NexusScreen, skipOffstage: false)),
        same(originalNexusElement),
      );
      expect(TickerMode.valuesOf(originalNexusElement).enabled, isFalse);
      expect(TickerMode.valuesOf(timelineElement).enabled, isTrue);

      harness.router.go(RoutePaths.nexus);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      _expectUri(harness, RoutePaths.nexus);
      expect(
        tester.element(find.byType(NexusScreen)),
        same(originalNexusElement),
      );
      expect(
        tester.element(find.byType(TimelineScreen, skipOffstage: false)),
        same(timelineElement),
      );
      expect(TickerMode.valuesOf(originalNexusElement).enabled, isTrue);
      expect(TickerMode.valuesOf(timelineElement).enabled, isFalse);

      harness.router.go(RoutePaths.timeline);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        tester.element(find.byType(TimelineScreen)),
        same(timelineElement),
      );

      await tester.pumpWidget(const SizedBox.shrink());
      harness.dispose();
    });

    testWidgets('saved primary tab restores through the persistent shell', (
      WidgetTester tester,
    ) async {
      final _RouterHarness firstLaunch = await _pumpRealRouter(
        tester,
        initialLocation: RoutePaths.nexus,
        authenticated: true,
        welcomeComplete: true,
        onboardingComplete: true,
      );
      await tester.pump();

      await tester.tap(find.byTooltip('Timeline'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      _expectUri(firstLaunch, RoutePaths.timeline);
      expect(PreferenceService().getLastOpenedTab(), 2);

      await tester.pumpWidget(const SizedBox.shrink());
      firstLaunch.dispose();

      final _RouterHarness restoredLaunch = await _pumpRealRouter(
        tester,
        authenticated: true,
        welcomeComplete: true,
        onboardingComplete: true,
      );
      await tester.pump();
      await tester.pump();

      _expectUri(restoredLaunch, RoutePaths.timeline);
      expect(restoredLaunch.container.read(appFlowProvider), AppView.timeline);
      expect(find.byType(TimelineScreen), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      restoredLaunch.dispose();
    });

    testWidgets('notification routing retains the persistent shell owner', (
      WidgetTester tester,
    ) async {
      final _RouterHarness harness = await _pumpRealRouter(
        tester,
        initialLocation: RoutePaths.nexus,
        authenticated: true,
        welcomeComplete: true,
        onboardingComplete: true,
      );
      await tester.pump();

      final State<NavigationShell> shellState = tester.state(
        find.byType(NavigationShell),
      );
      NotificationScheduler.tappedPayloadListenable.value =
          'daily_planning_reminder';
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      _expectUri(harness, RoutePaths.timeline);
      expect(harness.container.read(appFlowProvider), AppView.timeline);
      expect(
        tester.state<State<NavigationShell>>(find.byType(NavigationShell)),
        same(shellState),
      );
      expect(NotificationScheduler.tappedPayloadListenable.value, isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      harness.dispose();
    });

    testWidgets('app resume keeps the active primary route and shell owner', (
      WidgetTester tester,
    ) async {
      final _RouterHarness harness = await _pumpRealRouter(
        tester,
        initialLocation: RoutePaths.nexus,
        authenticated: true,
        welcomeComplete: true,
        onboardingComplete: true,
      );
      await tester.pump();

      harness.router.go(RoutePaths.timeline);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      final State<NavigationShell> shellState = tester.state(
        find.byType(NavigationShell),
      );

      for (final AppLifecycleState state in <AppLifecycleState>[
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
        await tester.pump();
      }

      _expectUri(harness, RoutePaths.timeline);
      expect(harness.container.read(appFlowProvider), AppView.timeline);
      expect(
        tester.state<State<NavigationShell>>(find.byType(NavigationShell)),
        same(shellState),
      );

      await tester.pumpWidget(const SizedBox.shrink());
      harness.dispose();
    });

    testWidgets('Back returns to Nexus without replacing the shell owner', (
      WidgetTester tester,
    ) async {
      final _RouterHarness harness = await _pumpRealRouter(
        tester,
        initialLocation: RoutePaths.nexus,
        authenticated: true,
        welcomeComplete: true,
        onboardingComplete: true,
      );
      await tester.pump();

      harness.router.go(RoutePaths.profile);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      final State<NavigationShell> shellState = tester.state(
        find.byType(NavigationShell),
      );

      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      _expectUri(harness, RoutePaths.nexus);
      expect(harness.container.read(appFlowProvider), AppView.nexus);
      expect(
        tester.state<State<NavigationShell>>(find.byType(NavigationShell)),
        same(shellState),
      );

      await tester.pumpWidget(const SizedBox.shrink());
      harness.dispose();
    });
  });
}

Future<_RouterHarness> _pumpRealRouter(
  WidgetTester tester, {
  String? initialLocation,
  required bool authenticated,
  required bool welcomeComplete,
  required bool onboardingComplete,
  bool internalAdvisorAccess = false,
}) async {
  final ProviderContainer container = ProviderContainer(
    overrides: [
      guards.authenticatedGuardProvider.overrideWith(
        (Ref ref) => ref.watch(_authenticatedStateProvider),
      ),
      guards.onboardingWelcomeCompleteGuardProvider.overrideWith(
        (Ref ref) => ref.watch(_welcomeCompleteStateProvider),
      ),
      guards.onboardingCompleteGuardProvider.overrideWith(
        (Ref ref) => ref.watch(_onboardingCompleteStateProvider),
      ),
      internalAdvisorAccessProvider.overrideWith(
        (Ref ref) => internalAdvisorAccess,
      ),
      notificationProvider.overrideWith(_StaticNotifications.new),
      goalsProvider.overrideWith(_StaticGoals.new),
    ],
  );
  _setGuardState(
    container,
    authenticated: authenticated,
    welcomeComplete: welcomeComplete,
    onboardingComplete: onboardingComplete,
  );

  final GoRouter router = container.read(appRouterProvider);
  if (initialLocation != null) {
    router.go(initialLocation);
  }

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ),
  );

  return _RouterHarness(container: container, router: router);
}

class _RouterHarness {
  _RouterHarness({required this.container, required this.router});

  final ProviderContainer container;
  final GoRouter router;
  bool _disposed = false;

  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    container.dispose();
  }
}

class _GuardCase {
  const _GuardCase({
    required this.authenticated,
    required this.welcomeComplete,
    required this.onboardingComplete,
    required this.expectedPath,
    required this.expectedWidget,
  });

  final bool authenticated;
  final bool welcomeComplete;
  final bool onboardingComplete;
  final String expectedPath;
  final Type expectedWidget;
}

class _RouteExpectation {
  const _RouteExpectation({
    required this.requestedPath,
    required this.finalPath,
    required this.expectedWidget,
    this.shellView,
  });

  final String requestedPath;
  final String finalPath;
  final Type expectedWidget;
  final AppView? shellView;
}

class _LegacyRouteExpectation {
  const _LegacyRouteExpectation({
    required this.legacyPath,
    required this.canonical,
  });

  final String legacyPath;
  final _RouteExpectation canonical;
}

void _expectUri(_RouterHarness harness, String path) {
  expect(harness.router.routeInformationProvider.value.uri.path, path);
}

String? _returnTo(_RouterHarness harness) {
  return harness
      .router
      .routeInformationProvider
      .value
      .uri
      .queryParameters['returnTo'];
}

const List<_GuardCase> _initialLocationCases = <_GuardCase>[
  _GuardCase(
    authenticated: false,
    welcomeComplete: false,
    onboardingComplete: false,
    expectedPath: RoutePaths.onboarding,
    expectedWidget: OnboardingScreen,
  ),
  _GuardCase(
    authenticated: true,
    welcomeComplete: false,
    onboardingComplete: false,
    expectedPath: RoutePaths.onboarding,
    expectedWidget: OnboardingScreen,
  ),
  _GuardCase(
    authenticated: false,
    welcomeComplete: true,
    onboardingComplete: false,
    expectedPath: RoutePaths.login,
    expectedWidget: AuthGate,
  ),
  _GuardCase(
    authenticated: false,
    welcomeComplete: true,
    onboardingComplete: true,
    expectedPath: RoutePaths.login,
    expectedWidget: AuthGate,
  ),
  _GuardCase(
    authenticated: true,
    welcomeComplete: true,
    onboardingComplete: false,
    expectedPath: RoutePaths.onboarding,
    expectedWidget: OnboardingScreen,
  ),
  _GuardCase(
    authenticated: true,
    welcomeComplete: true,
    onboardingComplete: true,
    expectedPath: RoutePaths.nexus,
    expectedWidget: NavigationShell,
  ),
];

const List<_RouteExpectation> _canonicalRouteExpectations = <_RouteExpectation>[
  _RouteExpectation(
    requestedPath: RoutePaths.onboarding,
    finalPath: RoutePaths.nexus,
    expectedWidget: NavigationShell,
    shellView: AppView.nexus,
  ),
  _RouteExpectation(
    requestedPath: RoutePaths.login,
    finalPath: RoutePaths.nexus,
    expectedWidget: NavigationShell,
    shellView: AppView.nexus,
  ),
  _RouteExpectation(
    requestedPath: RoutePaths.nexus,
    finalPath: RoutePaths.nexus,
    expectedWidget: NavigationShell,
    shellView: AppView.nexus,
  ),
  _RouteExpectation(
    requestedPath: RoutePaths.plan,
    finalPath: RoutePaths.timeline,
    expectedWidget: NavigationShell,
    shellView: AppView.timeline,
  ),
  _RouteExpectation(
    requestedPath: RoutePaths.creator,
    finalPath: RoutePaths.creator,
    expectedWidget: NavigationShell,
    shellView: AppView.creator,
  ),
  _RouteExpectation(
    requestedPath: RoutePaths.creatorGoals,
    finalPath: RoutePaths.creatorGoals,
    expectedWidget: NavigationShell,
    shellView: AppView.goals,
  ),
  _RouteExpectation(
    requestedPath: RoutePaths.settings,
    finalPath: RoutePaths.settings,
    expectedWidget: NavigationShell,
    shellView: AppView.settings,
  ),
  _RouteExpectation(
    requestedPath: RoutePaths.notifications,
    finalPath: RoutePaths.notifications,
    expectedWidget: NotificationsPage,
  ),
  _RouteExpectation(
    requestedPath: RoutePaths.logs,
    finalPath: RoutePaths.logs,
    expectedWidget: NavigationShell,
    shellView: AppView.timeline,
  ),
  _RouteExpectation(
    requestedPath: RoutePaths.tasks,
    finalPath: RoutePaths.tasks,
    expectedWidget: NavigationShell,
    shellView: AppView.creator,
  ),
  _RouteExpectation(
    requestedPath: RoutePaths.profile,
    finalPath: RoutePaths.profile,
    expectedWidget: NavigationShell,
    shellView: AppView.profile,
  ),
  _RouteExpectation(
    requestedPath: RoutePaths.progression,
    finalPath: RoutePaths.progression,
    expectedWidget: NavigationShell,
    shellView: AppView.progression,
  ),
  _RouteExpectation(
    requestedPath: RoutePaths.si,
    finalPath: RoutePaths.si,
    expectedWidget: NavigationShell,
    shellView: AppView.console,
  ),
  _RouteExpectation(
    requestedPath: RoutePaths.timeline,
    finalPath: RoutePaths.timeline,
    expectedWidget: NavigationShell,
    shellView: AppView.timeline,
  ),
  _RouteExpectation(
    requestedPath: RoutePaths.smartPlanner,
    finalPath: RoutePaths.smartPlanner,
    expectedWidget: NavigationShell,
    shellView: AppView.smartPlanner,
  ),
  _RouteExpectation(
    requestedPath: RoutePaths.trajectoryEngine,
    finalPath: RoutePaths.trajectoryEngine,
    expectedWidget: NavigationShell,
    shellView: AppView.trajectoryEngine,
  ),
  _RouteExpectation(
    requestedPath: RoutePaths.advisor,
    finalPath: RoutePaths.advisor,
    expectedWidget: ProductAdvisorScreen,
  ),
  _RouteExpectation(
    requestedPath: RoutePaths.paywall,
    finalPath: RoutePaths.paywall,
    expectedWidget: PaywallPage,
  ),
  _RouteExpectation(
    requestedPath: RoutePaths.privacy,
    finalPath: RoutePaths.privacy,
    expectedWidget: WebPageView,
  ),
  _RouteExpectation(
    requestedPath: RoutePaths.deleteAccount,
    finalPath: RoutePaths.deleteAccount,
    expectedWidget: WebPageView,
  ),
  _RouteExpectation(
    requestedPath: RoutePaths.terms,
    finalPath: RoutePaths.terms,
    expectedWidget: WebPageView,
  ),
  _RouteExpectation(
    requestedPath: RoutePaths.support,
    finalPath: RoutePaths.support,
    expectedWidget: WebPageView,
  ),
  _RouteExpectation(
    requestedPath: RoutePaths.about,
    finalPath: RoutePaths.about,
    expectedWidget: AboutPage,
  ),
];

const List<_RouteExpectation> _signedOutPublicRoutes = <_RouteExpectation>[
  _RouteExpectation(
    requestedPath: RoutePaths.privacy,
    finalPath: RoutePaths.privacy,
    expectedWidget: WebPageView,
  ),
  _RouteExpectation(
    requestedPath: RoutePaths.terms,
    finalPath: RoutePaths.terms,
    expectedWidget: WebPageView,
  ),
  _RouteExpectation(
    requestedPath: RoutePaths.support,
    finalPath: RoutePaths.support,
    expectedWidget: WebPageView,
  ),
  _RouteExpectation(
    requestedPath: RoutePaths.about,
    finalPath: RoutePaths.about,
    expectedWidget: AboutPage,
  ),
  _RouteExpectation(
    requestedPath: RoutePaths.deleteAccount,
    finalPath: RoutePaths.deleteAccount,
    expectedWidget: WebPageView,
  ),
];

final List<_LegacyRouteExpectation> _legacyRouteExpectations = AppRouteRegistry
    .routerCompatibilityRedirects
    .map(
      (AppRouteCompatibility alias) => _LegacyRouteExpectation(
        legacyPath: alias.path!,
        canonical: _canonicalRouteExpectations.singleWhere(
          (_RouteExpectation route) => route.requestedPath == alias.targetPath,
        ),
      ),
    )
    .toList(growable: false);

class _StaticGoals extends GoalsNotifier {
  @override
  List<GoalEntity> build() => const <GoalEntity>[];
}

class _StaticNotifications extends NotificationNotifier {
  @override
  List<NotificationEntity> build() => const <NotificationEntity>[];
}
