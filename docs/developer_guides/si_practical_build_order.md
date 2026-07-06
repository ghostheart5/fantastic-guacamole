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

## Practical build order

### Step 1 - Make ai_controller.dart the chat controller

Controller methods:
- sendMessage(text)
- retryMessage(messageId)
- clearConversation()
- acceptSuggestion(actionId)
- rejectSuggestion(actionId)

### Step 2 - Make agent_orchestrator.dart the router

Intent routing:
- general chat -> chat_agent.dart
- planning -> planner_agent.dart
- task recommendation -> recommendation_agent.dart
- reminder/schedule -> reminder_agent.dart
- summary/history -> summarization_agent.dart
- research/task context -> research_agent.dart

### Step 3 - Make si_engine_service.dart the public SI facade

Outside engine/si call via facade methods:
- si_engine_service.generateResponse(...)
- si_engine_service.generateDecision(...)
- si_engine_service.updateMemory(...)
- si_engine_service.validateOutput(...)

### Step 4 - Add validation before UI output

Before rendering:
- coherence validation
- policy validation
- dedupe check
- confidence check
- grounding check against app state

### Step 5 - Persist memory carefully

Use si_memory.dart, si_snapshot.dart, si_user_state_tracker.dart, and si_memory_provider.dart for working memory, then persist through si_engine_repository.dart.

Bridge flow:
SI Console UI
  -> AI Controller
  -> Intelligence Providers
  -> Agent Orchestrator
  -> AI Agents + Tools
  -> SI Engine Repository
  -> SI Engine Service
  -> Internal SI Modules
  -> Validated SI Output Bundle
  -> Controller State
  -> UI

Important rule:
Do not connect features/si_console directly to engine/si/*. Use ai_controller.dart, intelligence_provider.dart, agent_orchestrator.dart, si_engine_repository.dart, and si_engine_service.dart as the controlled bridge.
