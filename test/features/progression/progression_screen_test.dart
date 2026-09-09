import 'dart:async';

import 'package:fantastic_guacamole/core/storage/account_storage_namespace.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/features/progression/ui/progression_screen.dart';
import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/domain/entities/log_entry_entity.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/state/models/trajectory_summary_view.dart';
import 'package:fantastic_guacamole/state/providers/advisor_provider.dart';
import 'package:fantastic_guacamole/state/providers/timeline_provider.dart';
import 'package:fantastic_guacamole/state/state/logs_state.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
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
    Size physicalSize = const Size(1200, 4000),
    FutureOr<String> Function(Ref ref)? weeklySummaryOverride,
    FutureOr<ProgressionReview> Function(Ref ref)? reviewOverride,
    FutureOr<List<Task>> Function(Ref ref)? tasksOverride,
    List<TimelineEventEntity>? timelineOverdue,
    List<LearningHistorySnapshot>? learningHistorySnapshots,
    List<LogEntryEntity> savedLogs = const [],
  }) async {
    tester.platformDispatcher.views.first
      ..physicalSize = physicalSize
      ..devicePixelRatio = 1.0;
    addTearDown(() {
      tester.platformDispatcher.views.first
        ..resetPhysicalSize()
        ..resetDevicePixelRatio();
    });

    final ProviderContainer container = ProviderContainer(
      overrides: [
        accountStorageScopeProvider.overrideWithValue(
          AccountStorageScope.authenticated('progression-test-account'),
        ),
        accountLegacyOwnershipProvider.overrideWithValue(
          LegacyScopeOwnership.provenNotOwned,
        ),
        trajectorySummaryProvider.overrideWithValue(trajectory),
        logsProvider.overrideWith(() => _SavedLogs(savedLogs)),
        progressionReviewProvider.overrideWith(
          reviewOverride ??
              (Ref ref) async => ProgressionReview(
                await (weeklySummaryOverride ??
                    (Ref ref) async => _summaryText)(ref),
              ),
        ),
        if (tasksOverride != null) tasksProvider.overrideWith(tasksOverride),
        if (timelineOverdue != null)
          timelineOverdueProvider.overrideWithValue(timelineOverdue),
        if (learningHistorySnapshots != null)
          learningHistorySnapshotsProvider.overrideWithValue(
            learningHistorySnapshots,
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
    return container;
  }

  testWidgets('renders for a brand-new account with zeroed progress', (
    WidgetTester tester,
  ) async {
    await pumpProgression(tester, trajectory: _emptyTrajectory);

    expect(find.text('PROGRESSION'), findsOneWidget);
    expect(find.text('Not enough evidence'), findsOneWidget);
    expect(find.text('Not enough history'), findsOneWidget);
    expect(find.text('Off Track'), findsNothing);
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

  testWidgets('saved completion survives empty session history after restart', (
    WidgetTester tester,
  ) async {
    await pumpProgression(
      tester,
      trajectory: _emptyTrajectory,
      learningHistorySnapshots: const [],
      savedLogs: [
        LogEntryEntity(
          id: 'persisted-completion',
          source: 'task_completed',
          message: 'Completed the installation test',
          timestamp: DateTime.now().subtract(const Duration(minutes: 1)),
        ),
      ],
    );
    expect(find.text('100% completed'), findsOneWidget);
    expect(find.text('Not enough history'), findsOneWidget);
    expect(find.text('Last 30 days • 1 completed'), findsOneWidget);
    expect(find.text('Off Track'), findsNothing);
    expect(
      find.text('Your momentum trend will appear after you complete an item.'),
      findsNothing,
    );
    expect(find.textContaining('Rebuilding the habit'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final int completionCount in <int>[1, 2]) {
    testWidgets(
      'paints a visible chart marker for $completionCount same-day completions',
      (WidgetTester tester) async {
        final DateTime now = DateTime.now();
        await pumpProgression(
          tester,
          trajectory: _emptyTrajectory,
          learningHistorySnapshots: const [],
          savedLogs: [
            for (int i = 0; i < completionCount; i++)
              LogEntryEntity(
                id: 'same-day-$i',
                source: 'task_completed',
                message: 'Saved completion',
                timestamp: DateTime(now.year, now.month, now.day),
              ),
          ],
        );

        expect(
          find.text('Last 30 days • $completionCount completed'),
          findsOneWidget,
        );
        expect(
          tester.renderObject(
            find.byKey(const ValueKey('progression_completion_chart')),
          ),
          paints..circle(color: AppColors.neonCyan),
          reason: 'One recorded day must still have a visible data marker.',
        );
      },
    );
  }

  testWidgets('fits a compact Pixel-width viewport without overflow', (
    WidgetTester tester,
  ) async {
    await pumpProgression(
      tester,
      trajectory: _activeTrajectory,
      physicalSize: const Size(412, 915),
    );

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
          accountStorageScopeProvider.overrideWithValue(
            AccountStorageScope.authenticated('progression-test-account'),
          ),
          accountLegacyOwnershipProvider.overrideWithValue(
            LegacyScopeOwnership.provenNotOwned,
          ),
          trajectorySummaryProvider.overrideWithValue(_activeTrajectory),
          progressionReviewProvider.overrideWith(
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
          'Progress review is unavailable. Your saved evidence could not be read. Retry when your data is available.',
        ),
        findsOneWidget,
      );
      expect(find.text('Retry progress review'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Open Creator'), findsNothing);
    },
  );

  testWidgets('the back arrow returns to Nexus', (WidgetTester tester) async {
    final ProviderContainer container = await pumpProgression(
      tester,
      trajectory: _activeTrajectory,
    );
    // Simulate having arrived here from somewhere other than the planner, so
    // tapping back is actually exercising a transition, not a no-op.
    container.read(appFlowProvider.notifier).toProgression();
    await tester.pump();

    final Finder backToNexus = find.bySemanticsLabel('Back to Nexus');
    expect(backToNexus, findsOneWidget);

    await tester.tap(backToNexus);
    await tester.pump();

    expect(container.read(appFlowProvider), AppView.nexus);
  });

  testWidgets(
    'unavailable review offers retry and recovers without adding work',
    (WidgetTester tester) async {
      int attempts = 0;
      await pumpProgression(
        tester,
        trajectory: _activeTrajectory,
        tasksOverride: (_) => [],
        timelineOverdue: [],
        reviewOverride: (_) async => ++attempts == 1
            ? const ProgressionReview(
                'Saved evidence is unavailable.',
                status: ProgressionReviewStatus.unavailable,
              )
            : const ProgressionReview('Recovered saved review.'),
      );
      await tester.pump();
      expect(find.text('Saved evidence is unavailable.'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Open Creator'), findsNothing);
      expect(find.text('PRESSURE'), findsNothing);
      expect(find.text('No milestones recorded yet.'), findsNothing);
      expect(
        find.text(
          'Saved continuity evidence is unavailable. Retry the progress review below.',
        ),
        findsOneWidget,
      );
      final retry = find.text('Retry progress review');
      await tester.ensureVisible(retry);
      await tester.tap(retry);
      await tester.pump();
      await tester.pump();
      expect(attempts, 2);
      expect(find.text('Recovered saved review.'), findsOneWidget);
      expect(find.text('Retry progress review'), findsNothing);
      expect(find.text('PRESSURE'), findsOneWidget);
    },
  );

  for (final status in <ProgressionReviewStatus>[
    ProgressionReviewStatus.loading,
    ProgressionReviewStatus.empty,
  ]) {
    testWidgets('$status does not display fallback continuity ratings', (
      tester,
    ) async {
      await pumpProgression(
        tester,
        trajectory: _emptyTrajectory,
        tasksOverride: (_) => [],
        timelineOverdue: [],
        reviewOverride: (_) =>
            ProgressionReview('Unrated review', status: status),
      );
      await tester.pump();
      expect(find.text('PRESSURE'), findsNothing);
      expect(find.text('No milestones recorded yet.'), findsNothing);
      expect(
        find.byKey(const Key('progression-continuity-availability')),
        findsOneWidget,
      );
      if (status == ProgressionReviewStatus.empty) {
        expect(
          find.widgetWithText(FilledButton, 'Open Creator'),
          findsOneWidget,
        );
      } else {
        expect(find.widgetWithText(FilledButton, 'Open Creator'), findsNothing);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the advisor action opens Creator when no work exists', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = await pumpProgression(
      tester,
      trajectory: _emptyTrajectory,
      weeklySummaryOverride: (Ref ref) async => _summaryText,
      tasksOverride: (Ref ref) async => const <Task>[],
      timelineOverdue: const <TimelineEventEntity>[],
    );
    await tester.pump();

    await tester.tap(find.widgetWithText(FilledButton, 'Open Creator'));
    await tester.pump();

    expect(container.read(appFlowProvider), AppView.creator);
  });

  testWidgets('the advisor action opens Timeline when active work exists', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = await pumpProgression(
      tester,
      trajectory: _activeTrajectory,
      weeklySummaryOverride: (Ref ref) async => _summaryText,
      tasksOverride: (Ref ref) async => <Task>[
        Task(
          id: 'task-1',
          title: 'Finish the active thing',
          priority: 2,
          difficulty: 2,
          energyRequired: 2,
        ),
      ],
      timelineOverdue: const <TimelineEventEntity>[],
    );
    await tester.pump();

    await tester.tap(find.widgetWithText(FilledButton, 'Open Timeline'));
    await tester.pump();

    expect(container.read(appFlowProvider), AppView.timeline);
  });

  testWidgets(
    'the progress chart reports completion momentum, not estimated XP',
    (WidgetTester tester) async {
      final DateTime now = DateTime.now();
      await pumpProgression(
        tester,
        trajectory: _activeTrajectory,
        savedLogs: [
          for (int i = 0; i < 5; i++)
            LogEntryEntity(
              id: 'saved-$i',
              source: i == 0
                  ? 'completed_task'
                  : i == 1
                  ? 'goal_completed'
                  : 'task_completed',
              message: 'Saved completion',
              timestamp: now.subtract(Duration(days: i < 2 ? 2 : 1)),
            ),
        ],
      );

      expect(find.text('COMPLETION MOMENTUM'), findsOneWidget);
      expect(find.text('XP PROGRESSION'), findsNothing);
      expect(find.text('Last 30 days • 5 completed'), findsOneWidget);
    },
  );

  testWidgets(
    'recorded skips show declining follow-through, not false success',
    (WidgetTester tester) async {
      final now = DateTime.now();
      await pumpProgression(
        tester,
        trajectory: _activeTrajectory,
        savedLogs: [
          LogEntryEntity(
            id: 'previous',
            source: 'task_completed',
            message: 'Done',
            timestamp: now.subtract(const Duration(days: 8)),
          ),
          LogEntryEntity(
            id: 'current',
            source: 'task_skipped',
            message: 'Skipped',
            timestamp: now.subtract(const Duration(hours: 1)),
          ),
        ],
      );
      expect(find.text('0% completed'), findsOneWidget);
      expect(find.text('Declining'), findsOneWidget);
      expect(find.text('Last 30 days • 1 completed'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('old and future completions do not populate the current chart', (
    WidgetTester tester,
  ) async {
    final now = DateTime.now();
    await pumpProgression(
      tester,
      trajectory: _activeTrajectory,
      savedLogs: [
        LogEntryEntity(
          id: 'old',
          source: 'task_completed',
          message: 'Old',
          timestamp: now.subtract(const Duration(days: 31)),
        ),
        LogEntryEntity(
          id: 'future',
          source: 'task_completed',
          message: 'Future',
          timestamp: now.add(const Duration(days: 1)),
        ),
      ],
    );
    expect(
      find.text('No completions were recorded in the last 30 days.'),
      findsOneWidget,
    );
    expect(find.textContaining('Last 30 days •'), findsNothing);
    expect(find.text('Not enough evidence'), findsOneWidget);
    expect(tester.takeException(), isNull);
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

      await tester.tap(find.byTooltip('Share progression'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Progress snapshot'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
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

const String _summaryText =
    'SYSTEM GUIDANCE REPORT\n\nRecommendation: complete one grounded action.';

class _SavedLogs extends LogsController {
  _SavedLogs(this.entries);
  final List<LogEntryEntity> entries;
  @override
  LogsState build() => LogsState(entries: entries, isLoading: false);
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
