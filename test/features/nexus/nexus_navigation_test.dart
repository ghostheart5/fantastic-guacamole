import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/log_entry_entity.dart';
import 'package:fantastic_guacamole/domain/entities/memory_entity.dart';
import 'package:fantastic_guacamole/domain/entities/notification_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/features/nexus/ui/nexus_screen.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/state/models/core_values_models.dart';
import 'package:fantastic_guacamole/state/models/insight_model.dart';
import 'package:fantastic_guacamole/state/models/insights_models.dart';
import 'package:fantastic_guacamole/state/models/si_pipeline_models.dart';
import 'package:fantastic_guacamole/state/models/personal_alignment_models.dart';
import 'package:fantastic_guacamole/state/models/trajectory_summary_view.dart';
import 'package:fantastic_guacamole/ui/widgets/holo_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// The Nexus home screen is the only surface that reaches several core
/// features. Timeline and Progression were previously absent from every
/// navigation surface in the app, so they were unreachable without a deep
/// link. These tests pin that they stay reachable and route to the right view.
void main() {
  for (final (String label, AppView expected) in <(String, AppView)>[
    ('Timeline', AppView.timeline),
    ('Progression', AppView.progression),
    ('SI Console', AppView.console),
    ('Create Task', AppView.creator),
    ('Plan View', AppView.plan),
  ]) {
    testWidgets('Nexus "$label" navigates to $expected', (
      WidgetTester tester,
    ) async {
      // The action grid is the last sliver on a long screen, so the default
      // 800x600 viewport never builds it. A tall surface renders the whole
      // scroll view at once and keeps this test about routing, not scrolling.
      tester.platformDispatcher.views.first
        ..physicalSize = const Size(1200, 4000)
        ..devicePixelRatio = 1.0;
      addTearDown(() {
        tester.platformDispatcher.views.first
          ..resetPhysicalSize()
          ..resetDevicePixelRatio();
      });

      final SemanticsHandle semantics = tester.ensureSemantics();

      final ProviderContainer container = ProviderContainer(
        overrides: [
          // NotificationNotifier.build schedules a timer that outlives the
          // test frame, so pin it the way the Nexus smoke test does.
          unreadNotificationsProvider.overrideWithValue(0),
        ],
      );
      addTearDown(container.dispose);

      try {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: NexusScreen()),
          ),
        );
        await tester.pump();

        // HoloButton uppercases the visible text but exposes the original
        // casing as its semantics label, so screen readers announce it
        // properly.
        expect(
          find.bySemanticsLabel(label),
          findsWidgets,
          reason: '"$label" must stay reachable from the Nexus home screen.',
        );

        // Scope to the button: several of these words also appear as
        // dependency-mesh card titles higher up the same screen, and those
        // labels are not navigation controls.
        final Finder button = find.descendant(
          of: find.byType(HoloButton),
          matching: find.text(label.toUpperCase()),
        );
        expect(button, findsOneWidget);

        await tester.tap(button);
        await tester.pump();

        expect(container.read(appFlowProvider), expected);
      } finally {
        // Must dispose inside the test body: the framework verifies no
        // handle is outstanding before addTearDown callbacks run.
        semantics.dispose();
      }
    });
  }

  group('first-run call to action', () {
    Future<void> pumpNexus(
      WidgetTester tester, {
      required TrajectorySummaryView trajectory,
      required ProviderContainer container,
    }) async {
      tester.platformDispatcher.views.first
        ..physicalSize = const Size(1200, 4000)
        ..devicePixelRatio = 1.0;
      addTearDown(() {
        tester.platformDispatcher.views.first
          ..resetPhysicalSize()
          ..resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: NexusScreen()),
        ),
      );
      await tester.pump();
    }

    ProviderContainer containerFor(TrajectorySummaryView trajectory) {
      return ProviderContainer(
        overrides: [
          unreadNotificationsProvider.overrideWithValue(0),
          trajectorySummaryProvider.overrideWithValue(trajectory),
        ],
      );
    }

    testWidgets('is shown, and creates a task, when nothing exists yet', (
      WidgetTester tester,
    ) async {
      final ProviderContainer container = containerFor(_emptyTrajectory);
      addTearDown(container.dispose);

      await pumpNexus(
        tester,
        trajectory: _emptyTrajectory,
        container: container,
      );

      expect(find.text('Start here'), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byType(HoloButton),
          matching: find.text('CREATE YOUR FIRST TASK'),
        ),
      );
      await tester.pump();

      expect(container.read(appFlowProvider), AppView.creator);
    });

    testWidgets('is hidden once the user already has tasks', (
      WidgetTester tester,
    ) async {
      final ProviderContainer container = containerFor(_activeTrajectory);
      addTearDown(container.dispose);

      await pumpNexus(
        tester,
        trajectory: _activeTrajectory,
        container: container,
      );

      expect(find.text('Start here'), findsNothing);
    });
  });

  group('header actions', () {
    GoRouter buildRouter() => GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (context, state) => const NexusScreen()),
        GoRoute(
          path: RoutePaths.login,
          builder: (context, state) =>
              const Scaffold(body: Text('LOGIN_SURFACE')),
        ),
        GoRoute(
          path: RoutePaths.notifications,
          builder: (context, state) =>
              const Scaffold(body: Text('NOTIFICATIONS_SURFACE')),
        ),
      ],
    );

    testWidgets('the notification bell navigates to the notifications route', (
      WidgetTester tester,
    ) async {
      final ProviderContainer container = ProviderContainer(
        overrides: [unreadNotificationsProvider.overrideWithValue(0)],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: buildRouter()),
        ),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.notifications_outlined));
      await tester.pumpAndSettle();

      expect(find.text('NOTIFICATIONS_SURFACE'), findsOneWidget);
    });

    testWidgets('signing out (mock session) returns to the login route', (
      WidgetTester tester,
    ) async {
      final ProviderContainer container = ProviderContainer(
        overrides: [
          unreadNotificationsProvider.overrideWithValue(0),
          mockAuthSessionProvider.overrideWith(_ActiveMockSessionNotifier.new),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: buildRouter()),
        ),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.logout));
      await tester.pumpAndSettle();

      expect(find.text('LOGIN_SURFACE'), findsOneWidget);
      expect(container.read(mockAuthSessionProvider), isFalse);
    });
  });

  group('dependency mesh', () {
    testWidgets('a sync failure shows the degraded status strip', (
      WidgetTester tester,
    ) async {
      tester.platformDispatcher.views.first
        ..physicalSize = const Size(1200, 4000)
        ..devicePixelRatio = 1.0;
      addTearDown(() {
        tester.platformDispatcher.views.first
          ..resetPhysicalSize()
          ..resetDevicePixelRatio();
      });

      final ProviderContainer container = ProviderContainer(
        // FutureProviders retry a thrown error with backoff by default
        // (ProviderContainer.defaultRetry); disable it so the failure
        // settles into a stable AsyncError within a single pump.
        retry: (int retryCount, Object error) => null,
        overrides: [
          unreadNotificationsProvider.overrideWithValue(0),
          nexusScreenModelProvider.overrideWith(
            (Ref ref) async => throw Exception('sync failed'),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: NexusScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text("Couldn't update — showing last saved"), findsOneWidget);
    });

    testWidgets('a populated model renders card headlines', (
      WidgetTester tester,
    ) async {
      tester.platformDispatcher.views.first
        ..physicalSize = const Size(1200, 4000)
        ..devicePixelRatio = 1.0;
      addTearDown(() {
        tester.platformDispatcher.views.first
          ..resetPhysicalSize()
          ..resetDevicePixelRatio();
      });

      final ProviderContainer container = ProviderContainer(
        overrides: [
          unreadNotificationsProvider.overrideWithValue(0),
          nexusScreenModelProvider.overrideWith(
            (Ref ref) async => _populatedNexusModel,
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: NexusScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Up to date'), findsOneWidget);
      expect(find.text('Finish quarterly review'), findsOneWidget);
      expect(find.text('Ship the launch plan'), findsOneWidget);
    });
  });
}

class _ActiveMockSessionNotifier extends MockAuthSessionNotifier {
  @override
  bool build() => true;
}

final NexusScreenModel _populatedNexusModel = NexusScreenModel(
  aggregation: SIStateAggregation(
    tasks: <Task>[
      const Task(
        id: 'task-1',
        title: 'Finish quarterly review',
        priority: 3,
        difficulty: 3,
        energyRequired: 3,
        goalId: 'goal-1',
      ),
    ],
    goals: <GoalEntity>[
      GoalEntity(
        id: 'goal-1',
        title: 'Ship the launch plan',
        createdAt: DateTime.utc(2026, 7, 1),
      ),
    ],
    insights: const InsightsBundle(
      items: <Insight>[],
      summary: 'Stable',
      healthScore: 0.76,
    ),
    logs: const <LogEntryEntity>[],
    timeline: const <TimelineEventEntity>[],
    memories: const <MemoryEntity>[],
    notifications: const <NotificationEntity>[],
    planPreview: const <String>['Lock sprint scope'],
    profile: _PopulatedProfileController().build(),
    siState: const SIState(energy: 0.78, fatigue: 0.24, completedToday: 4),
    trajectory: _activeTrajectory,
    signals: const SISignalExtraction(
      friction: false,
      overwhelm: false,
      streakHealth: 'High',
      goalDrift: false,
      taskAvoidance: false,
      emotion: 'focused',
      emotionalStrain: false,
      emotionalStability: true,
      emotionalPatterns: <String>['steady'],
    ),
    coreValues: const CoreValuesAlignment(
      scores: <CoreValueType, CoreValueScore>{},
      overall: 70,
      strongest: CoreValueType.discipline,
      mostNeglected: CoreValueType.connection,
      recommendations: <String>[],
      selectedValues: <String>{'Discipline', 'Purpose'},
    ),
    personalAlignment: const PersonalAlignmentAlignment(
      scores: <PersonalAlignmentDimension, PersonalAlignmentDimensionScore>{},
      overall: 72,
      strongest: PersonalAlignmentDimension.purpose,
      weakest: PersonalAlignmentDimension.growthJourney,
      recommendations: <String>[],
    ),
  ),
  decision: const SIDecisionOutput(
    nextAction: 'Lock sprint scope',
    plannerMessage: 'Stay with the current sprint focus.',
    suggestedPlanAdjustments: <String>['Hold one high-priority lane'],
    insightPrompts: <String>['What can be simplified?'],
    progressionFeedback: 'Momentum is compounding.',
    warnings: <String>[],
  ),
);

class _PopulatedProfileController extends ProfileController {
  @override
  ProfileState build() => ProfileState(
    xp: 460,
    level: 10,
    streak: 21,
    longestStreak: 21,
    name: 'Operative',
  );
}

const TrajectorySummaryView _emptyTrajectory = TrajectorySummaryView(
  pendingTasks: 0,
  completedTasks: 0,
  completedToday: 0,
  level: 1,
  streak: 0,
  energy: 0.7,
  momentum: 0.0,
  adaptability: 0.5,
  lastCompletionXp: 0,
  lastCompletionQuality: 0.0,
  pressureIndex: 0,
  behaviorDivergence: 0,
  alert: '',
  predictionTitle: null,
  predictionOutcome: null,
  predictionProbability: null,
  predictionExplanation: null,
);

const TrajectorySummaryView _activeTrajectory = TrajectorySummaryView(
  pendingTasks: 2,
  completedTasks: 3,
  completedToday: 1,
  level: 2,
  streak: 4,
  energy: 0.7,
  momentum: 0.5,
  adaptability: 0.5,
  lastCompletionXp: 10,
  lastCompletionQuality: 0.6,
  pressureIndex: 10,
  behaviorDivergence: 5,
  alert: '',
  predictionTitle: null,
  predictionOutcome: null,
  predictionProbability: null,
  predictionExplanation: null,
);
