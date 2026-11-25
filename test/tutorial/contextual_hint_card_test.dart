import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/models/auth_models.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
import 'package:fantastic_guacamole/state/core/app_providers.dart';
import 'package:fantastic_guacamole/state/providers/account_onboarding_provider.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/auth_session_boundary_provider.dart';
import 'package:fantastic_guacamole/state/providers/daily_decision_intelligence_provider.dart';
import 'package:fantastic_guacamole/state/providers/intelligence_provider.dart';
import 'package:fantastic_guacamole/tutorial/adaptive_guidance.dart';
import 'package:fantastic_guacamole/tutorial/adaptive_guide_overlay.dart';
import 'package:fantastic_guacamole/tutorial/guide_hint_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Contextual hints are small cards that leave the screen usable, appear once
/// per account and lesson, and also reach people who skipped the first-run
/// guide.
const String _account = 'hint-card-user';
const Key _card = Key('guide_hint_card');

String get _prefix =>
    'adaptive_guidance_v3.${AccountStorageScope.authenticated(_account).v2Namespace}';

const List<String> _core = <String>[
  'createFirstItem',
  'scheduleFirstItem',
  'reviewTimeline',
];

Map<String, Object> get _coreFinished {
  final int at = DateTime.utc(2020).millisecondsSinceEpoch;
  return <String, Object>{
    for (final String milestone in <String>[
      'firstItem',
      'firstSchedule',
      'firstTimelineReview',
    ]) ...<String, Object>{
      '$_prefix.$milestone.at': at,
      '$_prefix.$milestone.count': 1,
    },
  };
}

Map<String, Object> get _coreSkipped => <String, Object>{
  for (final String id in _core) '$_prefix.skip.$id': true,
};

Map<String, Object> get _corePaused => <String, Object>{
  for (final String id in _core) '$_prefix.later.$id': true,
};

