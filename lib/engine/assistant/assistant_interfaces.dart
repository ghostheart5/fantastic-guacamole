import 'package:fantastic_guacamole/engine/assistant/assistant_models.dart';
import 'package:fantastic_guacamole/engine/assistant/assistant_memory_models.dart';
import 'package:fantastic_guacamole/domain/entities/assistant_conversation_scope.dart';
import 'package:fantastic_guacamole/domain/entities/emotional_state.dart';
import 'package:fantastic_guacamole/domain/ports/i_assistant_context_builder.dart';
import 'package:fantastic_guacamole/engine/si/models/si_state.dart'
    as si_models;
import 'package:fantastic_guacamole/engine/si/si_cognitive_ecosystem_layer.dart';
import 'package:fantastic_guacamole/engine/si/si_cognitive_evolution_timeline.dart';
import 'package:fantastic_guacamole/engine/si/si_cognitive_micro_pattern_engine.dart';

abstract class AssistantIntentDetector {
  AssistantIntent detect({
    required String input,
    required AssistantSurface surface,
  });
}

abstract class AssistantContextBuilder implements IAssistantContextBuilder {
  AssistantContext buildSmartPlannerContext({
    required String input,
    required AssistantIntent intent,
    required double energy,
    required String emotion,
    required List<String> memorySummaries,
    required List<String> timelineSummaries,
    required List<String> goalSummaries,
  });

  @override
  AssistantContext buildSIConsoleContext({
    required String input,
    required AssistantIntent intent,
    required List<String> matchedSurfaces,
    required List<String> memorySummaries,
    required List<String> timelineSummaries,
    required int taskCount,
    required int goalCount,
  });
}

abstract class AssistantMemoryInterface {
  List<AssistantMemorySnapshot> recentSnapshots({int limit = 24});
  void capture(AssistantMemorySnapshot snapshot);
  void clear();
}

abstract class AssistantTimelineEngine {
  EvolutionTimelineUpdate track({
    required EvolutionTimeline current,
    required si_models.SIMemoryStore memory,
    required si_models.SIContext context,
    MicroPatternReport? patterns,
    SIEcosystemState? ecosystem,
    si_models.SIDecision? decision,
    DateTime? now,
  });
}

abstract class RecommendationEngine {
  Future<Map<String, dynamic>> execute(Map<String, dynamic> request);
}

abstract class SmartPlannerInterface<TResult extends Object> {
  Future<TResult> requestPlanningGuidance({
    required double? energy,
    required EmotionalState? emotion,
    required String notes,
    required List<Map<String, String>> history,
    required String? previousSavedNotes,
  });

  Future<String> requestFollowUp({
    required String input,
    required double? energy,
    required EmotionalState? emotion,
    required String reflection,
    required List<Map<String, String>> history,
  });
}

abstract class SIConsoleInterface<TResult extends Object> {
  Future<TResult?> sendMessage(String text);
  Future<TResult?> executeConsoleQuery({
    required String input,
    List<Map<String, String>> history,
    Map<String, dynamic> context,
  });
}
