import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/log_entry_entity.dart';
import 'package:fantastic_guacamole/domain/entities/memory_entity.dart';
import 'package:fantastic_guacamole/domain/entities/note_entity.dart';
import 'package:fantastic_guacamole/domain/entities/notification_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/features/nexus/ui/nexus_screen.dart';
import 'package:fantastic_guacamole/features/timeline/ui/timeline_screen.dart';
import 'package:fantastic_guacamole/state/controllers/profile_controller.dart';
import 'package:fantastic_guacamole/state/models/signal_model.dart';
import 'package:fantastic_guacamole/state/models/signals_models.dart';
import 'package:fantastic_guacamole/state/models/si_pipeline_models.dart';
import 'package:fantastic_guacamole/state/models/trajectory_summary_view.dart';
import 'package:fantastic_guacamole/state/providers/goals_provider.dart';
import 'package:fantastic_guacamole/state/providers/notification_provider.dart';
import 'package:fantastic_guacamole/state/providers/notes_provider.dart';
import 'package:fantastic_guacamole/state/providers/si_pipeline_provider.dart';
import 'package:fantastic_guacamole/state/providers/task_provider.dart';
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

  testWidgets('TimelineScreen projects due-date tasks with actions', (
    WidgetTester tester,
  ) async {
    final DateTime now = DateTime.now();
    final ProviderContainer container = ProviderContainer(
      overrides: [
        timelineProvider.overrideWith(_EmptyTimelineNotifier.new),
        goalsProvider.overrideWith(_StaticGoalsNotifier.new),
        tasksProvider.overrideWith((ref) async {
          return <Task>[
            Task(
              id: 'task-due-only',
              title: 'Due-date only task',
              priority: 3,
              difficulty: 2,
              energyRequired: 2,
              dueDate: DateTime(now.year, now.month, now.day, 12),
            ),
          ];
        }),
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
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.bySemanticsLabel('Back to Nexus'), findsOneWidget);
    expect(find.text('Due-date only task'), findsOneWidget);
    expect(find.text('Complete'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
  });

  testWidgets('NexusScreen renders with a supplied screen model', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        nexusScreenModelProvider.overrideWith((Ref ref) async => _nexusModel),
        unreadNotificationsProvider.overrideWithValue(0),
        goalsProvider.overrideWith(_StaticGoalsNotifier.new),
        tasksProvider.overrideWith(
          (Ref ref) async => _nexusModel.aggregation.tasks,
        ),
        notesProvider.overrideWith(_StaticNotesNotifier.new),
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

class _StaticNotesNotifier extends NotesNotifier {
  @override
  Future<List<NoteEntity>> build() async => const <NoteEntity>[];
}

class _StaticTimelineNotifier extends TimelineNotifier {
  @override
  List<TimelineEventEntity> build() => <TimelineEventEntity>[
    TimelineEventEntity(
      id: 'timeline-1',
      type: TimelineEventType.goalComplete,
      title: 'Completed sprint review',
      detail: 'Closed the review loop for the weekly plan.',
      // Keep the fixture in the current week even when CI runs shortly after
      // the Monday boundary.
      timestamp: DateTime.now(),
    ),
  ];
}

class _EmptyTimelineNotifier extends TimelineNotifier {
  @override
  List<TimelineEventEntity> build() => const <TimelineEventEntity>[];
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
    profile: _StaticProfileController().build(),
    siState: const SIState(energy: 0.78, fatigue: 0.24, completedToday: 4),
    trajectory: _trajectory,
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
