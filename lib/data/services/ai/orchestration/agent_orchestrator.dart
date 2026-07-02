import 'package:fantastic_guacamole/data/services/ai/agents/ai_agent.dart';
import 'package:fantastic_guacamole/data/services/ai/agents/chat_agent.dart';
import 'package:fantastic_guacamole/data/services/ai/agents/classification_agent.dart';
import 'package:fantastic_guacamole/data/services/ai/agents/custom_agent.dart';
import 'package:fantastic_guacamole/data/services/ai/agents/planner_agent.dart';
import 'package:fantastic_guacamole/data/services/ai/agents/recommendation_agent.dart';
import 'package:fantastic_guacamole/data/services/ai/agents/reminder_agent.dart';
import 'package:fantastic_guacamole/data/services/ai/agents/research_agent.dart';
import 'package:fantastic_guacamole/data/services/ai/agents/summarization_agent.dart';
import 'package:fantastic_guacamole/data/services/ai/models/agent_request.dart';
import 'package:fantastic_guacamole/data/services/ai/models/agent_result.dart';

enum AgentKind {
  chat,
  research,
  recommendation,
  reminder,
  planning,
  summarization,
  classification,
  custom,
}

class AgentOrchestrator {
  const AgentOrchestrator({
    this.chatAgent = const ChatAgent(),
    this.researchAgent = const ResearchAgent(),
    this.recommendationAgent = const RecommendationAgent(),
    this.reminderAgent = const ReminderAgent(),
    this.plannerAgent = const PlannerAgent(),
    this.summarizationAgent = const SummarizationAgent(),
    this.classificationAgent = const ClassificationAgent(),
    this.customAgent = const CustomAgent(),
  });

  final ChatAgent chatAgent;
  final ResearchAgent researchAgent;
  final RecommendationAgent recommendationAgent;
  final ReminderAgent reminderAgent;
  final PlannerAgent plannerAgent;
  final SummarizationAgent summarizationAgent;
  final ClassificationAgent classificationAgent;
  final CustomAgent customAgent;

  Future<AgentResult> execute({
    required String prompt,
    Map<String, dynamic> context = const <String, dynamic>{},
    AgentKind? preferredAgent,
    AgentRequest? request,
  }) async {
    final Stopwatch stopwatch = Stopwatch()..start();
    final AgentRequest resolvedRequest =
        request ??
        AgentRequest(prompt: prompt, context: context, preferredAgent: preferredAgent?.name);
    final AgentKind agentKind = preferredAgent ?? _selectAgent(prompt, context);
    final Map<String, dynamic> payload = await _resolve(agentKind).execute(resolvedRequest.toMap());
    stopwatch.stop();

    return AgentResult(
      selectedAgent: agentKind.name,
      workflow: 'execute',
      payload: _normalizePayload(payload, durationMs: stopwatch.elapsedMilliseconds),
    );
  }

  AgentKind _selectAgent(String prompt, Map<String, dynamic> context) {
    final String lowered = prompt.toLowerCase();
    if (lowered.contains('remind') || lowered.contains('notify')) {
      return AgentKind.reminder;
    }
    if (lowered.contains('plan') || lowered.contains('schedule')) {
      return AgentKind.planning;
    }
    if (lowered.contains('research') ||
        lowered.contains('find out') ||
        lowered.contains('lookup')) {
      return AgentKind.research;
    }
    if (lowered.contains('summarize') || lowered.contains('summary')) {
      return AgentKind.summarization;
    }
    if (lowered.contains('classify') || lowered.contains('label') || lowered.contains('intent')) {
      return AgentKind.classification;
    }
    if (lowered.contains('recommend') || lowered.contains('suggest') || lowered.contains('best')) {
      return AgentKind.recommendation;
    }
    if (lowered.contains('custom')) {
      return AgentKind.custom;
    }
    if (context['mode']?.toString() == 'planning') {
      return AgentKind.planning;
    }
    return AgentKind.chat;
  }

  AiAgent _resolve(AgentKind agentKind) {
    switch (agentKind) {
      case AgentKind.chat:
        return chatAgent;
      case AgentKind.research:
        return researchAgent;
      case AgentKind.recommendation:
        return recommendationAgent;
      case AgentKind.reminder:
        return reminderAgent;
      case AgentKind.planning:
        return plannerAgent;
      case AgentKind.summarization:
        return summarizationAgent;
      case AgentKind.classification:
        return classificationAgent;
      case AgentKind.custom:
        return customAgent;
    }
  }

  Map<String, dynamic> _normalizePayload(Map<String, dynamic> payload, {required int durationMs}) {
    final Map<String, dynamic> normalized = Map<String, dynamic>.from(payload);
    normalized['message'] ??= normalized['response'] ?? normalized['summary'] ?? '';
    normalized['reasoning'] ??= normalized['message'];
    normalized['emotion'] ??= 'balanced';
    normalized['confidence'] ??= 0.5;
    normalized['durationMs'] = durationMs;
    return normalized;
  }
}
