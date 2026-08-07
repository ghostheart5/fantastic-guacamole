import 'package:fantastic_guacamole/features/progression/ui/progression_screen.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/state/models/trajectory_summary_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Progression had no widget coverage at all despite being a 600+ line screen
/// that renders XP, level, streak and weekly summary state. These are smoke
/// tests: they prove the screen mounts and survives the states a real user
/// actually hits, rather than asserting on exact copy.
void main() {
  Future<ProviderContainer> pumpProgression(
    WidgetTester tester, {
    required TrajectorySummaryView trajectory,
  }) async {
    tester.platformDispatcher.views.first
      ..physicalSize = const Size(1200, 4000)
      ..devicePixelRatio = 1.0;
    addTearDown(() {
      tester.platformDispatcher.views.first
        ..resetPhysicalSize()
        ..resetDevicePixelRatio();
    });

    final ProviderContainer container = ProviderContainer(
      overrides: [trajectorySummaryProvider.overrideWithValue(trajectory)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ProgressionScreen()),
      ),
    );
    await tester.pump();
    return container;
  }

  testWidgets('renders for a brand-new account with zeroed progress', (
    WidgetTester tester,
  ) async {
    await pumpProgression(tester, trajectory: _emptyTrajectory);

    expect(find.text('PROGRESSION'), findsOneWidget);
    expect(
      tester.takeException(),
      isNull,
      reason: 'A zeroed account is the first thing every new user sees.',
    );
  });

  testWidgets('renders for an established account with real progress', (
    WidgetTester tester,
  ) async {
    await pumpProgression(tester, trajectory: _activeTrajectory);

    expect(find.text('PROGRESSION'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('survives a trajectory carrying prediction fields', (
    WidgetTester tester,
  ) async {
    // Every existing fixture in the suite left the prediction fields null, so
    // the populated-prediction path had never been rendered anywhere.
    await pumpProgression(tester, trajectory: _predictiveTrajectory);

    expect(find.text('PROGRESSION'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

const TrajectorySummaryView _emptyTrajectory = TrajectorySummaryView(
  pendingTasks: 0,
  completedTasks: 0,
  completedToday: 0,
  level: 1,
  streak: 0,
  energy: 0.5,
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
  pendingTasks: 4,
  completedTasks: 27,
  completedToday: 3,
  level: 6,
  streak: 12,
  energy: 0.78,
  momentum: 0.66,
  adaptability: 0.71,
  lastSessionXp: 25,
  lastSessionQuality: 0.83,
  pressureIndex: 34,
  behaviorDivergence: 12,
  alert: 'Trajectory is calm.',
  predictionTitle: null,
  predictionOutcome: null,
  predictionProbability: null,
  predictionExplanation: null,
);

const TrajectorySummaryView _predictiveTrajectory = TrajectorySummaryView(
  pendingTasks: 2,
  completedTasks: 9,
  completedToday: 1,
  level: 3,
  streak: 5,
  energy: 0.6,
  momentum: 0.4,
  adaptability: 0.6,
  lastSessionXp: 15,
  lastSessionQuality: 0.7,
  pressureIndex: 20,
  behaviorDivergence: 8,
  alert: 'Momentum dipping.',
  predictionTitle: 'Streak at risk',
  predictionOutcome: 'Streak breaks within two days',
  predictionProbability: 0.62,
  predictionExplanation: 'Completion rate fell for three consecutive days.',
);
