import 'package:fantastic_guacamole/features/nexus/ui/nexus_screen.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/state/models/trajectory_summary_view.dart';
import 'package:fantastic_guacamole/ui/widgets/holo_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Nexus action hub is the only surface that reaches several core
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
    testWidgets('action hub "$label" navigates to $expected', (
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
          reason: '"$label" must stay reachable from the Nexus action hub.',
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
  lastSessionXp: 0,
  lastSessionQuality: 0.0,
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
  lastSessionXp: 10,
  lastSessionQuality: 0.6,
  pressureIndex: 10,
  behaviorDivergence: 5,
  alert: '',
  predictionTitle: null,
  predictionOutcome: null,
  predictionProbability: null,
  predictionExplanation: null,
);
