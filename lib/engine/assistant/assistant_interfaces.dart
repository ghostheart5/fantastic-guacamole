import 'package:fantastic_guacamole/engine/assistant/assistant_models.dart';
import 'package:fantastic_guacamole/engine/si/models/si_state.dart'
    as si_models;
import 'package:fantastic_guacamole/engine/si/si_cognitive_ecosystem_layer.dart';
import 'package:fantastic_guacamole/engine/si/si_cognitive_evolution_timeline.dart';
import 'package:fantastic_guacamole/engine/si/si_cognitive_micro_pattern_engine.dart';
import 'package:fantastic_guacamole/state/models/ai_recommendation.dart';
import 'package:fantastic_guacamole/state/models/si_memory_models.dart';
import 'package:fantastic_guacamole/state/state/emotional_state.dart';

abstract class AssistantIntentDetector {
  AssistantIntent detect({required String input, required String surface});
}

abstract class AssistantContextBuilder {
  Map<String, dynamic> buildSmartCoachContext({
    required String input,
    required AssistantIntent intent,
    required double energy,
    required String emotion,
    required List<String> memorySummaries,
    required List<String> timelineSummaries,
    required List<String> goalSummaries,
  });

  Map<String, dynamic> buildSIConsoleContext({
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
  List<SISnapshot> recentSnapshots({int limit = 24});
  void capture(SISnapshot snapshot);
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

abstract class SmartCoachInterface {
  Future<dynamic> requestCoaching({
    required double energy,
    required EmotionalState emotion,
    required String notes,
    required List<Map<String, String>> history,
    required String? previousSavedNotes,
  });

  Future<String> requestFollowUp({
    required String input,
    required double energy,
    required EmotionalState emotion,
    required String reflection,
    required List<Map<String, String>> history,
  });
}

abstract class SIConsoleInterface {
  Future<AIRecommendation?> sendMessage(String text);
  Future<AIRecommendation?> executeConsoleQuery({
    required String input,
    List<Map<String, String>> history,
    Map<String, dynamic> context,
  });
}
