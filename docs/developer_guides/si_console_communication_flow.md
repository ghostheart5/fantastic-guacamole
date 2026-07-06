<style>
a {
    text-decoration: none;
    color: #464feb;
}
tr th, tr td {
    border: 1px solid #e6e6e6;
}
tr th {
    background-color: #f5f5f5;
}
</style>

## Correct communication flow

Use this exact flow for `si_console_screen.dart`:
1. User types message
2. si_console_screen.dart calls aiController.sendMessage(text)
3. ai_controller.dart creates AgentRequest
4. agent_orchestrator.dart routes to the right agent/tool
5. chat_agent.dart / planner_agent.dart / recommendation_agent.dart handles the conversational role
6. tools classify/prepare intent and context
7. si_engine_repository.dart calls engine/si facade
8. si_engine_service.dart calls internal SI modules
9. output is validated, ranked, deduped, and converted to UI state
10. ai_controller.dart stores response + memory update
11. si_console_screen.dart renders response

## Unified chatbot layer

AI UI shell:
- features/si_console/ui/si_console_screen.dart

State/controller shell:
- state/controllers/ai_controller.dart
- state/controllers/si_state_controller.dart
- state/providers/intelligence_provider.dart
- state/providers/si_memory_provider.dart

Agent layer:
- data/services/ai/orchestration/agent_orchestrator.dart
- data/services/ai/agents/*
- data/services/ai/tools/*

SI engine bridge:
- data/repositories/si_engine_repository.dart

SI engine facade:
- engine/si/si_engine_service.dart
- engine/si/si_engine.dart
- engine/si/synthetic_intelligence_engine.dart
