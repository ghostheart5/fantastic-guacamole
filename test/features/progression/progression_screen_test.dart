import 'package:fantastic_guacamole/features/progression/ui/progression_screen.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/state/models/trajectory_summary_view.dart';
import 'package:fantastic_guacamole/state/providers/advisor_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  // L-27: _AdvisorSummaryCard's error branch was implemented but untested — a
  // weekly-summary fetch failure must degrade to a plain message, not crash
  // or hang on the loading copy forever.
  testWidgets(
    'a weekly summary fetch failure shows the degraded advisor message',
    (WidgetTester tester) async {
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
          trajectorySummaryProvider.overrideWithValue(_activeTrajectory),
          weeklySummaryProvider.overrideWith(
            (Ref ref) async => throw Exception('summary failed'),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: ProgressionScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        find.text(
          'Not enough saved evidence yet. Add or complete an item, then return to see a grounded progression signal.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('the back arrow returns to the planner view', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = await pumpProgression(
      tester,
      trajectory: _activeTrajectory,
    );
    // Simulate having arrived here from somewhere other than the planner, so
    // tapping back is actually exercising a transition, not a no-op.
    container.read(appFlowProvider.notifier).toProgression();
    await tester.pump();

    await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
    await tester.pump();

    expect(container.read(appFlowProvider), AppView.nexus);
  });

  testWidgets(
    'share progress falls back to clipboard + SnackBar when the share sheet is unavailable',
    (WidgetTester tester) async {
      // Neither share_plus's platform channel nor the clipboard channel has
      // a real implementation under flutter_test — an unmocked channel just
      // hangs forever (never resolves) rather than throwing, so both must be
      // mocked explicitly: the share channel to simulate "no implementation
      // available", the clipboard channel to actually record what is set.
      String? clipboardText;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (
            MethodCall call,
          ) async {
            switch (call.method) {
              case 'Clipboard.setData':
                clipboardText =
                    (call.arguments as Map<dynamic, dynamic>)['text']
                        as String?;
                return null;
              case 'Clipboard.getData':
                return <String, dynamic>{'text': clipboardText};
              default:
                return null;
            }
          });
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('dev.fluttercommunity.plus/share'),
            (MethodCall call) async {
              throw PlatformException(
                code: 'unavailable',
                message: 'no share implementation in tests',
              );
            },
          );
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('dev.fluttercommunity.plus/share'),
              null,
            );
      });

      await pumpProgression(tester, trajectory: _activeTrajectory);

      await tester.tap(find.byTooltip('Share progress snapshot'));
      await tester.pump();
      expect(find.text('Review progress snapshot'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Share'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text(
          'Share sheet unavailable. Progress snapshot copied to clipboard.',
        ),
        findsOneWidget,
      );
      expect(clipboardText, contains('ChronoSpark Progress Snapshot'));
    },
  );
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
  pendingTasks: 4,
  completedTasks: 27,
  completedToday: 3,
  level: 6,
  streak: 12,
  energy: 0.78,
  momentum: 0.66,
  adaptability: 0.71,
  lastCompletionXp: 25,
  lastCompletionQuality: 0.83,
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
  lastCompletionXp: 15,
  lastCompletionQuality: 0.7,
  pressureIndex: 20,
  behaviorDivergence: 8,
  alert: 'Momentum dipping.',
  predictionTitle: 'Streak at risk',
  predictionOutcome: 'Streak breaks within two days',
  predictionProbability: 0.62,
  predictionExplanation: 'Completion rate fell for three consecutive days.',
);
