import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:fantastic_guacamole/data/models/auth_models.dart';
import 'package:fantastic_guacamole/state/core/app_providers.dart';
import 'package:fantastic_guacamole/state/providers/account_onboarding_provider.dart';
import 'package:fantastic_guacamole/state/providers/auth_session_boundary_provider.dart';
import 'package:fantastic_guacamole/state/providers/daily_decision_intelligence_provider.dart';
import 'package:fantastic_guacamole/state/providers/intelligence_provider.dart';
import 'package:fantastic_guacamole/tutorial/adaptive_guide_overlay.dart';
import 'package:fantastic_guacamole/tutorial/adaptive_guidance.dart';
import 'package:fantastic_guacamole/tutorial/first_run_tutorial_state.dart';
import 'package:fantastic_guacamole/tutorial/guide_hint_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  for (final language in ['en', 'es']) {
    for (final dismiss in [false, true]) {
      testWidgets(
        '$language credit guidance remains reachable at 320px and 200 percent text, dismiss=$dismiss',
        (tester) async {
          // Sets the window MediaQuery reads, in logical pixels.
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = const Size(320, 800);
          addTearDown(tester.view.reset);
          var underlyingActions = 0;
          final router = GoRouter(
            initialLocation: RoutePaths.siConsole,
            routes: [
              GoRoute(
                path: RoutePaths.siConsole,
                builder: (context, state) => Scaffold(
                  body: TextButton(
                    onPressed: () => underlyingActions++,
                    child: const Text('Underlying action'),
                  ),
                ),
              ),
              GoRoute(
                path: RoutePaths.settings,
                builder: (context, state) =>
                    const Scaffold(body: Text('Settings')),
              ),
            ],
          );
          addTearDown(router.dispose);
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                accountOnboardingCompleteProvider.overrideWith(
                  () => _FixedAccountOnboarding(true),
                ),
                authUserProvider.overrideWith(
                  (ref) => Stream<User?>.value(
                    const User(
                      id: 'account-a',
                      email: 'account-a@example.test',
                      emailVerified: true,
                    ),
                  ),
                ),
                authSessionBoundaryProvider.overrideWith(
                  () => _FixedBoundary(
                    const AuthSessionBoundary(
                      generation: 1,
                      userId: 'account-a',
                      isTransitioning: false,
                      isStorageReady: true,
                    ),
                  ),
                ),
                adaptiveGuidanceProvider.overrideWith(_CreditGuideState.new),
                dailyDecisionIntelligenceProvider.overrideWith(
                  (ref) => _decision,
                ),
              ],
              child: MaterialApp.router(
                locale: Locale(language),
                supportedLocales: ChronoSparkLocalizations.supportedLocales,
                localizationsDelegates: const [
                  ChronoSparkLocalizations.delegate,
                  ...GlobalMaterialLocalizations.delegates,
                ],
                routerConfig: router,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: const TextScaler.linear(2)),
                  child: Stack(
                    children: [
                      // Like the app root: a hint card moves the page down.
                      Positioned.fill(
                        child: GuideHintSpace(
                          child: child ?? const SizedBox.shrink(),
                        ),
                      ),
                      // Keyed by location like the app root, so widget
                      // state cannot hide a lesson after a route change.
                      ListenableBuilder(
                        listenable: router.routerDelegate,
                        builder: (context, child) => AdaptiveGuideOverlay(
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
          // The tutorial pointer repeats continuously; wait for its content,
          // rather than requiring every animation to become idle.
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          final explanation = find.textContaining(
            language == 'es'
                ? 'Las herramientas gratuitas no usan créditos'
                : 'Free tools use no credits',
          );
          expect(explanation, findsOneWidget);
          final container = ProviderScope.containerOf(
            tester.element(find.byType(MaterialApp)),
          );
          final _CreditGuideState notifier =
              container.read(adaptiveGuidanceProvider.notifier)
                  as _CreditGuideState;
          // Drawing the card stores it as seen once.
          expect(notifier.completeCalls, 1);
          expect(notifier.skipCalls, 0);
          // The long credit explanation scrolls inside the small hint card;
          // its buttons stay on screen the whole time.
          final scrollable = find.descendant(
            of: find.byKey(const Key('guide_hint_text')),
            matching: find.byType(Scrollable),
          );
          final target = find.widgetWithText(
            TextButton,
            dismiss
                ? (language == 'es' ? 'Ahora no' : 'Not now')
                : (language == 'es' ? 'Entendido' : 'Got it'),
          );
          expect(target.hitTestable(), findsOneWidget);
          await tester.drag(scrollable, const Offset(0, -400));
          await tester.pump(const Duration(milliseconds: 300));
          expect(target.hitTestable(), findsOneWidget);
          // The page under the hint stays usable.
          await tester.tap(find.text('Underlying action'));
          expect(underlyingActions, 1);
          expect(tester.takeException(), isNull);
          await tester.tap(target.hitTestable());
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          expect(underlyingActions, 1);
          expect(router.routerDelegate.state.uri.path, RoutePaths.siConsole);
          expect(explanation, findsNothing);
          // Only the tapped button's own call follows: "Not now" stores its
          // mute, "Got it" finishes the lesson again. Either way it does not
          // come back on the next visit.
          expect(notifier.skipCalls, dismiss ? 1 : 0);
          expect(notifier.completeCalls, dismiss ? 1 : 2);
          final saved = container.read(adaptiveGuidanceProvider).requireValue;
          expect(
            saved.skippedLessons.contains(GuidanceLessonId.siConsole),
            dismiss,
          );
          router.go(RoutePaths.settings);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          router.go(RoutePaths.siConsole);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          expect(explanation, findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final String route in <String>[
    RoutePaths.settings,
    RoutePaths.creator,
    RoutePaths.creatorGoals,
  ]) {
    testWidgets('no lesson about another screen covers $route after the '
        'first-run guide', (WidgetTester tester) async {
      var underlyingActions = 0;
      final GoRouter router = GoRouter(
        initialLocation: route,
        routes: <RouteBase>[
          GoRoute(
            path: route,
            builder: (BuildContext context, GoRouterState state) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => underlyingActions++,
                  child: const Text('Form field'),
                ),
              ),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accountOnboardingCompleteProvider.overrideWith(
              () => _FixedAccountOnboarding(true),
            ),
            authUserProvider.overrideWith(
              (ref) => Stream<User?>.value(
                const User(
                  id: 'account-a',
                  email: 'account-a@example.test',
                  emailVerified: true,
                ),
              ),
            ),
            authSessionBoundaryProvider.overrideWith(
              () => _FixedBoundary(
                const AuthSessionBoundary(
                  generation: 1,
                  userId: 'account-a',
                  isTransitioning: false,
                  isStorageReady: true,
                ),
              ),
            ),
            // Core finished long ago and every old fallback is live: low
            // confidence, no outcomes, Today never reviewed.
            adaptiveGuidanceProvider.overrideWith(_CreditGuideState.new),
            dailyDecisionIntelligenceProvider.overrideWith(
              (ref) => const DailyDecisionIntelligence(
                primaryAction: 'Wait for evidence.',
                momentum: '0% stable',
                trajectory: 'No trajectory yet.',
                energy: 'Energy not checked',
                warning: 'Too much is scheduled for Friday.',
                recovery: 'No recovery signal yet.',
                recommendedAction: 'Wait for evidence.',
                rationale: 'No evidence yet.',
                changeSummary: 'No prior state.',
                evidence: <String>[],
                confidence: 0,
                observedOutcomes: 0,
                replanAction: 'Move Task A to 3 pm.',
              ),
            ),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            builder: (context, child) => Stack(
              children: [
                ?child,
                ListenableBuilder(
                  listenable: router.routerDelegate,
                  builder: (context, child) =>
                      AdaptiveGuideOverlay(router: router),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Help with this page'), findsNothing);
      await tester.tap(find.text('Form field'));
      expect(underlyingActions, 1);
      expect(tester.takeException(), isNull);
    });
  }

  for (final bool accountComplete in <bool>[true, false]) {
    testWidgets(
      'guide overlay follows the account setup answer, not the device flag '
      '(account complete=$accountComplete)',
      (WidgetTester tester) async {
        // The schedule step is shown on Schedule only.
        final GoRouter router = GoRouter(
          initialLocation: RoutePaths.timeline,
          routes: <RouteBase>[
            GoRoute(
              path: RoutePaths.timeline,
              builder: (BuildContext context, GoRouterState state) =>
                  const Scaffold(body: SizedBox.expand()),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              // The device-wide flag is the opposite of the account answer.
              onboardingCompleteProvider.overrideWith(
                accountComplete
                    ? _OnboardingIncomplete.new
                    : _OnboardingComplete.new,
              ),
              accountOnboardingCompleteProvider.overrideWith(
                () => _FixedAccountOnboarding(accountComplete),
              ),
              authUserProvider.overrideWith(
                (ref) => Stream<User?>.value(
                  const User(
                    id: 'account-a',
                    email: 'account-a@example.test',
                    emailVerified: true,
                  ),
                ),
              ),
              authSessionBoundaryProvider.overrideWith(
                () => _FixedBoundary(
                  const AuthSessionBoundary(
                    generation: 1,
                    userId: 'account-a',
                    isTransitioning: false,
                    isStorageReady: true,
                  ),
                ),
              ),
              adaptiveGuidanceProvider.overrideWith(
                _TimelineReviewGuidance.new,
              ),
              dailyDecisionIntelligenceProvider.overrideWith(
                (ref) => _decision,
              ),
              firstRunTutorialTaskProvider.overrideWith(
                (ref, taskId) async => null,
              ),
            ],
            child: MaterialApp.router(
              routerConfig: router,
              builder: (context, child) => Stack(
                children: [
                  ?child,
                  ListenableBuilder(
                    listenable: router.routerDelegate,
                    builder: (context, child) =>
                        AdaptiveGuideOverlay(router: router),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();
        expect(
          find.text('Find your saved task'),
          accountComplete ? findsOneWidget : findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('the schedule step leaves other screens usable and appears on '
      'Schedule', (WidgetTester tester) async {
    final semantics = tester.ensureSemantics();
    var underlyingActions = 0;
    late final GoRouter router;
    router = GoRouter(
      initialLocation: RoutePaths.creator,
      routes: [
        GoRoute(
          path: RoutePaths.creator,
          builder: (context, state) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {
                  underlyingActions++;
                  router.go(RoutePaths.timeline);
                },
                child: const Text('Open Timeline'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: RoutePaths.timeline,
          builder: (context, state) =>
              const Scaffold(body: Text('Timeline route opened')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountOnboardingCompleteProvider.overrideWith(
            () => _FixedAccountOnboarding(true),
          ),
          authUserProvider.overrideWith(
            (ref) => Stream<User?>.value(
              const User(
                id: 'account-a',
                email: 'account-a@example.test',
                emailVerified: true,
              ),
            ),
          ),
          authSessionBoundaryProvider.overrideWith(
            () => _FixedBoundary(
              const AuthSessionBoundary(
                generation: 1,
                userId: 'account-a',
                isTransitioning: false,
                isStorageReady: true,
              ),
            ),
          ),
          adaptiveGuidanceProvider.overrideWith(_TimelineReviewGuidance.new),
          dailyDecisionIntelligenceProvider.overrideWith((ref) => _decision),
          firstRunTutorialTaskProvider.overrideWith(
            (ref, taskId) async => null,
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          builder: (context, child) => Stack(
            children: [
              ?child,
              ListenableBuilder(
                listenable: router.routerDelegate,
                builder: (context, child) =>
                    AdaptiveGuideOverlay(router: router),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    // Nothing covers Add something while the next step waits on Schedule.
    expect(find.text('Find your saved task'), findsNothing);
    expect(find.text('Step 2 of 2'), findsNothing);
    final action = tester.getSemantics(
      find.widgetWithText(ElevatedButton, 'Open Timeline'),
    );
    tester.binding.renderViews.single.owner!.semanticsOwner!.performAction(
      action.id,
      SemanticsAction.tap,
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(underlyingActions, 1);
    expect(router.routerDelegate.state.uri.path, RoutePaths.timeline);
    expect(find.text('Timeline route opened'), findsOneWidget);
    expect(find.text('Find your saved task'), findsOneWidget);
    expect(find.text('Step 2 of 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets(
    'guide follows route entry and back navigation from app builder',
    (WidgetTester tester) async {
      final GoRouter router = GoRouter(
        initialLocation: RoutePaths.login,
        routes: <RouteBase>[
          GoRoute(
            path: RoutePaths.login,
            builder: (BuildContext context, GoRouterState state) =>
                const SizedBox.expand(),
          ),
          GoRoute(
            path: RoutePaths.nexus,
            builder: (BuildContext context, GoRouterState state) =>
                const SizedBox.expand(),
          ),
          GoRoute(
            path: RoutePaths.paywall,
            builder: (BuildContext context, GoRouterState state) =>
                const SizedBox.expand(),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accountOnboardingCompleteProvider.overrideWith(
              () => _FixedAccountOnboarding(true),
            ),
            authUserProvider.overrideWith(
              (Ref ref) => Stream<User?>.value(
                const User(
                  id: 'account-a',
                  email: 'account-a@example.test',
                  emailVerified: true,
                ),
              ),
            ),
            authSessionBoundaryProvider.overrideWith(
              () => _FixedBoundary(
                const AuthSessionBoundary(
                  generation: 1,
                  userId: 'account-a',
                  isTransitioning: false,
                  isStorageReady: true,
                ),
              ),
            ),
            adaptiveGuidanceProvider.overrideWith(_FixedGuidance.new),
            dailyDecisionIntelligenceProvider.overrideWith(
              (Ref ref) => _decision,
            ),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            builder: (BuildContext context, Widget? child) => Stack(
              children: <Widget>[
                ?child,
                ListenableBuilder(
                  listenable: router.routerDelegate,
                  builder: (BuildContext context, Widget? child) {
                    final String location =
                        router.routerDelegate.currentConfiguration.isEmpty
                        ? ''
                        : router.routerDelegate.state.uri.path;
                    return AdaptiveGuideOverlay(
                      key: ValueKey<String>(location),
                      router: router,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      final ProviderContainer container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      await container.read(authUserProvider.future);
      await container.read(adaptiveGuidanceProvider.future);

      expect(find.text('Add your first task'), findsNothing);

      router.go(RoutePaths.nexus);
      await tester.pump();
      await tester.pump();
      expect(router.routerDelegate.state.uri.path, RoutePaths.nexus);
      expect(find.text('Add your first task'), findsOneWidget);

      final Future<void> pushed = router.push<void>(RoutePaths.paywall);
      await tester.pump();
      expect(find.text('Add your first task'), findsNothing);

      router.pop();
      await pushed;
      await tester.pump();
      await tester.pump();
      expect(find.text('Add your first task'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('signed-out guide does not subscribe to account intelligence', (
    WidgetTester tester,
  ) async {
    await _expectDecisionProviderNotRead(
      tester,
      user: null,
      boundary: const AuthSessionBoundary(
        generation: 1,
        userId: null,
        isTransitioning: false,
        isStorageReady: true,
      ),
    );
  });

  testWidgets(
    'authenticated guide waits for matching writable account storage',
    (WidgetTester tester) async {
      await _expectDecisionProviderNotRead(
        tester,
        user: const User(
          id: 'account-a',
          email: 'account-a@example.test',
          emailVerified: true,
        ),
        boundary: const AuthSessionBoundary(
          generation: 2,
          userId: 'account-a',
          isTransitioning: false,
          isStorageReady: false,
        ),
      );
    },
  );
}

Future<void> _expectDecisionProviderNotRead(
  WidgetTester tester, {
  required User? user,
  required AuthSessionBoundary boundary,
}) async {
  int decisionProviderReads = 0;
  final GoRouter router = GoRouter(
    initialLocation: RoutePaths.nexus,
    routes: <RouteBase>[
      GoRoute(
        path: RoutePaths.nexus,
        builder: (BuildContext context, GoRouterState state) =>
            const SizedBox.expand(),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        accountOnboardingCompleteProvider.overrideWith(
          () => _FixedAccountOnboarding(true),
        ),
        authUserProvider.overrideWith((Ref ref) => Stream<User?>.value(user)),
        authSessionBoundaryProvider.overrideWith(
          () => _FixedBoundary(boundary),
        ),
        dailyDecisionIntelligenceProvider.overrideWith((Ref ref) {
          decisionProviderReads++;
          return _decision;
        }),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        builder: (BuildContext context, Widget? child) => Stack(
          children: <Widget>[
            ?child,
            AdaptiveGuideOverlay(router: router),
          ],
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();

  expect(decisionProviderReads, 0);
  expect(tester.takeException(), isNull);
}

class _CreditGuideState extends AdaptiveGuidanceNotifier {
  @override
  Future<AdaptiveGuidanceState> build() async => AdaptiveGuidanceState(
    milestones: {
      GuidanceMilestone.firstItem: DateTime.utc(2020),
      GuidanceMilestone.firstSchedule: DateTime.utc(2020),
      GuidanceMilestone.firstTimelineReview: DateTime.utc(2020),
    },
    counts: const {},
    skippedLessons: const {},
    completedLessons: const {},
  );

  int skipCalls = 0;
  int completeCalls = 0;

  @override
  Future<void> skip(GuidanceLessonId lesson) async {
    skipCalls++;
    final current = state.requireValue;
    state = AsyncData(
      AdaptiveGuidanceState(
        milestones: current.milestones,
        counts: current.counts,
        skippedLessons: {...current.skippedLessons, lesson},
        completedLessons: current.completedLessons,
      ),
    );
  }

  @override
  Future<void> completeLesson(GuidanceLessonId lesson) async {
    completeCalls++;
    final current = state.requireValue;
    state = AsyncData(
      AdaptiveGuidanceState(
        milestones: current.milestones,
        counts: current.counts,
        skippedLessons: current.skippedLessons,
        completedLessons: {...current.completedLessons, lesson},
      ),
    );
  }
}

class _OnboardingComplete extends OnboardingCompleteNotifier {
  @override
  bool build() => true;
}

class _OnboardingIncomplete extends OnboardingCompleteNotifier {
  @override
  bool build() => false;
}

class _FixedAccountOnboarding extends AccountOnboardingCompleteNotifier {
  _FixedAccountOnboarding(this.value);

  final bool value;

  @override
  bool build() => value;
}

class _FixedBoundary extends AuthSessionBoundaryNotifier {
  _FixedBoundary(this.value);

  final AuthSessionBoundary value;

  @override
  AuthSessionBoundary build() => value;
}

class _FixedGuidance extends AdaptiveGuidanceNotifier {
  @override
  Future<AdaptiveGuidanceState> build() async => const AdaptiveGuidanceState(
    milestones: <GuidanceMilestone, DateTime>{},
    counts: <GuidanceMilestone, int>{},
    skippedLessons: <GuidanceLessonId>{},
    completedLessons: <GuidanceLessonId>{},
    laterLessons: <GuidanceLessonId>{},
    replayLessons: <GuidanceLessonId>{GuidanceLessonId.createFirstItem},
  );
}

class _TimelineReviewGuidance extends AdaptiveGuidanceNotifier {
  @override
  Future<AdaptiveGuidanceState> build() async => const AdaptiveGuidanceState(
    milestones: {},
    counts: {},
    skippedLessons: {},
    completedLessons: {},
    replayLessons: {GuidanceLessonId.reviewTimeline},
    expectedFirstRunCreatorTaskIds: {'saved-task'},
  );
}

const DailyDecisionIntelligence _decision = DailyDecisionIntelligence(
  primaryAction: 'Wait for evidence.',
  momentum: '0% stable',
  trajectory: 'No trajectory yet.',
  energy: 'Energy not checked',
  warning: 'No material constraint is supported by current evidence.',
  recovery: 'No recovery signal yet.',
  recommendedAction: 'Wait for evidence.',
  rationale: 'No evidence yet.',
  changeSummary: 'No prior state.',
  evidence: <String>[],
  confidence: 0,
  observedOutcomes: 0,
);
