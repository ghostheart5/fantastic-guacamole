import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:fantastic_guacamole/data/models/auth_models.dart';
import 'package:fantastic_guacamole/state/core/app_providers.dart';
import 'package:fantastic_guacamole/state/providers/auth_session_boundary_provider.dart';
import 'package:fantastic_guacamole/state/providers/daily_decision_intelligence_provider.dart';
import 'package:fantastic_guacamole/state/providers/intelligence_provider.dart';
import 'package:fantastic_guacamole/tutorial/adaptive_guide_overlay.dart';
import 'package:fantastic_guacamole/tutorial/adaptive_guidance.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
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
                        router.routerDelegate.currentConfiguration.uri.path;
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

      expect(find.text('Capture the first real commitment'), findsNothing);

      router.go(RoutePaths.nexus);
      await tester.pump();
      expect(find.text('Capture the first real commitment'), findsOneWidget);

      final Future<void> pushed = router.push<void>(RoutePaths.login);
      await tester.pump();
      expect(find.text('Capture the first real commitment'), findsNothing);

      router.pop();
      await pushed;
      await tester.pump();
      expect(find.text('Capture the first real commitment'), findsOneWidget);
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
