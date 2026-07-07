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

### Main controller/interface layer

Your best existing controller entry points are:
- lib/state/controllers/ai_controller.dart
- lib/state/controllers/si_state_controller.dart
- lib/state/providers/intelligence_provider.dart
- lib/state/providers/si_memory_provider.dart

| Entry Point | Responsibility |
| --- | --- |
| `ai_controller.dart` | Main chatbot controller: receive user text, create request, call orchestrator, update message state. |
| `si_state_controller.dart` | Owns current SI state, snapshots, learning state, and active operational context. |
| `intelligence_provider.dart` | Riverpod provider exposing assistant/chat runtime intelligence to UI and controller layers. |
| `si_memory_provider.dart` | Provider exposing short/long-term SI memory to the assistant layer. |

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