void main() {
  testWidgets('the page under a hint stays usable and is not covered', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(_coreFinished);
    final _Page page = _Page();
    await _pumpApp(tester, page);

    expect(find.byKey(_card), findsOneWidget);
    await tester.tap(find.byKey(const Key('top-action')));
    await tester.tap(find.byKey(const Key('bottom-action')));
    expect(page.topTaps, 1);
    expect(page.bottomTaps, 1);
    // Typing on the page works: the hint does not take or trap focus.
    await tester.enterText(find.byKey(const Key('page-field')), 'hello');
    expect(find.text('hello'), findsOneWidget);

    final Rect card = tester.getRect(find.byKey(_card));
    final Rect screen =
        Offset.zero & tester.view.physicalSize / tester.view.devicePixelRatio;
    expect(card.top, greaterThanOrEqualTo(0));
    // The page is moved below the card instead of being covered by it.
    expect(
      tester.getRect(find.byKey(const Key('page-title'))).top,
      greaterThanOrEqualTo(card.bottom),
    );
    final Rect bottom = tester.getRect(find.byKey(const Key('bottom-action')));
    expect(bottom.overlaps(card), isFalse);
    expect(bottom.bottom, lessThanOrEqualTo(screen.bottom));
    expect(find.byKey(_card), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final (String action, String storedKey) in <(String, String)>[
    ('Not now', 'skip'),
    ('Got it', 'complete'),
  ]) {
    testWidgets('after "$action" the hint does not return on re-entry or '
        'restart', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(_coreFinished);
      final GoRouter router = await _pumpApp(tester, _Page());
      expect(find.byKey(_card), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, action));
      await _settle(tester);
      expect(find.byKey(_card), findsNothing);
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('$_prefix.$storedKey.siConsole'), isTrue);

      router.go(RoutePaths.settings);
      await _settle(tester);
      router.go(RoutePaths.siConsole);
      await _settle(tester);
      expect(find.byKey(_card), findsNothing);

      await _pumpApp(tester, _Page(), restart: 1);
      expect(find.byKey(_card), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a hint is shown once even when it is ignored', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(_coreFinished);
    final GoRouter router = await _pumpApp(tester, _Page());
    expect(find.byKey(_card), findsOneWidget);
    // Still there while the person stays on the page.
    await tester.pump(const Duration(seconds: 2));
    expect(find.byKey(_card), findsOneWidget);

    router.go(RoutePaths.settings);
    await _settle(tester);
    router.go(RoutePaths.siConsole);
    await _settle(tester);
    expect(find.byKey(_card), findsNothing);

    await _pumpApp(tester, _Page(), restart: 1);
    expect(find.byKey(_card), findsNothing);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    // Seen, not muted: the Settings "prompts muted" count is unchanged.
    expect(prefs.getBool('$_prefix.skip.siConsole'), isNull);
  });

  testWidgets('doing the page\'s real action ends the hint', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(_coreFinished);
    await _pumpApp(tester, _Page());
    expect(find.byKey(_card), findsOneWidget);
    final ProviderContainer container = ProviderScope.containerOf(
      tester.element(find.byKey(_card)),
    );
    await container
        .read(adaptiveGuidanceProvider.notifier)
        .record(GuidanceMilestone.firstSiQuery);
    await _settle(tester);
    expect(find.byKey(_card), findsNothing);
  });

  for (final (String name, Map<String, Object> stored, CoreGuideStatus status)
      in <(String, Map<String, Object>, CoreGuideStatus)>[
        ('skipped', _coreSkipped, CoreGuideStatus.skipped),
        ('paused', _corePaused, CoreGuideStatus.paused),
      ]) {
    testWidgets('a $name first-run guide still gets the hint on its page, '
        'not the guide', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(stored);
      final _Page page = _Page();
      final GoRouter router = await _pumpApp(tester, page);

      expect(find.byKey(_card), findsOneWidget);
      expect(find.text('Add your first task'), findsNothing);
      expect(find.text('Pause guide'), findsNothing);
      await tester.tap(find.byKey(const Key('top-action')));
      expect(page.topTaps, 1);

      await tester.tap(find.widgetWithText(TextButton, 'Not now'));
      await _settle(tester);
      final ProviderContainer container = ProviderScope.containerOf(
        tester.element(find.byKey(const Key('page-title'))),
      );
      final AdaptiveGuidanceState state = container
          .read(adaptiveGuidanceProvider)
          .requireValue;
      // Settings still tells the truth about the guide itself.
      expect(state.coreGuideStatus, status);
      expect(state.activeCoreLesson, isNull);

      router.go(RoutePaths.settings);
      await _settle(tester);
      expect(find.byKey(_card), findsNothing);
      expect(find.text('Add your first task'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  for (final String language in <String>['en', 'es']) {
    testWidgets('$language hint fits 320 dp at 200% text and keeps the page '
        'usable', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      SharedPreferences.setMockInitialValues(_coreFinished);
      final _Page page = _Page();
      await _pumpApp(tester, page, language: language, textScale: 2);
      final bool es = language == 'es';

      expect(find.byKey(_card), findsOneWidget);
      expect(tester.takeException(), isNull);
      final Rect card = tester.getRect(find.byKey(_card));
      expect(card.left, greaterThanOrEqualTo(0));
      expect(card.right, lessThanOrEqualTo(320));
      expect(card.height, lessThanOrEqualTo(640 * .5));
      for (final String label in <String>[
        es ? 'Ahora no' : 'Not now',
        es ? 'Entendido' : 'Got it',
      ]) {
        final Finder button = find.widgetWithText(TextButton, label);
        expect(button.hitTestable(), findsOneWidget, reason: label);
        final Size size = tester.getSize(button);
        expect(size.height, greaterThanOrEqualTo(48), reason: label);
        expect(size.width, greaterThanOrEqualTo(48), reason: label);
      }
      await tester.tap(find.byKey(const Key('top-action')));
      expect(page.topTaps, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$language hint is announced once as a hint and its buttons '
        'work from a screen reader', (WidgetTester tester) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      SharedPreferences.setMockInitialValues(_coreFinished);
      await _pumpApp(tester, _Page(), language: language);
      final bool es = language == 'es';
      final ChronoSparkLocalizations l10n = ChronoSparkLocalizations(
        Locale(language),
      );
      final String hintLabel = es
          ? 'Ayuda con esta página'
          : 'Help with this page';
      final String title = l10n.guideTitle('siConsole', 'Ask what is missing');

      expect(
        tester.getSemantics(find.byKey(_card)),
        isSemantics(label: '$hintLabel. $title', isLiveRegion: true),
      );
      final String dismiss = es ? 'Ahora no' : 'Not now';
      final String gotIt = es ? 'Entendido' : 'Got it';
      expect(
        tester.getSemantics(find.widgetWithText(TextButton, dismiss)),
        isSemantics(label: dismiss, isButton: true, hasTapAction: true),
      );
      final SemanticsNode action = tester.getSemantics(
        find.widgetWithText(TextButton, gotIt),
      );
      expect(
        action,
        isSemantics(label: gotIt, isButton: true, hasTapAction: true),
      );
      tester.binding.renderViews.single.owner!.semanticsOwner!.performAction(
        action.id,
        SemanticsAction.tap,
      );
      await _settle(tester);
      expect(find.byKey(_card), findsNothing);
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('$_prefix.complete.siConsole'), isTrue);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  }
}

class _Page {
  int topTaps = 0;
  int bottomTaps = 0;

  /// Stands in for a lesson screen: a title and action at the top, a field,
  /// and a control at the very bottom (like a composer or bottom navigation).
  Widget build() => Scaffold(
    body: SafeArea(
      child: Column(
        children: <Widget>[
          const Text('Chat page', key: Key('page-title')),
          TextButton(
            key: const Key('top-action'),
            onPressed: () => topTaps++,
            child: const Text('Top action'),
          ),
          const TextField(key: Key('page-field')),
          const Spacer(),
          TextButton(
            key: const Key('bottom-action'),
            onPressed: () => bottomTaps++,
            child: const Text('Bottom action'),
          ),
        ],
      ),
    ),
  );
}

Future<void> _settle(WidgetTester tester) async {
  for (int i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<GoRouter> _pumpApp(
  WidgetTester tester,
  _Page page, {
  String language = 'en',
  double textScale = 1,
  int restart = 0,
}) async {
  final GoRouter router = GoRouter(
    initialLocation: RoutePaths.siConsole,
    routes: <RouteBase>[
      GoRoute(
        path: RoutePaths.siConsole,
        builder: (BuildContext context, GoRouterState state) => page.build(),
      ),
      GoRoute(
        path: RoutePaths.settings,
        builder: (BuildContext context, GoRouterState state) =>
            const Scaffold(body: Center(child: Text('Settings page'))),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      // A new scope is a fresh app start that reads stored guidance again.
      key: ValueKey<int>(restart),
      overrides: [
        accountStorageScopeProvider.overrideWithValue(
          AccountStorageScope.authenticated(_account),
        ),
        domainTaskRepositoryProvider.overrideWithValue(_NoTasks()),
        accountOnboardingCompleteProvider.overrideWith(_SetupDone.new),
        authUserProvider.overrideWith(
          (Ref ref) => Stream<User?>.value(
            const User(
              id: _account,
              email: 'hint@example.test',
              emailVerified: true,
            ),
          ),
        ),
        authSessionBoundaryProvider.overrideWith(_ReadyBoundary.new),
        dailyDecisionIntelligenceProvider.overrideWith((Ref ref) => _decision),
      ],
      child: MaterialApp.router(
        locale: Locale(language),
        supportedLocales: ChronoSparkLocalizations.supportedLocales,
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          ChronoSparkLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        routerConfig: router,
        // Mirrors the app root: the page sits in the hint space and the
        // guide overlay is keyed by location.
        builder: (BuildContext context, Widget? child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Positioned.fill(
                child: GuideHintSpace(child: child ?? const SizedBox.shrink()),
              ),
              ListenableBuilder(
                listenable: router.routerDelegate,
                builder: (BuildContext context, Widget? _) =>
                    AdaptiveGuideOverlay(
                      key: ValueKey<String>(
                        router.routerDelegate.state.uri.path,
                      ),
                      router: router,
                    ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await _settle(tester);
  return router;
}

class _SetupDone extends AccountOnboardingCompleteNotifier {
  @override
  bool build() => true;
}

class _ReadyBoundary extends AuthSessionBoundaryNotifier {
  @override
  AuthSessionBoundary build() => const AuthSessionBoundary(
    generation: 1,
    userId: _account,
    isTransitioning: false,
    isStorageReady: true,
  );
}

class _NoTasks implements ITaskRepository {
  @override
  Future<List<TaskEntity>> getAllTasks() async => <TaskEntity>[];
  @override
  Future<TaskEntity?> getTaskById(String id) async => null;
  @override
  Future<void> saveTask(TaskEntity task) async {}
  @override
  Future<void> deleteTask(String id) async {}
}

const DailyDecisionIntelligence _decision = DailyDecisionIntelligence(
  primaryAction: 'Work on Task A',
  momentum: '60% steady',
  trajectory: 'Stable',
  energy: '70% energy',
  warning: 'No material constraint is supported by the current evidence.',
  recovery: 'Protect a short recovery window.',
  recommendedAction: 'Work on Task A',
  rationale: 'Task A is the highest feasible item.',
  changeSummary: 'Task A moved up.',
  evidence: <String>['priority=5'],
  confidence: .7,
  observedOutcomes: 1,
);
