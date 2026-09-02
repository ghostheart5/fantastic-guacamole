import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/log_entry_entity.dart';
import 'package:fantastic_guacamole/domain/entities/memory_entity.dart';
import 'package:fantastic_guacamole/domain/entities/note_entity.dart';
import 'package:fantastic_guacamole/domain/entities/notification_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/domain/operating_system/operating_system_contract.dart';
import 'package:fantastic_guacamole/domain/predictive/predictive_planning_contract.dart';
import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/features/nexus/domain/nexus_decision_model.dart';
import 'package:fantastic_guacamole/features/nexus/ui/nexus_screen.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/state/models/signal_model.dart';
import 'package:fantastic_guacamole/state/models/signals_models.dart';
import 'package:fantastic_guacamole/state/models/si_pipeline_models.dart';
import 'package:fantastic_guacamole/state/models/trajectory_summary_view.dart';
import 'package:fantastic_guacamole/state/providers/notes_provider.dart';
import 'package:fantastic_guacamole/state/providers/nexus_decision_provider.dart';
import 'package:fantastic_guacamole/state/providers/timeline_provider.dart';
import 'package:fantastic_guacamole/ui/constants/app_sizes.dart';
import 'package:fantastic_guacamole/ui/constants/breakpoints.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/golden_harness.dart';

