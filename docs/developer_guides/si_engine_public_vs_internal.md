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

## Which SI engine files should be public vs internal

Your `engine/si` folder is large and should be treated as a private subsystem.

### Public engine facade files

These are the engine files allowed as public integration points:
- engine/si/si_engine_service.dart
- engine/si/si_engine.dart
- engine/si/synthetic_intelligence_engine.dart
- engine/si/ai_response.dart
- engine/si/si_decision.dart
- engine/si/si_output_bundle.dart
- engine/si/models/si_state.dart

### Internal engine modules

These should be imported inside engine only, not by UI/state/data directly:
- si_input_fusion.dart
- si_intent_engine.dart
- si_reasoning.dart
- si_meta_reasoning.dart
- prediction_engine.dart
- si_memory.dart
- si_snapshot.dart
- si_tiered_memory.dart
- si_user_state_tracker.dart
- si_adaptive_learning.dart
- si_cognitive_coherence_validator.dart
- si_self_consistency_engine.dart
- si_policy.dart
- si_ethics_layer.dart
- si_output_bundle.dart
