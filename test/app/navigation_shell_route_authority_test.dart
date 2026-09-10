import 'dart:async';

import 'package:fantastic_guacamole/app/navigation_shell.dart';
import 'package:fantastic_guacamole/app/router/app_route_registry.dart';
import 'package:fantastic_guacamole/app/router/app_router.dart';
import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:fantastic_guacamole/core/network/network_status_service.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_namespace.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/storage/account_scoped_shared_prefs_store.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/data/storage/hive_service.dart';
import 'package:hive/hive.dart';
import 'package:fantastic_guacamole/state/providers/storage_providers.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/creator_handshake.dart';
import 'package:fantastic_guacamole/features/notes/ui/note_detail_screen.dart';
import 'package:fantastic_guacamole/state/models/creator_form_data.dart';
import 'package:fantastic_guacamole/state/providers/notes_provider.dart';
import 'package:fantastic_guacamole/state/providers/planning_note_provider.dart';
import 'package:fantastic_guacamole/state/providers/timeline_provider.dart';
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
import 'package:fantastic_guacamole/state/services/app_recovery_service.dart';
import 'package:fantastic_guacamole/tutorial/adaptive_guidance.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await SharedPrefsService.init();
    await SharedPrefsService.clear();
  });

  testWidgets(
    'Creator note is visible in Timeline immediately and after reload',
    (WidgetTester tester) async {
      final harness = await _pumpRouteShell(
        tester,
        initialLocation: RoutePaths.creator,
        memoryStorage: true,
      );
      final container = harness.container;
      expect(container.read(timelineProvider), isEmpty);
      final creator = container.read(creatorHandshakeProvider.notifier);
      await creator.stage(
        data: const CreatorFormData(
          title: 'Release note history',
          type: 'Note',
          priority: 3,
          description: 'Persist this body.',
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      final confirm = find.byKey(const Key('creator-confirm-selected'));
      await tester.ensureVisible(confirm);
      await tester.tap(confirm);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        container.read(creatorHandshakeProvider).phase,
        CreatorHandshakePhase.applied,
      );
      expect(
        container.read(timelineProvider).single.detail,
        'Release note history',
      );
      await creator.confirm();
      expect(container.read(timelineProvider), hasLength(1));
      await tester.ensureVisible(find.text('Open Timeline'));
      await tester.tap(find.text('Open Timeline'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(TimelineScreen), findsOneWidget);
      expect(find.text('Note Created'), findsOneWidget);
      expect(find.textContaining('Release note history'), findsWidgets);
      container.invalidate(timelineProvider);
      await tester.pump();
      expect(
        container.read(timelineProvider).single.detail,
        'Release note history',
      );
      await creator.undo();
      await creator.undo();
      expect(
        await container.read(domainNoteRepositoryProvider).getNotes(),
        isEmpty,
      );
      final events = container.read(timelineProvider);
      expect(events.where((event) => event.isNoteCreated), hasLength(1));
      expect(events.where((event) => event.isNoteDeleted), hasLength(1));
      await tester.pump();
      expect(find.text('Note Deleted'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final reuseShell in [false, true]) {
    testWidgets(
      'Nexus note consent opens visible Planner (shared shell: $reuseShell)',
      (WidgetTester tester) async {
        final harness = await _pumpRouteShell(
          tester,
          reuseShellState: reuseShell,
          memoryStorage: true,
        );
        await harness.container
            .read(notesProvider.notifier)
            .createNote(
              title: 'Explicit planning note',
              body: 'Only ten minutes available.',
            );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        final openNote = find.bySemanticsLabel('Open NOTE');
        await tester.ensureVisible(openNote);
        await tester.tap(openNote);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        expect(find.byType(NoteDetailScreen), findsOneWidget);
        final noteRoute = ModalRoute.of(
          tester.element(find.byType(NoteDetailScreen)),
        )!;
        await tester.tap(find.text('Use in planning'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(find.text('Cancel'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(NoteDetailScreen), findsOneWidget);
        expect(harness.container.read(planningNoteSelectionProvider), isNull);
        await tester.tap(find.text('Use in planning'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(find.text('Use this note'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pump(const Duration(milliseconds: 500));
        _expectRouterUri(harness, RoutePaths.smartPlanner);
        expect(
          noteRoute.isActive,
          isFalse,
          reason: 'The exact note route must leave the Navigator.',
        );
        expect(find.byType(NoteDetailScreen), findsNothing);
        expect(find.byType(SmartPlannerScreen), findsOneWidget);
        expect(
          (await harness.container.read(
            selectedPlanningNoteProvider.future,
          ))?.title,
          'Explicit planning note',
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        harness.dispose();
        await tester.pump();
      },
    );
  }

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

  testWidgets('direct Timeline launch does not mount a hidden Nexus surface', (
    WidgetTester tester,
  ) async {
    await _pumpRouteShell(tester, initialLocation: RoutePaths.timeline);

    expect(find.byType(TimelineScreen), findsOneWidget);
    expect(find.byType(NexusScreen), findsNothing);
  });

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

  testWidgets(
    'bottom navigation uses the canonical Trajectory Engine identity',
    (WidgetTester tester) async {
      final _RouteShellHarness harness = await _pumpRouteShell(tester);

      expect(find.text('Trajectory Engine'), findsOneWidget);
      expect(find.text('Trajectory'), findsNothing);

      await tester.tap(find.text('Trajectory Engine'));
      await tester.pump();
      await tester.pump();

      _expectRouterUri(harness, RoutePaths.trajectoryEngine);
      _expectRouteAndVisibleView(_byRoute(RoutePaths.trajectoryEngine));
      expect(harness.container.read(appFlowProvider), AppView.trajectoryEngine);
    },
  );

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

  testWidgets('phone navigation contains the map action below app content', (
    WidgetTester tester,
  ) async {
    await _pumpRouteShell(
      tester,
      initialLocation: RoutePaths.timeline,
      surfaceSize: const Size(360, 772),
      forceOnline: true,
    );

    const Key navigationKey = ValueKey<String>('phone-bottom-navigation');
    final Finder navigation = find.byKey(navigationKey);
    final Finder mapAction = find.byTooltip('Open navigation map');

    expect(navigation, findsOneWidget);
    expect(
      find.descendant(of: navigation, matching: mapAction),
      findsOneWidget,
    );
    final Rect navigationRect = tester.getRect(navigation);
    final Rect mapRect = tester.getRect(mapAction);
    expect(mapRect.left, greaterThanOrEqualTo(navigationRect.left));
    expect(mapRect.top, greaterThanOrEqualTo(navigationRect.top));
    expect(mapRect.right, lessThanOrEqualTo(navigationRect.right));
    expect(mapRect.bottom, lessThanOrEqualTo(navigationRect.bottom));
    expect(tester.takeException(), isNull);
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

  for (final bool systemBack in <bool>[true, false]) {
    testWidgets(
      'Settings Back after a route replacement (system: $systemBack)',
      (WidgetTester tester) async {
        final _RouteShellHarness harness = await _pumpRouteShell(
          tester,
          reuseShellState: true,
        );
        await tester.pump();
        await tester.pump();
        unawaited(harness.router.replace<void>(RoutePaths.settings));
        await tester.pump();
        await tester.pump();
        expect(find.byType(SettingsScreen), findsOneWidget);
        if (systemBack) {
          await tester.binding.handlePopRoute();
        } else {
          await tester.tap(find.byTooltip('Back'));
        }
        await tester.pump();
        await tester.pump();
        _expectRouterUri(harness, RoutePaths.nexus);
        expect(find.byType(NexusScreen), findsOneWidget);
        expect(find.byType(SettingsScreen), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('saved-tab restoration affects only the default Nexus launch', (
    WidgetTester tester,
  ) async {
    await _testPreferenceService().setLastOpenedTab(2);

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

  testWidgets('default launch restores the account recovery primary view', (
    WidgetTester tester,
  ) async {
    await _testRecoveryService().saveState(
      lastPrimaryViewName: AppView.profile.name,
    );

    final _RouteShellHarness harness = await _pumpRouteShell(
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
    await tester.pump();

    _expectRouterUri(harness, RoutePaths.profile);
    _expectRouteAndVisibleView(_byRoute(RoutePaths.profile));
    expect(harness.container.read(appFlowProvider), AppView.profile);
  });

  testWidgets('mounted shell honors a new saved-tab restore request', (
    WidgetTester tester,
  ) async {
    await _testPreferenceService().setLastOpenedTab(2);

    final _RouteShellHarness harness = await _pumpRouteShell(
      tester,
      initialLocation: RoutePaths.creator,
      reuseShellState: true,
    );
    await tester.pump();
    await tester.pump();

    _expectRouterUri(harness, RoutePaths.creator);
    _expectRouteAndVisibleView(_byRoute(RoutePaths.creator));
    expect(harness.container.read(appFlowProvider), AppView.creator);

    harness.router.go(
      Uri(
        path: RoutePaths.nexus,
        queryParameters: const <String, String>{
          restoreSavedTabQueryParameter: 'true',
        },
      ).toString(),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();
    await tester.pump();

    _expectRouterUri(harness, RoutePaths.timeline);
    _expectRouteAndVisibleView(_byRoute(RoutePaths.timeline));
    expect(harness.container.read(appFlowProvider), AppView.timeline);
  });

  testWidgets('mounted shell restores Nexus without stale app flow', (
    WidgetTester tester,
  ) async {
    await _testPreferenceService().setLastOpenedTab(0);

    final _RouteShellHarness harness = await _pumpRouteShell(
      tester,
      initialLocation: RoutePaths.creator,
      reuseShellState: true,
    );
    await tester.pump();
    await tester.pump();

    _expectRouterUri(harness, RoutePaths.creator);
    expect(harness.container.read(appFlowProvider), AppView.creator);

    harness.router.go(
      Uri(
        path: RoutePaths.nexus,
        queryParameters: const <String, String>{
          restoreSavedTabQueryParameter: 'true',
        },
      ).toString(),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();

    _expectRouterUri(harness, RoutePaths.nexus);
    _expectRouteAndVisibleView(_byRoute(RoutePaths.nexus));
    expect(harness.container.read(appFlowProvider), AppView.nexus);
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

  testWidgets(
    'compatibility routes end at the correct canonical path and view',
    (WidgetTester tester) async {
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
    },
  );
}

Future<_RouteShellHarness> _pumpRouteShell(
  WidgetTester tester, {
  String initialLocation = RoutePaths.nexus,
  bool reuseShellState = false,
  Size surfaceSize = const Size(1200, 2400),
  bool forceOnline = false,
  bool memoryStorage = false,
}) async {
  tester.platformDispatcher.views.first
    ..physicalSize = surfaceSize
    ..devicePixelRatio = 1.0;
  addTearDown(() {
    tester.platformDispatcher.views.first
      ..resetPhysicalSize()
      ..resetDevicePixelRatio();
  });

  final ProviderContainer container = ProviderContainer(
    overrides: [
      if (memoryStorage) ...[
        hiveStoreProvider.overrideWithValue(_MemoryHiveStore()),
        secureStoreProvider.overrideWithValue(
          SecureStore(backend: InMemorySecureStoreBackend()),
        ),
        sensitivePrefsStoreProvider.overrideWithValue(
          const SharedPrefsStoreAdapter(),
        ),
      ],
      accountStorageScopeProvider.overrideWithValue(
        AccountStorageScope.authenticated('navigation-test-account'),
      ),
      accountLegacyOwnershipProvider.overrideWithValue(
        LegacyScopeOwnership.provenNotOwned,
      ),
      if (forceOnline)
        networkInterfaceAvailabilityProvider.overrideWithValue(
          NetworkInterfaceAvailability.available,
        ),
      unreadNotificationsProvider.overrideWithValue(0),
      goalsProvider.overrideWith(_StaticGoals.new),
    ],
  );

  final GoRouter router = GoRouter(
    initialLocation: initialLocation,
    routes: <RouteBase>[
      ...(reuseShellState ? _sharedShellRoutes : _shellRoutes),
      ..._legacyRedirectRoutes,
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ),
  );

  final harness = _RouteShellHarness(container: container, router: router);
  addTearDown(harness.dispose);
  return harness;
}

class _RouteShellHarness {
  _RouteShellHarness({required this.container, required this.router});

  final ProviderContainer container;
  final GoRouter router;
  bool _disposed = false;
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    container.dispose();
  }
}

// Keep the real repositories and route stack, but avoid native disk I/O under
// WidgetTester's fake async clock for the mutation journeys.
class _MemoryHiveStore implements HiveStore {
  final Map<String, Box<dynamic>> _boxes = {};
  @override
  Future<void> init() async {}
  @override
  bool isBoxOpen(String key) => _boxes.containsKey(key);
  @override
  Future<Box<T>> openBox<T>(String key) async =>
      _boxes.putIfAbsent(key, _MemoryBox<T>.new) as Box<T>;
  @override
  Box<T> box<T>(String key) => _boxes[key]! as Box<T>;
  @override
  Future<void> clearBox(String key) async {
    await _boxes[key]?.clear();
  }

  @override
  Future<void> closeBox(String key) async {
    _boxes.remove(key);
  }
}

class _MemoryBox<T> implements Box<T> {
  final Map<dynamic, T> _values = {};
  @override
  T? get(dynamic key, {T? defaultValue}) => _values[key] ?? defaultValue;
  @override
  bool containsKey(dynamic key) => _values.containsKey(key);
  @override
  Iterable<dynamic> get keys => _values.keys;
  @override
  bool get isNotEmpty => _values.isNotEmpty;
  @override
  Map<dynamic, T> toMap() => Map.of(_values);
  @override
  Future<void> put(dynamic key, T value) async {
    _values[key] = value;
  }

  @override
  Future<void> putAll(Map<dynamic, T> values) async {
    _values.addAll(values);
  }

  @override
  Future<void> delete(dynamic key) async {
    _values.remove(key);
  }

  @override
  Future<int> clear() async {
    final count = _values.length;
    _values.clear();
    return count;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

PreferenceService _testPreferenceService() {
  return PreferenceService(
    accountStore: AccountScopedSharedPrefsStore(
      delegate: const SharedPrefsStoreAdapter(),
      scope: AccountStorageScope.authenticated('navigation-test-account'),
    ),
  );
}

AppRecoveryService _testRecoveryService() {
  return AppRecoveryService(
    store: AccountScopedSharedPrefsStore(
      delegate: const SharedPrefsStoreAdapter(),
      scope: AccountStorageScope.authenticated('navigation-test-account'),
    ),
  );
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

const ValueKey<String> _sharedNavigationShellPageKey = ValueKey<String>(
  'test-shared-navigation-shell',
);

List<GoRoute> get _sharedShellRoutes {
  return <GoRoute>[
    for (final _ShellExpectation expectation in _shellExpectations)
      GoRoute(
        path: expectation.route,
        pageBuilder: (BuildContext context, GoRouterState state) =>
            NoTransitionPage<void>(
              key: _sharedNavigationShellPageKey,
              child: _navigationShellForRoute(state, expectation.view),
            ),
      ),
  ];
}

List<GoRoute> get _legacyRedirectRoutes {
  return <GoRoute>[
    for (final _LegacyExpectation expectation in _legacyExpectations)
      GoRoute(
        path: expectation.legacyRoute,
        redirect: (_, _) => expectation.canonical.route,
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

final List<_LegacyExpectation> _legacyExpectations = AppRouteRegistry
    .routerCompatibilityRedirects
    .where(
      (AppRouteCompatibility alias) => _shellExpectations.any(
        (_ShellExpectation route) => route.route == alias.targetPath,
      ),
    )
    .map(
      (AppRouteCompatibility alias) => _LegacyExpectation(
        legacyRoute: alias.path!,
        canonical: _byRoute(alias.targetPath),
      ),
    )
    .toList(growable: false);

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
    builder: (BuildContext context, GoRouterState state) =>
        _navigationShellForRoute(state, view),
  );
}

NavigationShell _navigationShellForRoute(GoRouterState state, AppView view) {
  return NavigationShell(
    initialView: appViewFromRoutePath(state.matchedLocation) ?? view,
    allowSavedTabRestore:
        state.matchedLocation == RoutePaths.nexus &&
        state.uri.queryParameters[restoreSavedTabQueryParameter] == 'true',
  );
}

class _StaticGoals extends GoalsNotifier {
  @override
  List<GoalEntity> build() => const <GoalEntity>[];
}
