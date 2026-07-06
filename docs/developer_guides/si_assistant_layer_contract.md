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

## SI Assistant Layer Contract

Layer 1 - Assistant UI:
- features/home/ui/smart_coach_screen.dart
- features/home/widgets/ai_decision_card.dart
- features/si_console/ui/si_console_screen.dart
- features/plan/ui/plan_screen.dart
- features/tasks/ui/task_screen.dart

Layer 2 - Assistant state/application layer:
- state/controllers/ai_controller.dart
- state/controllers/si_state_controller.dart
- state/controllers/prediction_controller.dart
- state/controllers/voice_controller.dart
- state/providers/intelligence_provider.dart
- state/providers/si_memory_provider.dart
- state/providers/trajectory_provider.dart
- state/providers/task_provider.dart
- state/providers/calendar_provider.dart

Layer 3 - Assistant intelligence/data layer:
- data/services/ai/orchestration/agent_orchestrator.dart
- data/services/ai/agents/*
- data/services/ai/tools/*
- data/repositories/si_engine_repository.dart
- engine/si/si_engine_service.dart

Contract notes:
- Layer 1 talks to Layer 2.
- Layer 2 orchestrates and may route through Layer 3 entry points.
- Layer 2 must not import agent/tool internals directly.
- Layer 3 owns orchestration internals and SI engine bridge/facade wiring.
