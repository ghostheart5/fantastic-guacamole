import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/log_entry_entity.dart';
import 'package:fantastic_guacamole/domain/entities/memory_entity.dart';
import 'package:fantastic_guacamole/domain/entities/notification_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/engine/si/si_synthetic_soul_layer.dart';
import 'package:fantastic_guacamole/features/memories/ui/memories_screen.dart';
import 'package:fantastic_guacamole/features/nexus/ui/nexus_screen.dart';
import 'package:fantastic_guacamole/features/personal_alignment/ui/personal_alignment_screen.dart';
import 'package:fantastic_guacamole/features/timeline/ui/timeline_screen.dart';
import 'package:fantastic_guacamole/state/controllers/profile_controller.dart';
import 'package:fantastic_guacamole/state/models/core_values_models.dart';
import 'package:fantastic_guacamole/state/models/insight_model.dart';
import 'package:fantastic_guacamole/state/models/insights_models.dart';
import 'package:fantastic_guacamole/state/models/si_pipeline_models.dart';
import 'package:fantastic_guacamole/state/models/personal_alignment_models.dart';
import 'package:fantastic_guacamole/state/models/trajectory_summary_view.dart';
import 'package:fantastic_guacamole/state/providers/feature_derived_providers.dart';
import 'package:fantastic_guacamole/state/providers/goals_provider.dart';
import 'package:fantastic_guacamole/state/providers/memories_provider.dart';
import 'package:fantastic_guacamole/state/providers/notification_provider.dart';
import 'package:fantastic_guacamole/state/providers/si_pipeline_provider.dart';
import 'package:fantastic_guacamole/state/providers/timeline_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('TimelineScreen renders grouped events', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        timelineProvider.overrideWith(_StaticTimelineNotifier.new),
        goalsProvider.overrideWith(_StaticGoalsNotifier.new),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: TimelineScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('TIMELINE'), findsOneWidget);
    expect(find.text('Completed sprint review'), findsOneWidget);
  });

  testWidgets('MemoriesScreen renders starred memories first', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = ProviderContainer(
      overrides: [memoriesProvider.overrideWith(_StaticMemoriesNotifier.new)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: MemoriesScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('MEMORIES'), findsOneWidget);
    expect(find.text('Saved the best insight from today'), findsOneWidget);
  });

  testWidgets('PersonalAlignmentScreen renders strongest dimensions summary', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        goalsProvider.overrideWith(_StaticGoalsNotifier.new),
        soulStateProvider.overrideWithValue(
          const SoulState(
            continuity: 0.88,
            identityStrength: 0.81,
            emotionalEvolution: 0.44,
            personalityGrowth: 0.52,
            narrativePresence: 0.77,
            userConnection: 0.63,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: PersonalAlignmentScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('PERSONAL ALIGNMENT'), findsOneWidget);
    expect(find.text('PERSONAL ALIGNMENT ANALYSIS'), findsOneWidget);
  });

  testWidgets('NexusScreen renders with a supplied screen model', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        nexusScreenModelProvider.overrideWith((Ref ref) async => _nexusModel),
        unreadNotificationsProvider.overrideWithValue(0),
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

    expect(find.text('NEXUS'), findsOneWidget);
    expect(find.text('ADAPTIVE LOGIC CORE'), findsOneWidget);
  });
}

class _StaticGoalsNotifier extends GoalsNotifier {
  @override
  List<GoalEntity> build() => const <GoalEntity>[];
}

class _StaticTimelineNotifier extends TimelineNotifier {
  @override
  List<TimelineEventEntity> build() => <TimelineEventEntity>[
    TimelineEventEntity(
      id: 'timeline-1',
      type: TimelineEventType.goalComplete,
      title: 'Completed sprint review',
      detail: 'Closed the review loop for the weekly plan.',
      // Must be relative to now: TimelineScreen defaults to the "week" window,
      // so a hardcoded date silently stops matching once it ages out and the
      // test fails for a reason that has nothing to do with the screen.
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
    ),
  ];
}

class _StaticMemoriesNotifier extends MemoriesNotifier {
  @override
  List<MemoryEntity> build() => <MemoryEntity>[
    MemoryEntity(
      id: 'memory-1',
      text: 'Saved the best insight from today',
      date: DateTime.utc(2026, 7, 7),
      starred: true,
    ),
    MemoryEntity(
      id: 'memory-2',
      text: 'Reviewed the daily reflection prompt',
      date: DateTime.utc(2026, 7, 6),
    ),
  ];
}

class _StaticProfileController extends ProfileController {
  @override
  ProfileState build() => ProfileState(
    xp: 460,
    level: 10,
    streak: 21,
    longestStreak: 21,
    name: 'ChronoSpark User',
  );
}

const TrajectorySummaryView _trajectory = TrajectorySummaryView(
  pendingTasks: 3,
  completedTasks: 12,
  completedToday: 4,
  level: 10,
  streak: 21,
  energy: 0.78,
  momentum: 0.82,
  adaptability: 0.71,
  lastCompletionXp: 25,
  lastCompletionQuality: 0.83,
  pressureIndex: 28,
  behaviorDivergence: 12,
  alert: 'SI STATUS: current load signal is low.',
  predictionTitle: null,
  predictionOutcome: null,
  predictionProbability: null,
  predictionExplanation: null,
);

final NexusScreenModel _nexusModel = NexusScreenModel(
  aggregation: SIStateAggregation(
    tasks: const <Task>[],
    goals: const <GoalEntity>[],
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
    profile: _StaticProfileController().build(),
    siState: const SIState(energy: 0.78, fatigue: 0.24, completedToday: 4),
    trajectory: _trajectory,
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
