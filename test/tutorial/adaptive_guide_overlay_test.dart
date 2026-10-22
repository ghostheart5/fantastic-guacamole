import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:fantastic_guacamole/data/models/auth_models.dart';
import 'package:fantastic_guacamole/state/core/app_providers.dart';
import 'package:fantastic_guacamole/state/providers/auth_session_boundary_provider.dart';
import 'package:fantastic_guacamole/state/providers/daily_decision_intelligence_provider.dart';
import 'package:fantastic_guacamole/state/providers/intelligence_provider.dart';
import 'package:fantastic_guacamole/tutorial/adaptive_guide_overlay.dart';
import 'package:fantastic_guacamole/tutorial/adaptive_guidance.dart';
import 'package:fantastic_guacamole/tutorial/first_run_tutorial_state.dart';
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
          await tester.binding.setSurfaceSize(const Size(320, 800));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          var chatEntries = 0;
          var underlyingActions = 0;
          final router = GoRouter(
            initialLocation: '/credit-guide',
            routes: [
              GoRoute(
                path: '/credit-guide',
                builder: (context, state) => Scaffold(
                  body: TextButton(
                    onPressed: () => underlyingActions++,
                    child: const Text('Underlying action'),
                  ),
                ),
              ),
              GoRoute(
                path: RoutePaths.siConsole,
                builder: (context, state) {
                  chatEntries++;
                  return const Scaffold(body: Text('Chat destination'));
                },
              ),
            ],
          );
          addTearDown(router.dispose);
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                onboardingCompleteProvider.overrideWith(
                  _OnboardingComplete.new,
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
            ),
          );
          await tester.pumpAndSettle();
          final explanation = find.textContaining(
            language == 'es'
                ? 'Las herramientas gratuitas no usan créditos'
                : 'Free tools use no credits',
          );
          expect(explanation, findsOneWidget);
          final scrollable = find.descendant(
            of: find.byKey(const Key('tutorial_callout_scroll_view')),
            matching: find.byType(Scrollable),
          );
          final target = dismiss
              ? find.widgetWithText(
                  TextButton,
                  language == 'es' ? 'Ahora no' : 'Not now',
                )
              : find.widgetWithText(
                  FilledButton,
                  language == 'es' ? 'Revisar las fuentes' : 'Inspect evidence',
                );
          for (
            var read = 0;
            read < 12 && target.hitTestable().evaluate().isEmpty;
            read++
          ) {
            await tester.drag(scrollable, const Offset(0, -160));
            await tester.pumpAndSettle();
          }
          expect(target.hitTestable(), findsOneWidget);
          expect(chatEntries, 0);
          expect(underlyingActions, 0);
          expect(tester.takeException(), isNull);
          await tester.tap(target.hitTestable());
          await tester.pumpAndSettle();
          expect(chatEntries, dismiss ? 0 : 1);
          expect(underlyingActions, 0);
          expect(
            router.routerDelegate.state.uri.path,
            dismiss ? '/credit-guide' : RoutePaths.siConsole,
          );
          // Primary routing retains contextual guidance; dismissal hides it.
          expect(explanation, dismiss ? findsNothing : findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('accessible review guide action opens the real Timeline route', (
    WidgetTester tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final router = GoRouter(
      initialLocation: RoutePaths.creator,
      routes: [
        GoRoute(
          path: RoutePaths.creator,
          builder: (context, state) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => fail('Covered screen action was activated'),
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
          onboardingCompleteProvider.overrideWith(_OnboardingComplete.new),
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
    expect(find.text('Find your saved task'), findsOneWidget);
    final action = tester.getSemantics(
      find.widgetWithText(FilledButton, 'Open schedule'),
    );
    tester.binding.renderViews.single.owner!.semanticsOwner!.performAction(
      action.id,
      SemanticsAction.tap,
    );
    await tester.pump();
    await tester.pump();
    expect(router.routerDelegate.state.uri.path, RoutePaths.timeline);
    expect(find.text('Timeline route opened'), findsOneWidget);
    expect(find.text('Find your saved task'), findsNothing);
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
            onboardingCompleteProvider.overrideWith(_OnboardingComplete.new),
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
        onboardingCompleteProvider.overrideWith(_OnboardingComplete.new),
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

  @override
  Future<void> skip(GuidanceLessonId lesson) async {
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
}

class _OnboardingComplete extends OnboardingCompleteNotifier {
  @override
  bool build() => true;
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
