import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/log_entry_entity.dart';
import 'package:fantastic_guacamole/domain/entities/memory_entity.dart';
import 'package:fantastic_guacamole/domain/entities/notification_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/state/controllers/profile_controller.dart';
import 'package:fantastic_guacamole/state/models/core_values_models.dart';
import 'package:fantastic_guacamole/state/models/insights_models.dart';
import 'package:fantastic_guacamole/state/models/soul_map_models.dart';
import 'package:fantastic_guacamole/state/models/trajectory_summary_view.dart';

class SISignalExtraction {
  const SISignalExtraction({
    required this.friction,
    required this.overwhelm,
    required this.streakHealth,
    required this.goalDrift,
    required this.taskAvoidance,
    required this.executionCompletedToday,
    required this.executionSkippedToday,
    required this.executionDelayedToday,
    required this.executionStability7d,
    required this.emotion,
    required this.emotionalStrain,
    required this.emotionalStability,
    required this.emotionalPatterns,
  });

  final bool friction;
  final bool overwhelm;
  final String streakHealth;
  final bool goalDrift;
  final bool taskAvoidance;
  final int executionCompletedToday;
  final int executionSkippedToday;
  final int executionDelayedToday;
  final double executionStability7d;
  final String emotion;
  final bool emotionalStrain;
  final bool emotionalStability;
  final List<String> emotionalPatterns;

  String get executionSummary {
    final int stabilityPercent = (executionStability7d * 100).round();
    return 'completed $executionCompletedToday, skipped $executionSkippedToday, delayed $executionDelayedToday today ($stabilityPercent% weekly stability)';
  }
}

enum SISourceStatus { loading, ready, empty, error }

class SISourceHealth {
  const SISourceHealth({
    required this.tasks,
    required this.goals,
    required this.insights,
    required this.memories,
    this.tasksError,
    this.goalsError,
    this.insightsError,
    this.memoriesError,
  });

  final SISourceStatus tasks;
  final SISourceStatus goals;
  final SISourceStatus insights;
  final SISourceStatus memories;

  final String? tasksError;
  final String? goalsError;
  final String? insightsError;
  final String? memoriesError;
}

class SIStateAggregation {
  const SIStateAggregation({
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
    required this.soulMap,
    required this.sourceHealth,
  });

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
  final SoulMapAlignment soulMap;
  final SISourceHealth sourceHealth;
}

class SIDecisionOutput {
  const SIDecisionOutput({
    required this.nextAction,
    required this.coachMessage,
    required this.suggestedPlanAdjustments,
    required this.insightPrompts,
    required this.progressionFeedback,
    required this.warnings,
  });

  final String nextAction;
  final String coachMessage;
  final List<String> suggestedPlanAdjustments;
  final List<String> insightPrompts;
  final String progressionFeedback;
  final List<String> warnings;
}

class SmartCoachScreenModel {
  const SmartCoachScreenModel({
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

class NexusStartupSummary {
  const NexusStartupSummary({
    required this.profile,
    required this.energy,
    required this.fatigue,
    required this.completedToday,
    required this.emotionLabel,
    required this.startupDirective,
  });

  final ProfileState profile;
  final double energy;
  final double fatigue;
  final int completedToday;
  final String emotionLabel;
  final String startupDirective;
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
