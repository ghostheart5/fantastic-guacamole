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
const String _otherAccount = 'hint-card-other-user';
const Key _card = Key('guide_hint_card');

String _prefixFor(String account) =>
    'adaptive_guidance_v3.${AccountStorageScope.authenticated(account).v2Namespace}';

String get _prefix => _prefixFor(_account);

const List<String> _core = <String>[
  'createFirstItem',
  'scheduleFirstItem',
  'reviewTimeline',
];

Map<String, Object> _coreFinishedFor(String account) {
  final int at = DateTime.utc(2020).millisecondsSinceEpoch;
  return <String, Object>{
    for (final String milestone in <String>[
      'firstItem',
      'firstSchedule',
      'firstTimelineReview',
    ]) ...<String, Object>{
      '${_prefixFor(account)}.$milestone.at': at,
      '${_prefixFor(account)}.$milestone.count': 1,
    },
  };
}

Map<String, Object> get _coreFinished => _coreFinishedFor(_account);

Map<String, Object> get _coreSkipped => <String, Object>{
  for (final String id in _core) '$_prefix.skip.$id': true,
};

Map<String, Object> get _corePaused => <String, Object>{
  for (final String id in _core) '$_prefix.later.$id': true,
};

/// Sets the test window in logical pixels, so MediaQuery sees exactly this.
void _setWindow(WidgetTester tester, Size size, {double keyboard = 0}) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
}

