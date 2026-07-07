import 'package:fantastic_guacamole/domain/entities/flowmap_node.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/log_entry_entity.dart';
import 'package:fantastic_guacamole/domain/entities/memory_entity.dart';
import 'package:fantastic_guacamole/domain/entities/notification_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/state/controllers/profile_controller.dart';
import 'package:fantastic_guacamole/state/models/insights_models.dart';
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
}

class SIStateAggregation {
  const SIStateAggregation({
    required this.tasks,
    required this.goals,
    required this.insights,
    required this.flowmapNodes,
    required this.logs,
    required this.timeline,
    required this.memories,
    required this.notifications,
    required this.planPreview,
    required this.profile,
    required this.siState,
    required this.trajectory,
    required this.signals,
  });

  final List<Task> tasks;
  final List<GoalEntity> goals;
  final InsightsBundle insights;
  final List<FlowmapNode> flowmapNodes;
  final List<LogEntryEntity> logs;
  final List<TimelineEventEntity> timeline;
  final List<MemoryEntity> memories;
  final List<NotificationEntity> notifications;
  final List<String> planPreview;
  final ProfileState profile;
  final SIState siState;
  final TrajectorySummaryView trajectory;
  final SISignalExtraction signals;
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
  const SmartCoachScreenModel({required this.aggregation, required this.decision});

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
