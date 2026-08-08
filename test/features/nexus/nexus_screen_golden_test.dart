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
import 'package:fantastic_guacamole/state/models/soul_map_models.dart';
import 'package:fantastic_guacamole/state/models/trajectory_summary_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/golden_harness.dart';

/// Pixel regression coverage for Phase 6's M-1 font/breakpoint migration.
/// These are generated against the CURRENT (pre-migration) screen first —
/// see the Phase 6 plan for why the sequencing matters — then re-run
/// unchanged after the migration to prove it was value-preserving.
void main() {
  setUpAll(loadAppFontsForGolden);
  setUpAll(useTolerantGoldenComparator);

  for (final (String label, double width) in <(String, double)>[
    ('ultraCompact_320', 320),
    ('compact_375', 375),
    ('regular_500', 500),
  ]) {
    testWidgets('NexusScreen at $label matches golden', (
      WidgetTester tester,
    ) async {
      final ProviderContainer container = ProviderContainer(
        // FutureProviders retry a thrown error with backoff by default
        // (ProviderContainer.defaultRetry); a scheduled retry timer can
        // outlive the test frame and fail teardown. Golden capture doesn't
        // exercise error paths, so disabling retry is safe here — matching
        // nexus_navigation_test.dart's "dependency mesh" test.
        retry: (int retryCount, Object error) => null,
        overrides: [
          unreadNotificationsProvider.overrideWithValue(0),
          profileProvider.overrideWith(_PopulatedProfileController.new),
          nexusScreenModelProvider.overrideWith(
            (Ref ref) async => _populatedNexusModel,
          ),
        ],
      );
      addTearDown(container.dispose);

      await pumpForGolden(
        tester,
        UncontrolledProviderScope(
          container: container,
          child: const NexusScreen(),
        ),
        size: Size(width, 2400),
      );
      await tester.pump(const Duration(milliseconds: 50));

      await expectLater(
        find.byType(NexusScreen),
        matchesGoldenFile('goldens/nexus_screen_$label.png'),
      );
    });
  }
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
    soulMap: const SoulMapAlignment(
      scores: <SoulMapDimension, SoulMapDimensionScore>{},
      overall: 72,
      strongest: SoulMapDimension.purpose,
      weakest: SoulMapDimension.growthJourney,
      recommendations: <String>[],
    ),
  ),
  decision: const SIDecisionOutput(
    nextAction: 'Lock sprint scope',
    coachMessage: 'Stay with the current sprint focus.',
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
