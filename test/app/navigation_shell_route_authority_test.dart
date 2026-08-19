import 'package:fantastic_guacamole/app/navigation_shell.dart';
import 'package:fantastic_guacamole/app/router/app_router.dart';
import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/features/creator/ui/creator_screen.dart';
import 'package:fantastic_guacamole/features/home/ui/smart_planner_screen.dart';
import 'package:fantastic_guacamole/features/nexus/ui/nexus_screen.dart';
import 'package:fantastic_guacamole/features/profile/ui/profile_screen.dart';
import 'package:fantastic_guacamole/features/progression/ui/progression_screen.dart';
import 'package:fantastic_guacamole/features/settings/ui/settings_screen.dart';
import 'package:fantastic_guacamole/features/si_console/ui/si_console_screen.dart';
import 'package:fantastic_guacamole/features/timeline/ui/timeline_screen.dart';
import 'package:fantastic_guacamole/features/trajectory_engine/ui/trajectory_engine_screen.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/tutorial/adaptive_guidance.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets(
    'direct navigation to every shell route renders the correct first frame',
    (WidgetTester tester) async {
      for (final _ShellExpectation expectation in _shellExpectations) {
        await _pumpRouteShell(tester, initialLocation: expectation.route);

        _expectRouteAndVisibleView(expectation);

        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
  );

  testWidgets('bottom navigation updates both content and URL', (
    WidgetTester tester,
  ) async {
    final _RouteShellHarness harness = await _pumpRouteShell(tester);

    await tester.tap(find.text('Timeline'));
    await tester.pump();
    await tester.pump();

    _expectRouterUri(harness, RoutePaths.timeline);
    _expectRouteAndVisibleView(_byRoute(RoutePaths.timeline));
    expect(harness.container.read(appFlowProvider), AppView.timeline);
  });

  testWidgets('navigation-map selection updates both content and URL', (
    WidgetTester tester,
  ) async {
    final _RouteShellHarness harness = await _pumpRouteShell(tester);

    await tester.tap(find.byTooltip('Open navigation map'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Smart Planner'));
    await tester.pump();
    await tester.pump();

    _expectRouterUri(harness, RoutePaths.smartPlanner);
    _expectRouteAndVisibleView(_byRoute(RoutePaths.smartPlanner));
    expect(harness.container.read(appFlowProvider), AppView.smartPlanner);
  });

  testWidgets('system back produces the expected content and URL', (
    WidgetTester tester,
  ) async {
    final _RouteShellHarness harness = await _pumpRouteShell(tester);

    await tester.tap(find.text('Profile'));
    await tester.pump();
    await tester.pump();
    _expectRouterUri(harness, RoutePaths.profile);
    _expectRouteAndVisibleView(_byRoute(RoutePaths.profile));

    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump();

    _expectRouterUri(harness, RoutePaths.nexus);
    _expectRouteAndVisibleView(_byRoute(RoutePaths.nexus));
    expect(harness.container.read(appFlowProvider), AppView.nexus);
  });

  testWidgets('saved-tab restoration affects only the default Nexus launch', (
    WidgetTester tester,
  ) async {
    await PreferenceService().setLastOpenedTab(2);

    final _RouteShellHarness defaultLaunch = await _pumpRouteShell(
      tester,
      initialLocation: Uri(
        path: RoutePaths.nexus,
        queryParameters: const <String, String>{
          restoreSavedTabQueryParameter: 'true',
        },
      ).toString(),
    );
    await tester.pump();
    await tester.pump();

    _expectRouterUri(defaultLaunch, RoutePaths.timeline);
    _expectRouteAndVisibleView(_byRoute(RoutePaths.timeline));
    expect(defaultLaunch.container.read(appFlowProvider), AppView.timeline);

    await tester.pumpWidget(const SizedBox.shrink());

    final _RouteShellHarness explicitNexus = await _pumpRouteShell(
      tester,
      initialLocation: RoutePaths.nexus,
    );
    await tester.pump();
    await tester.pump();

    _expectRouterUri(explicitNexus, RoutePaths.nexus);
    _expectRouteAndVisibleView(_byRoute(RoutePaths.nexus));
    expect(explicitNexus.container.read(appFlowProvider), AppView.nexus);
  });

  test(
    'adaptive guidance receives the route corresponding to the visible screen',
    () {
      final AdaptiveGuidanceState state = AdaptiveGuidanceState(
        milestones: <GuidanceMilestone, DateTime>{
          GuidanceMilestone.firstItem: DateTime(2026),
          GuidanceMilestone.firstSchedule: DateTime(2026),
          GuidanceMilestone.firstTimelineReview: DateTime(2026),
        },
        counts: const <GuidanceMilestone, int>{},
        skippedLessons: const <GuidanceLessonId>{},
        completedLessons: const <GuidanceLessonId>{
          GuidanceLessonId.createFirstItem,
          GuidanceLessonId.scheduleFirstItem,
          GuidanceLessonId.reviewTimeline,
        },
      );

      for (final _ShellExpectation expectation
          in _adaptiveGuidanceExpectations) {
        final GuidanceLesson? lesson = state.nextIntervention(
          currentRoute: expectation.route,
          decision: _decision,
        );

        expect(
          lesson?.route,
          routePathForAppView(expectation.view),
          reason:
              'Adaptive guidance must receive and act on the route for the visible ${expectation.view.name} screen.',
        );
      }
    },
  );

  testWidgets('legacy routes end at the correct canonical path and view', (
    WidgetTester tester,
  ) async {
    for (final _LegacyExpectation expectation in _legacyExpectations) {
      final _RouteShellHarness harness = await _pumpRouteShell(
        tester,
        initialLocation: expectation.legacyRoute,
      );
      await tester.pump();
      await tester.pump();

      _expectRouterUri(harness, expectation.canonical.route);
      _expectRouteAndVisibleView(expectation.canonical);
      expect(
        harness.container.read(appFlowProvider),
        expectation.canonical.view,
      );

      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
}

Future<_RouteShellHarness> _pumpRouteShell(
  WidgetTester tester, {
  String initialLocation = RoutePaths.nexus,
}) async {
  tester.platformDispatcher.views.first
    ..physicalSize = const Size(1200, 2400)
    ..devicePixelRatio = 1.0;
  addTearDown(() {
    tester.platformDispatcher.views.first
      ..resetPhysicalSize()
      ..resetDevicePixelRatio();
  });

  final ProviderContainer container = ProviderContainer(
    overrides: [
      unreadNotificationsProvider.overrideWithValue(0),
      goalsProvider.overrideWith(_StaticGoals.new),
    ],
  );
  addTearDown(container.dispose);

  final GoRouter router = GoRouter(
    initialLocation: initialLocation,
    routes: <RouteBase>[..._shellRoutes, ..._legacyRedirectRoutes],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ),
  );

  return _RouteShellHarness(container: container, router: router);
}

class _RouteShellHarness {
  const _RouteShellHarness({required this.container, required this.router});

  final ProviderContainer container;
  final GoRouter router;
}

class _ShellExpectation {
  const _ShellExpectation({
    required this.route,
    required this.view,
    required this.screenType,
  });

  final String route;
  final AppView view;
  final Type screenType;
}

class _LegacyExpectation {
  const _LegacyExpectation({
    required this.legacyRoute,
    required this.canonical,
  });

  final String legacyRoute;
  final _ShellExpectation canonical;
}

void _expectRouterUri(_RouteShellHarness harness, String route) {
  expect(harness.router.routeInformationProvider.value.uri.path, route);
  expect(harness.router.routeInformationProvider.value.uri.hasQuery, isFalse);
}

void _expectRouteAndVisibleView(_ShellExpectation expectation) {
  expect(find.byType(expectation.screenType), findsWidgets);
  expect(appViewFromRoutePath(expectation.route), expectation.view);
}

_ShellExpectation _byRoute(String route) {
  return _shellExpectations.singleWhere(
    (_ShellExpectation expectation) => expectation.route == route,
  );
}

List<GoRoute> get _shellRoutes {
  return <GoRoute>[
    for (final _ShellExpectation expectation in _shellExpectations)
      _shellRoute(expectation.route, expectation.view),
  ];
}

List<GoRoute> get _legacyRedirectRoutes {
  return <GoRoute>[
    GoRoute(path: RoutePaths.legacyLogs, redirect: (_, _) => RoutePaths.logs),
    GoRoute(
      path: RoutePaths.legacyProgression,
      redirect: (_, _) => RoutePaths.progression,
    ),
    GoRoute(path: RoutePaths.legacySi, redirect: (_, _) => RoutePaths.si),
    GoRoute(path: RoutePaths.legacyTasks, redirect: (_, _) => RoutePaths.tasks),
    GoRoute(
      path: RoutePaths.legacyProfile,
      redirect: (_, _) => RoutePaths.profile,
    ),
    GoRoute(
      path: RoutePaths.legacyInsights,
      redirect: (_, _) => RoutePaths.smartPlanner,
    ),
    GoRoute(
      path: RoutePaths.legacyCoach,
      redirect: (_, _) => RoutePaths.smartPlanner,
    ),
    GoRoute(
      path: RoutePaths.legacySignals,
      redirect: (_, _) => RoutePaths.smartPlanner,
    ),
  ];
}

const List<_ShellExpectation> _shellExpectations = <_ShellExpectation>[
  _ShellExpectation(
    route: RoutePaths.nexus,
    view: AppView.nexus,
    screenType: NexusScreen,
  ),
  _ShellExpectation(
    route: RoutePaths.creator,
    view: AppView.creator,
    screenType: CreatorScreen,
  ),
  _ShellExpectation(
    route: RoutePaths.settings,
    view: AppView.settings,
    screenType: SettingsScreen,
  ),
  _ShellExpectation(
    route: RoutePaths.logs,
    view: AppView.timeline,
    screenType: TimelineScreen,
  ),
  _ShellExpectation(
    route: RoutePaths.tasks,
    view: AppView.creator,
    screenType: CreatorScreen,
  ),
  _ShellExpectation(
    route: RoutePaths.profile,
    view: AppView.profile,
    screenType: ProfileScreen,
  ),
  _ShellExpectation(
    route: RoutePaths.progression,
    view: AppView.progression,
    screenType: ProgressionScreen,
  ),
  _ShellExpectation(
    route: RoutePaths.si,
    view: AppView.console,
    screenType: SIConsoleScreen,
  ),
  _ShellExpectation(
    route: RoutePaths.timeline,
    view: AppView.timeline,
    screenType: TimelineScreen,
  ),
  _ShellExpectation(
    route: RoutePaths.smartPlanner,
    view: AppView.smartPlanner,
    screenType: SmartPlannerScreen,
  ),
  _ShellExpectation(
    route: RoutePaths.trajectoryEngine,
    view: AppView.trajectoryEngine,
    screenType: TrajectoryEngineScreen,
  ),
];

const List<_ShellExpectation> _adaptiveGuidanceExpectations =
    <_ShellExpectation>[
      _ShellExpectation(
        route: RoutePaths.nexus,
        view: AppView.nexus,
        screenType: NexusScreen,
      ),
      _ShellExpectation(
        route: RoutePaths.smartPlanner,
        view: AppView.smartPlanner,
        screenType: SmartPlannerScreen,
      ),
      _ShellExpectation(
        route: RoutePaths.timeline,
        view: AppView.timeline,
        screenType: TimelineScreen,
      ),
      _ShellExpectation(
        route: RoutePaths.si,
        view: AppView.console,
        screenType: SIConsoleScreen,
      ),
      _ShellExpectation(
        route: RoutePaths.trajectoryEngine,
        view: AppView.trajectoryEngine,
        screenType: TrajectoryEngineScreen,
      ),
      _ShellExpectation(
        route: RoutePaths.progression,
        view: AppView.progression,
        screenType: ProgressionScreen,
      ),
    ];

const List<_LegacyExpectation> _legacyExpectations = <_LegacyExpectation>[
  _LegacyExpectation(
    legacyRoute: RoutePaths.legacyLogs,
    canonical: _ShellExpectation(
      route: RoutePaths.logs,
      view: AppView.timeline,
      screenType: TimelineScreen,
    ),
  ),
  _LegacyExpectation(
    legacyRoute: RoutePaths.legacyProgression,
    canonical: _ShellExpectation(
      route: RoutePaths.progression,
      view: AppView.progression,
      screenType: ProgressionScreen,
    ),
  ),
  _LegacyExpectation(
    legacyRoute: RoutePaths.legacySi,
    canonical: _ShellExpectation(
      route: RoutePaths.si,
      view: AppView.console,
      screenType: SIConsoleScreen,
    ),
  ),
  _LegacyExpectation(
    legacyRoute: RoutePaths.legacyTasks,
    canonical: _ShellExpectation(
      route: RoutePaths.tasks,
      view: AppView.creator,
      screenType: CreatorScreen,
    ),
  ),
  _LegacyExpectation(
    legacyRoute: RoutePaths.legacyProfile,
    canonical: _ShellExpectation(
      route: RoutePaths.profile,
      view: AppView.profile,
      screenType: ProfileScreen,
    ),
  ),
  _LegacyExpectation(
    legacyRoute: RoutePaths.legacyInsights,
    canonical: _ShellExpectation(
      route: RoutePaths.smartPlanner,
      view: AppView.smartPlanner,
      screenType: SmartPlannerScreen,
    ),
  ),
  _LegacyExpectation(
    legacyRoute: RoutePaths.legacyCoach,
    canonical: _ShellExpectation(
      route: RoutePaths.smartPlanner,
      view: AppView.smartPlanner,
      screenType: SmartPlannerScreen,
    ),
  ),
  _LegacyExpectation(
    legacyRoute: RoutePaths.legacySignals,
    canonical: _ShellExpectation(
      route: RoutePaths.smartPlanner,
      view: AppView.smartPlanner,
      screenType: SmartPlannerScreen,
    ),
  ),
];

const DailyDecisionIntelligence _decision = DailyDecisionIntelligence(
  primaryAction: 'Review the current route.',
  momentum: '80% rising',
  trajectory: 'Stable',
  energy: '80% energy',
  warning: 'No material constraint is supported by the current evidence.',
  recovery: 'Keep current load.',
  recommendedAction: 'Use this screen.',
  rationale: 'Route-specific guidance should match the visible screen.',
  changeSummary: 'No material change.',
  evidence: <String>['test'],
  confidence: .8,
  observedOutcomes: 1,
);

GoRoute _shellRoute(String path, AppView view) {
  return GoRoute(
    path: path,
    builder: (BuildContext context, GoRouterState state) => NavigationShell(
      initialView: appViewFromRoutePath(state.matchedLocation) ?? view,
      allowSavedTabRestore:
          state.matchedLocation == RoutePaths.nexus &&
          state.uri.queryParameters[restoreSavedTabQueryParameter] == 'true',
    ),
  );
}

class _StaticGoals extends GoalsNotifier {
  @override
  List<GoalEntity> build() => const <GoalEntity>[];
}