void main() {
  setUpAll(loadAppFontsForGolden);
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<void> pumpNexusScreen(
    WidgetTester tester, {
    required double width,
    List<Task>? tasks,
    List<TimelineEventEntity>? timeline,
    bool observedVitals = true,
  }) async {
    tester.view.physicalSize = Size(width, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final ProviderContainer container = ProviderContainer(
      retry: (int retryCount, Object error) => null,
      overrides: [
        unreadNotificationsProvider.overrideWithValue(0),
        profileProvider.overrideWith(_PopulatedProfileController.new),
        siStateProvider.overrideWith(
          () => _TestSIStateController(observed: observedVitals),
        ),
        trajectorySummaryProvider.overrideWithValue(_activeTrajectory),
        goalsProvider.overrideWith(
          () => _StaticGoalsNotifier(_populatedNexusModel.aggregation.goals),
        ),
        tasksProvider.overrideWith(
          (Ref ref) async => tasks ?? _populatedNexusModel.aggregation.tasks,
        ),
        notesProvider.overrideWith(
          () => _StaticNotesNotifier(const <NoteEntity>[]),
        ),
        if (timeline != null)
          timelineProvider.overrideWith(
            () => _StaticTimelineNotifier(timeline),
          ),
        nexusScreenModelProvider.overrideWith(
          (Ref ref) async => _populatedNexusModel,
        ),
        nexusDecisionProvider.overrideWithValue(_readyNexusDecisionModel),
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

  Future<void> pumpNexusGolden(
    WidgetTester tester, {
    required double width,
  }) async {
    final ProviderContainer container = ProviderContainer(
      retry: (int retryCount, Object error) => null,
      overrides: [
        unreadNotificationsProvider.overrideWithValue(0),
        profileProvider.overrideWith(_PopulatedProfileController.new),
        siStateProvider.overrideWith(
          () => _TestSIStateController(observed: true),
        ),
        trajectorySummaryProvider.overrideWithValue(_activeTrajectory),
        goalsProvider.overrideWith(
          () => _StaticGoalsNotifier(_populatedNexusModel.aggregation.goals),
        ),
        tasksProvider.overrideWith(
          (Ref ref) async => _populatedNexusModel.aggregation.tasks,
        ),
        notesProvider.overrideWith(
          () => _StaticNotesNotifier(const <NoteEntity>[]),
        ),
        nexusScreenModelProvider.overrideWith(
          (Ref ref) async => _populatedNexusModel,
        ),
        nexusDecisionProvider.overrideWithValue(_readyNexusDecisionModel),
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

  group('NexusScreen golden regression', () {
    testWidgets('matches the ultraCompact_320 baseline', (
      WidgetTester tester,
    ) async {
      await pumpNexusGolden(tester, width: 320);
      await expectLater(
        find.byType(NexusScreen),
        matchesGoldenFile(
          platformGoldenFile('nexus_screen_ultraCompact_320.png'),
        ),
      );
    });

    testWidgets('matches the compact_375 baseline', (
      WidgetTester tester,
    ) async {
      await pumpNexusGolden(tester, width: 375);
      await expectLater(
        find.byType(NexusScreen),
        matchesGoldenFile(platformGoldenFile('nexus_screen_compact_375.png')),
      );
    });

    testWidgets('matches the regular_500 baseline', (
      WidgetTester tester,
    ) async {
      await pumpNexusGolden(tester, width: 500);
      await expectLater(
        find.byType(NexusScreen),
        matchesGoldenFile(platformGoldenFile('nexus_screen_regular_500.png')),
      );
    });
  });

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

    testWidgets('seeded vitals are not presented as personal measurements', (
      WidgetTester tester,
    ) async {
      await pumpNexusScreen(
        tester,
        width: Breakpoints.compact,
        observedVitals: false,
      );

      expect(find.text('UNMEASURED'), findsOneWidget);
      expect(find.text('NOT CHECKED'), findsOneWidget);
      expect(find.text('78%'), findsNothing);
    });
  });
}

final DateTime _decisionObservedAt = DateTime.utc(2026, 9, 2, 12);
final DateTime _decisionFreshUntil = DateTime.utc(2100);

final OperatingSnapshot _operatingSnapshot = OperatingSnapshot(
  accountScope: 'v2.golden',
  observedAt: _decisionObservedAt,
  sourceRevisions: const <String, String>{'tasks': 'golden-1'},
  activeGoalCount: 1,
  actionableCount: 1,
  overdueCount: 0,
  completedToday: 1,
  energy: .78,
  fatigue: .24,
  momentum: 50,
  pressure: 10,
  topActionId: 'task-1',
  topActionLabel: 'Finish quarterly review',
  activeRisks: const <String>[],
  evidenceCoverage: 1,
);

final OperatingDecisionReceipt _operatingDecision = OperatingDecisionReceipt(
  subjectId: 'task-1',
  recommendedAction: 'Finish quarterly review',
  rationale: 'It is the highest-priority grounded task.',
  whyItMatters: 'It protects the active launch goal.',
  consequenceOfDelay: 'The launch review remains incomplete.',
  generatedAt: _decisionObservedAt,
  expiresAt: _decisionFreshUntil,
  confidence: OperatingConfidence.high,
  recommendationConfidence: .82,
  evidence: <OperatingEvidence>[
    OperatingEvidence(
      code: 'task.priority',
      description: 'The task is Priority 3 in the active launch goal.',
      kind: OperatingEvidenceKind.observed,
      recordedAt: _decisionObservedAt,
      source: 'task_repository',
      subjectId: 'task-1',
      freshUntil: _decisionFreshUntil,
      weight: .82,
    ),
  ],
  actionIntent: const OperatingActionIntent(
    id: 'golden-action-1',
    type: OperatingActionType.openTimeline,
    label: 'Review on Timeline',
    destination: '/timeline',
    targetEntityId: 'task-1',
  ),
  sourceRevisions: const <String, String>{'tasks': 'golden-1'},
  modelVersion: 'golden-v1',
);

final NexusDecisionModel _readyNexusDecisionModel = NexusDecisionModel(
  status: NexusDecisionStatus.ready,
  isOnline: true,
  pendingSyncCount: 0,
  intelligence: DecisionIntelligence(
    snapshot: _operatingSnapshot,
    delta: const OperatingDeltaEngine().compare(
      previous: null,
      current: _operatingSnapshot,
      comparedAt: _decisionObservedAt,
    ),
    decision: _operatingDecision,
    acknowledgedSnapshotId: null,
  ),
  topRisk: 'No active risk is supported by current evidence.',
  recentProgress: 'One task was completed in the current evidence window.',
  statusDetail: 'The local planning summary is ready.',
);

class _StaticGoalsNotifier extends GoalsNotifier {
  _StaticGoalsNotifier(this.goals);

  final List<GoalEntity> goals;

  @override
  List<GoalEntity> build() => goals;
}

class _StaticNotesNotifier extends NotesNotifier {
  _StaticNotesNotifier(this.notes);

  final List<NoteEntity> notes;

  @override
  Future<List<NoteEntity>> build() async => notes;
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

class _TestSIStateController extends SIStateController {
  _TestSIStateController({required this.observed});

  final bool observed;

  @override
  SIState build() => SIState(
    energy: .78,
    fatigue: .24,
    completedToday: 4,
    energyOrigin: observed
        ? PredictiveEvidenceOrigin.observed
        : PredictiveEvidenceOrigin.estimated,
    fatigueOrigin: observed
        ? PredictiveEvidenceOrigin.observed
        : PredictiveEvidenceOrigin.estimated,
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
