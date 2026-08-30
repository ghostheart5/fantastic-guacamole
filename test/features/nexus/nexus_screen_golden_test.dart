import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/log_entry_entity.dart';
import 'package:fantastic_guacamole/domain/entities/memory_entity.dart';
import 'package:fantastic_guacamole/domain/entities/notification_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/features/nexus/ui/nexus_screen.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/state/models/signal_model.dart';
import 'package:fantastic_guacamole/state/models/signals_models.dart';
import 'package:fantastic_guacamole/state/models/si_pipeline_models.dart';
import 'package:fantastic_guacamole/state/models/trajectory_summary_view.dart';
import 'package:fantastic_guacamole/state/providers/timeline_provider.dart';
import 'package:fantastic_guacamole/ui/constants/app_sizes.dart';
import 'package:fantastic_guacamole/ui/constants/breakpoints.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpNexusScreen(
    WidgetTester tester, {
    required double width,
    List<Task>? tasks,
    List<TimelineEventEntity>? timeline,
  }) async {
    tester.view.physicalSize = Size(width, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final ProviderContainer container = ProviderContainer(
      retry: (int retryCount, Object error) => null,
      overrides: [
        unreadNotificationsProvider.overrideWithValue(0),
        profileProvider.overrideWith(_PopulatedProfileController.new),
        if (tasks != null) tasksProvider.overrideWith((Ref ref) async => tasks),
        if (timeline != null)
          timelineProvider.overrideWith(
            () => _StaticTimelineNotifier(timeline),
          ),
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
  }

  Text textWidgetContaining(WidgetTester tester, String text) =>
      tester.widget<Text>(
        find
            .byWidgetPredicate(
              (Widget widget) =>
                  widget is Text && (widget.data?.contains(text) ?? false),
            )
            .first,
      );

  group('NexusScreen responsive typography', () {
    testWidgets('uses ultra-compact values below 340px', (
      WidgetTester tester,
    ) async {
      await pumpNexusScreen(tester, width: Breakpoints.ultraCompact - 1);

      expect(
        textWidgetContaining(tester, 'LVL 10').style?.fontSize,
        AppSizes.fontMicro,
      );
    });

    testWidgets('uses compact values from 340px up to 389px', (
      WidgetTester tester,
    ) async {
      await pumpNexusScreen(tester, width: Breakpoints.ultraCompact);

      expect(
        textWidgetContaining(tester, 'LVL 10').style?.fontSize,
        AppSizes.fontXs,
      );
    });

    testWidgets('uses regular values at 390px and above', (
      WidgetTester tester,
    ) async {
      await pumpNexusScreen(tester, width: Breakpoints.compact);

      // At the regular breakpoint, both labels intentionally converge on the
      // same font size; this matches the production widget logic.
      expect(
        textWidgetContaining(tester, 'LVL 10').style?.fontSize,
        AppSizes.fontSm,
      );
    });

    testWidgets('scheduled time does not make a task due or overdue', (
      WidgetTester tester,
    ) async {
      final DateTime now = DateTime.now();
      await pumpNexusScreen(
        tester,
        width: Breakpoints.compact,
        tasks: <Task>[
          Task(
            id: 'scheduled-before-due',
            title: 'Work block before deadline',
            priority: 3,
            difficulty: 2,
            energyRequired: 2,
            scheduledFor: now.subtract(const Duration(hours: 2)),
            dueDate: now.add(const Duration(days: 1)),
          ),
        ],
        timeline: const <TimelineEventEntity>[],
      );

      await tester.scrollUntilVisible(find.text('Today at a glance'), 400);

      expect(find.text('Nothing is due today.'), findsOneWidget);
      expect(find.text('You’re all caught up'), findsOneWidget);
      expect(
        find.text('Review the overdue item below before taking a break.'),
        findsNothing,
      );
    });
  });
}

final NexusScreenModel _populatedNexusModel = NexusScreenModel(
  aggregation: SIStateAggregation(
    tasks: <Task>[
      Task(
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
    signals: const SignalsBundle(
      items: <Signal>[],
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
    planningEvidence: const SIPlanningEvidence(
      friction: false,
      overwhelm: false,
      streakHealth: 'High',
      goalDrift: false,
      taskAvoidance: false,
      emotion: 'engaged',
      emotionalStrain: false,
      emotionalStability: true,
      emotionalPatterns: <String>['steady'],
    ),
  ),
  decision: const SIDecisionOutput(
    nextAction: 'Lock sprint scope',
    plannerMessage: 'Stay with the current sprint attention.',
    suggestedPlanAdjustments: <String>['Hold one high-priority lane'],
    signalPrompts: <String>['What can be simplified?'],
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
    name: 'ChronoSpark User',
  );
}

class _StaticTimelineNotifier extends TimelineNotifier {
  _StaticTimelineNotifier(this.events);

  final List<TimelineEventEntity> events;

  @override
  List<TimelineEventEntity> build() => events;
}

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