Future<bool?> _storedSeen(String account) async =>
    (await SharedPreferences.getInstance()).getBool(
      '${_prefixFor(account)}.complete.siConsole',
    );

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

  for (final String action in <String>['Not now', 'Got it']) {
    testWidgets('after "$action" the hint does not return on re-entry or '
        'restart', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(_coreFinished);
      final GoRouter router = await _pumpApp(tester, _Page());
      expect(find.byKey(_card), findsOneWidget);
      // Drawn, so already stored as seen; it stays until acted on.
      expect(await _storedSeen(_account), isTrue);
      await tester.pump(const Duration(seconds: 2));
      expect(find.byKey(_card), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, action));
      await _settle(tester);
      // Only the button closes the card on this visit; only "Not now" mutes.
      expect(find.byKey(_card), findsNothing);
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getBool('$_prefix.skip.siConsole'),
        action == 'Not now' ? isTrue : isNull,
      );

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

  testWidgets('a hint that cannot be drawn is not stored as seen', (
    WidgetTester tester,
  ) async {
    addTearDown(tester.view.reset);
    // A landscape phone or split screen: too short for the card.
    _setWindow(tester, const Size(600, 330));
    SharedPreferences.setMockInitialValues(_coreFinished);
    await _pumpApp(tester, _Page());
    expect(
      MediaQuery.sizeOf(tester.element(find.byKey(const Key('page-title')))),
      const Size(600, 330),
    );
    expect(find.byKey(_card), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    expect(await _storedSeen(_account), isNull);
    expect(tester.takeException(), isNull);

    _setWindow(tester, const Size(600, 800));
    await _settle(tester);
    expect(find.byKey(_card), findsOneWidget);
    expect(await _storedSeen(_account), isTrue);
  });

  testWidgets('arriving with the keyboard open: no card and not seen until '
      'the keyboard closes', (WidgetTester tester) async {
    addTearDown(tester.view.reset);
    _setWindow(tester, const Size(320, 640), keyboard: 280);
    SharedPreferences.setMockInitialValues(_coreFinished);
    final _Page page = _Page();
    await _pumpApp(tester, page, textScale: 2);
    expect(find.byKey(_card), findsNothing);
    expect(await _storedSeen(_account), isNull);
    // The composer above the keyboard can be used.
    await tester.tap(find.byKey(const Key('bottom-action')));
    expect(page.bottomTaps, 1);

    _setWindow(tester, const Size(320, 640));
    await _settle(tester);
    expect(find.byKey(_card), findsOneWidget);
    expect(await _storedSeen(_account), isTrue);
    expect(tester.takeException(), isNull);
  });

  for (final String language in <String>['en', 'es']) {
    testWidgets('$language: the keyboard opening closes a seen hint for the '
        'visit and gives the page its room back', (WidgetTester tester) async {
      addTearDown(tester.view.reset);
      _setWindow(tester, const Size(320, 640));
      SharedPreferences.setMockInitialValues(_coreFinished);
      final _Page page = _Page();
      await _pumpApp(tester, page, language: language, textScale: 2);
      expect(find.byKey(_card), findsOneWidget);
      final double withCard = tester
          .getRect(find.byKey(const Key('page-title')))
          .top;
      expect(withCard, greaterThan(100));

      _setWindow(tester, const Size(320, 640), keyboard: 280);
      await _settle(tester);
      expect(find.byKey(_card), findsNothing);
      expect(tester.takeException(), isNull);
      expect(
        tester.getRect(find.byKey(const Key('page-title'))).top,
        lessThan(withCard),
      );
      final Finder composer = find.byKey(const Key('bottom-action'));
      expect(composer.hitTestable(), findsOneWidget);
      expect(tester.getRect(composer).bottom, lessThanOrEqualTo(640 - 280));
      await tester.tap(composer);
      expect(page.bottomTaps, 1);
      final double typing = tester
          .getRect(find.byKey(const Key('page-title')))
          .top;

      // Closing the keyboard does not bring the card back on this visit, so
      // the page does not jump again.
      _setWindow(tester, const Size(320, 640));
      await _settle(tester);
      expect(find.byKey(_card), findsNothing);
      expect(tester.getRect(find.byKey(const Key('page-title'))).top, typing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$language: a dialog covers the hint, and nothing moves under '
        'it', (WidgetTester tester) async {
      addTearDown(tester.view.reset);
      _setWindow(tester, const Size(320, 640));
      final SemanticsHandle semantics = tester.ensureSemantics();
      SharedPreferences.setMockInitialValues(_coreFinished);
      await _pumpApp(tester, _Page(), language: language, textScale: 2);
      final String dismiss = language == 'es' ? 'Ahora no' : 'Not now';
      expect(find.byKey(_card), findsOneWidget);
      final double pageTop = tester
          .getRect(find.byKey(const Key('page-title')))
          .top;

      await tester.tap(find.byKey(const Key('open-dialog')));
      await _settle(tester);
      expect(find.text('A dialog'), findsOneWidget);
      expect(
        find.widgetWithText(TextButton, dismiss).hitTestable(),
        findsNothing,
      );
      // Not reachable by screen readers behind the dialog either.
      expect(find.semantics.byLabel(dismiss), findsNothing);
      expect(tester.getRect(find.byKey(const Key('page-title'))).top, pageTop);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Close dialog'));
      await _settle(tester);
      expect(
        find.widgetWithText(TextButton, dismiss).hitTestable(),
        findsOneWidget,
      );
      expect(find.semantics.byLabel(dismiss), findsOne);
      semantics.dispose();
    });

    testWidgets('$language hint fits 320 dp at 200% text and keeps the page '
        'usable', (WidgetTester tester) async {
      addTearDown(tester.view.reset);
      _setWindow(tester, const Size(320, 640));
      SharedPreferences.setMockInitialValues(_coreFinished);
      final _Page page = _Page();
      await _pumpApp(tester, page, language: language, textScale: 2);
      final bool es = language == 'es';
      final BuildContext pageContext = tester.element(
        find.byKey(const Key('page-title')),
      );
      expect(MediaQuery.sizeOf(pageContext), const Size(320, 640));
      expect(MediaQuery.textScalerOf(pageContext).scale(10), 20);

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
      await tester.tap(find.byKey(const Key('bottom-action')));
      expect(page.bottomTaps, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$language hint is read first, announced as a hint, and its '
        'buttons work from a screen reader', (WidgetTester tester) async {
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

      final SemanticsNode cardNode = tester.getSemantics(find.byKey(_card));
      expect(
        cardNode,
        isSemantics(label: '$hintLabel. $title', isLiveRegion: true),
      );
      // Screen readers reach the hint before the page under it.
      final List<SemanticsNode> order = tester.semantics
          .simulatedAccessibilityTraversal()
          .toList();
      final SemanticsNode pageTitle = tester.getSemantics(
        find.byKey(const Key('page-title')),
      );
      expect(order.indexOf(cardNode), isNonNegative);
      expect(order.indexOf(cardNode), lessThan(order.indexOf(pageTitle)));

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
      // The tap closed the card; "Got it" is not a mute.
      expect(find.byKey(_card), findsNothing);
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('$_prefix.skip.siConsole'), isNull);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  }

  testWidgets('switching accounts on the same page: each account sees its '
      'own hint once, and only its own record is written', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      ..._coreFinishedFor(_account),
      ..._coreFinishedFor(_otherAccount),
    });
    await _pumpApp(tester, _Page());
    expect(find.byKey(_card), findsOneWidget);
    expect(await _storedSeen(_account), isTrue);
    expect(await _storedSeen(_otherAccount), isNull);

    final ProviderContainer container = ProviderScope.containerOf(
      tester.element(find.byKey(const Key('page-title'))),
    );
    container.read(_activeAccountProvider.notifier).switchTo(_otherAccount);
    await tester.pump();
    // A's card does not write anything for B on the way out.
    expect(await _storedSeen(_otherAccount), isNull);
    await _settle(tester);
    // B gets its own hint, stored for B once drawn; A's record is unchanged.
    expect(find.byKey(_card), findsOneWidget);
    expect(await _storedSeen(_account), isTrue);
    expect(await _storedSeen(_otherAccount), isTrue);
    expect(tester.takeException(), isNull);
  });
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
          Expanded(
            child: ListView(
              children: <Widget>[
                const Text('Chat page', key: Key('page-title')),
                TextButton(
                  key: const Key('top-action'),
                  onPressed: () => topTaps++,
                  child: const Text('Top action'),
                ),
                const TextField(key: Key('page-field')),
                Builder(
                  builder: (BuildContext context) => TextButton(
                    key: const Key('open-dialog'),
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (BuildContext context) => AlertDialog(
                        content: const Text('A dialog'),
                        actions: <Widget>[
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Close dialog'),
                          ),
                        ],
                      ),
                    ),
                    child: const Text('Open dialog'),
                  ),
                ),
              ],
            ),
          ),
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

final _activeAccountProvider = NotifierProvider<_ActiveAccount, String>(
  _ActiveAccount.new,
);

class _ActiveAccount extends Notifier<String> {
  @override
  String build() => _account;

  void switchTo(String account) => state = account;
}

Future<GoRouter> _pumpApp(
  WidgetTester tester,
  _Page page, {
  String language = 'en',
  double textScale = 1,
  int restart = 0,
}) async {
  final GuideHintModalObserver modals = GuideHintModalObserver();
  final GoRouter router = GoRouter(
    initialLocation: RoutePaths.siConsole,
    observers: <NavigatorObserver>[modals],
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
  modals.attachTo(router);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      // A new scope is a fresh app start that reads stored guidance again.
      key: ValueKey<int>(restart),
      overrides: [
        accountStorageScopeProvider.overrideWith(
          (Ref ref) => AccountStorageScope.authenticated(
            ref.watch(_activeAccountProvider),
          ),
        ),
        domainTaskRepositoryProvider.overrideWithValue(_NoTasks()),
        accountOnboardingCompleteProvider.overrideWith(_SetupDone.new),
        authUserProvider.overrideWith(
          (Ref ref) => Stream<User?>.value(
            User(
              id: ref.watch(_activeAccountProvider),
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
  AuthSessionBoundary build() {
    final String account = ref.watch(_activeAccountProvider);
    return AuthSessionBoundary(
      generation: account == _account ? 1 : 2,
      userId: account,
      isTransitioning: false,
      isStorageReady: true,
    );
  }
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
