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

## Prevent incorrect responses / hallucinations

In this app, hallucination means the assistant outputs claims not grounded in app state, memory, logs, tasks, plans, settings, or known SI engine outputs.

Grounded response pipeline:
input grounding
  -> intent classification
  -> context builder
  -> engine response
  -> response validation
  -> policy check
  -> UI

## Where conversation memory should live

### Short-term conversation memory

Closest files:
- state/state/intelligence_state.dart
- state/controllers/ai_controller.dart
- state/providers/intelligence_provider.dart

This should hold active session-scoped conversation context used by the current UI runtime.

### SI working memory

Use:
- engine/si/si_memory.dart
- engine/si/si_snapshot.dart
- engine/si/si_tiered_memory.dart
- engine/si/si_user_state_tracker.dart
- engine/si/si_user_state_engine.dart

### Persistent memory

Use:
- data/repositories/si_engine_repository.dart
- data/storage/hive_service.dart
- data/storage/shared_prefs_service.dart
- data/storage/secure_store.dart
- state/providers/si_memory_provider.dart

Persist summarized memory events by default for privacy/performance. Store full raw history only when explicitly requested.

Recommended update flow:
assistant response accepted
  -> summarize interaction
  -> classify memory type
  -> update si_memory.dart
  -> create si_snapshot.dart
  -> persist through si_engine_repository.dart
  -> expose via si_memory_provider.dart

## Expanding SI module communication without tight coupling

Use hub-and-spoke orchestration, not all-to-all imports:
- si_engine_service.dart owns orchestration
- si_engine.dart / synthetic_intelligence_engine.dart own core decision process
- si_input_fusion.dart builds normalized context
- si_intent_engine.dart classifies intent
- si_memory.dart / si_snapshot.dart provide memory context
- prediction_engine.dart forecasts outcomes
- si_reasoning.dart / si_meta_reasoning.dart reason over candidate actions
- engine/planning/calendar_service.dart validates schedule constraints
- engine/tasks/task_ranker.dart ranks tasks
- si_policy.dart / si_ethics_layer.dart enforce rules
- si_output_bundle.dart returns structured output

Communication contract:
SIInputContext -> SIIntent -> CandidateActions -> ValidatedDecision -> SIOutputBundle

## Current implementation touchpoints

- lib/engine/si/si_engine.dart
- lib/state/controllers/ai_controller.dart
- lib/state/providers/si_memory_provider.dart
- lib/data/repositories/si_engine_repository.dart
