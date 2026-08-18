import 'package:fantastic_guacamole/domain/entities/habit_record.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/log_entry_entity.dart';
import 'package:fantastic_guacamole/domain/entities/memory_entity.dart';
import 'package:fantastic_guacamole/domain/entities/notification_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/domain/entities/learning_entity.dart';
import 'package:fantastic_guacamole/domain/entities/si_state_entity.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/domain/planning/planner_input.dart';
import 'package:fantastic_guacamole/engine/decision/decision_engine.dart';
import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/state/controllers/profile_controller.dart';
import 'package:fantastic_guacamole/state/models/core_values_models.dart';
import 'package:fantastic_guacamole/state/models/insights_models.dart';
import 'package:fantastic_guacamole/state/models/personal_alignment_models.dart';
import 'package:fantastic_guacamole/state/models/trajectory_summary_view.dart';

class SISignalExtraction {
  const SISignalExtraction({
    required this.friction,
    required this.overwhelm,
    required this.streakHealth,
    required this.goalDrift,
    required this.taskAvoidance,
    required this.emotion,
    required this.emotionalStrain,
    required this.emotionalStability,
    required this.emotionalPatterns,
    this.executionCompletedToday = 0,
    this.executionSkippedToday = 0,
    this.executionDelayedToday = 0,
  });

  final bool friction;
  final bool overwhelm;
  final String streakHealth;
  final bool goalDrift;
  final bool taskAvoidance;
  final String emotion;
  final bool emotionalStrain;
  final bool emotionalStability;
  final List<String> emotionalPatterns;
  final int executionCompletedToday;
  final int executionSkippedToday;
  final int executionDelayedToday;
}

enum SISourceStatus { ready, empty, loading, error, unavailable }

class SISourceHealth {
  const SISourceHealth({
    required this.tasks,
    required this.goals,
    required this.memories,
    required this.observedAt,
  });

  final SISourceStatus tasks;
  final SISourceStatus goals;
  final SISourceStatus memories;
  final DateTime observedAt;

  double get readyFraction {
    final List<SISourceStatus> sources = <SISourceStatus>[
      tasks,
      goals,
      memories,
    ];
    return sources
            .where((SISourceStatus status) => status == SISourceStatus.ready)
            .length /
        sources.length;
  }
}

class SIStateAggregation {
  SIStateAggregation({
    required this.tasks,
    required this.goals,
    required this.insights,
    required this.logs,
    required this.timeline,
    required this.memories,
    required this.notifications,
    required this.planPreview,
    required this.profile,
    required this.siState,
    required this.trajectory,
    required this.signals,
    required this.coreValues,
    required this.personalAlignment,
    DecisionRecommendation? planningDecision,
    SISourceHealth? sourceHealth,
    this.habits = const <HabitRecord>[],
  }) : planningDecision =
           planningDecision ?? _fallbackPlanningDecision(tasks, siState),
       sourceHealth =
           sourceHealth ??
           SISourceHealth(
             tasks: tasks.isEmpty ? SISourceStatus.empty : SISourceStatus.ready,
             goals: goals.isEmpty ? SISourceStatus.empty : SISourceStatus.ready,
             memories: memories.isEmpty
                 ? SISourceStatus.empty
                 : SISourceStatus.ready,
             observedAt: DateTime.now(),
           );

  final List<Task> tasks;
  final List<GoalEntity> goals;
  final InsightsBundle insights;
  final List<LogEntryEntity> logs;
  final List<TimelineEventEntity> timeline;
  final List<MemoryEntity> memories;
  final List<NotificationEntity> notifications;
  final List<String> planPreview;
  final ProfileState profile;
  final SIState siState;
  final TrajectorySummaryView trajectory;
  final SISignalExtraction signals;
  final CoreValuesAlignment coreValues;
  final PersonalAlignmentAlignment personalAlignment;
  final DecisionRecommendation planningDecision;
  final SISourceHealth sourceHealth;

  /// Habits available to Smart Planner and SI. Empty when habit storage has not
  /// resolved yet, so aggregation never blocks on it.
  final List<HabitRecord> habits;

  int get activeHabitCount =>
      habits.where((HabitRecord habit) => habit.active).length;

  static DecisionRecommendation _fallbackPlanningDecision(
    List<Task> tasks,
    SIState siState,
  ) => const DecisionEngine().recommend(
    inputs: PlannerInputAdapter.fromLegacyTasks(tasks),
    state: SiStateEntity(
      energy: siState.energy,
      focus: 1 - siState.fatigue,
      fatigue: siState.fatigue,
      lastUpdated: null,
    ),
    learning: const LearningEntity(),
  );
}

class SIDecisionOutput {
  const SIDecisionOutput({
    required this.nextAction,
    required this.plannerMessage,
    required this.suggestedPlanAdjustments,
    required this.insightPrompts,
    required this.progressionFeedback,
    required this.warnings,
  });

  final String nextAction;
  final String plannerMessage;
  final List<String> suggestedPlanAdjustments;
  final List<String> insightPrompts;
  final String progressionFeedback;
  final List<String> warnings;
}

class SmartPlannerScreenModel {
  const SmartPlannerScreenModel({
    required this.aggregation,
    required this.decision,
  });

  final SIStateAggregation aggregation;
  final SIDecisionOutput decision;
}

class NexusScreenModel {
  const NexusScreenModel({required this.aggregation, required this.decision});

  final SIStateAggregation aggregation;
  final SIDecisionOutput decision;
}

class SIConsoleScreenModel {
  const SIConsoleScreenModel({
    required this.aggregation,
    required this.decision,
    required this.engineSnapshot,
  });

  final SIStateAggregation aggregation;
  final SIDecisionOutput decision;
  final String engineSnapshot;
}
