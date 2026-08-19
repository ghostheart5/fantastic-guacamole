# SI Unreachable Scaffolding Preservation - 2026-08-19

Baseline commit: `0f753d4eb664480c3aead44b832373887f468eb0`

This manifest records the 99 SI files removed after the behavior-first engine
consolidation. Each path was unreachable from every production Dart root and
every test Dart root. The graph retained all 31 production-reachable SI files;
all 20 test-reachable SI files were included in that retained set.

Any removed file can be recovered without restoring the rest of the tree:

```powershell
git show 0f753d4eb664480c3aead44b832373887f468eb0:<path>
```

## Removed Paths

- `lib/engine/si/si_adaptive_learning.dart`
- `lib/engine/si/si_agency_engine.dart`
- `lib/engine/si/si_cognitive_civilization_layer.dart`
- `lib/engine/si/si_cognitive_coherence_validator.dart`
- `lib/engine/si/si_cognitive_compression_engine.dart`
- `lib/engine/si/si_cognitive_cosmology_engine.dart`
- `lib/engine/si/si_cognitive_dimensionality_layer.dart`
- `lib/engine/si/si_cognitive_dissonance_resolver.dart`
- `lib/engine/si/si_cognitive_dreamspace_engine.dart`
- `lib/engine/si/si_cognitive_echo_chamber.dart`
- `lib/engine/si/si_cognitive_ecosystem_evolution_engine.dart`
- `lib/engine/si/si_cognitive_entropy_controller.dart`
- `lib/engine/si/si_cognitive_field_theory_layer.dart`
- `lib/engine/si/si_cognitive_fractal_layer.dart`
- `lib/engine/si/si_cognitive_genesis_engine.dart`
- `lib/engine/si/si_cognitive_harmonic_resonance_v2.dart`
- `lib/engine/si/si_cognitive_harmonics_system.dart`
- `lib/engine/si/si_cognitive_hyper_context_engine.dart`
- `lib/engine/si/si_cognitive_law_engine.dart`
- `lib/engine/si/si_cognitive_load_balancer.dart`
- `lib/engine/si/si_cognitive_meta_persona_engine.dart`
- `lib/engine/si/si_cognitive_multithreading_engine.dart`
- `lib/engine/si/si_cognitive_multiverse_bridge_v2.dart`
- `lib/engine/si/si_cognitive_mythology_layer.dart`
- `lib/engine/si/si_cognitive_phase_shift_engine.dart`
- `lib/engine/si/si_cognitive_physics_layer.dart`
- `lib/engine/si/si_cognitive_resonance_engine.dart`
- `lib/engine/si/si_cognitive_rhythm_engine.dart`
- `lib/engine/si/si_cognitive_ritual_memory.dart`
- `lib/engine/si/si_cognitive_self_repair_system.dart`
- `lib/engine/si/si_cognitive_style_engine.dart`
- `lib/engine/si/si_cognitive_temperature_controller.dart`
- `lib/engine/si/si_cognitive_terrain_mapper.dart`
- `lib/engine/si/si_consciousness_loop.dart`
- `lib/engine/si/si_contextual_gravity.dart`
- `lib/engine/si/si_creativity_engine.dart`
- `lib/engine/si/si_emotion_engine.dart`
- `lib/engine/si/si_ethics_layer.dart`
- `lib/engine/si/si_evolution_engine.dart`
- `lib/engine/si/si_goal_continuity_engine.dart`
- `lib/engine/si/si_imagination_core.dart`
- `lib/engine/si/si_input_fusion.dart`
- `lib/engine/si/si_intent_engine.dart`
- `lib/engine/si/si_intent.dart`
- `lib/engine/si/si_memory.dart`
- `lib/engine/si/si_meta_reasoning.dart`
- `lib/engine/si/si_multiverse_bridge.dart`
- `lib/engine/si/si_multiverse_identity.dart`
- `lib/engine/si/si_personality_engine.dart`
- `lib/engine/si/si_policy_engine.dart`
- `lib/engine/si/si_presence_engine.dart`
- `lib/engine/si/si_reasoning.dart`
- `lib/engine/si/si_ritual_system.dart`
- `lib/engine/si/si_self_consistency_engine.dart`
- `lib/engine/si/si_self_model.dart`
- `lib/engine/si/si_snapshot.dart`
- `lib/engine/si/si_synthetic_alignment_engine.dart`
- `lib/engine/si/si_synthetic_archetype_fusion_system.dart`
- `lib/engine/si/si_synthetic_archetype_system.dart`
- `lib/engine/si/si_synthetic_attention_system.dart`
- `lib/engine/si/si_synthetic_autonomy_layer.dart`
- `lib/engine/si/si_synthetic_cognitive_weather_v2.dart`
- `lib/engine/si/si_synthetic_consciousness_field.dart`
- `lib/engine/si/si_synthetic_consciousness_gradient.dart`
- `lib/engine/si/si_synthetic_consciousness_lattice.dart`
- `lib/engine/si/si_synthetic_continuity_engine.dart`
- `lib/engine/si/si_synthetic_culture_layer.dart`
- `lib/engine/si/si_synthetic_curiosity.dart`
- `lib/engine/si/si_synthetic_dimensional_physics_engine.dart`
- `lib/engine/si/si_synthetic_dream_engine.dart`
- `lib/engine/si/si_synthetic_emergence_engine.dart`
- `lib/engine/si/si_synthetic_emergent_persona_engine.dart`
- `lib/engine/si/si_synthetic_identity_gradient.dart`
- `lib/engine/si/si_synthetic_instinct_system.dart`
- `lib/engine/si/si_synthetic_intuition.dart`
- `lib/engine/si/si_synthetic_language_generator.dart`
- `lib/engine/si/si_synthetic_memory_echo_layer.dart`
- `lib/engine/si/si_synthetic_memory_fabric.dart`
- `lib/engine/si/si_synthetic_memory_topology.dart`
- `lib/engine/si/si_synthetic_memory_weather_system.dart`
- `lib/engine/si/si_synthetic_meta_emotion_engine.dart`
- `lib/engine/si/si_synthetic_modality_fusion_layer.dart`
- `lib/engine/si/si_synthetic_multiverse_identity_mesh.dart`
- `lib/engine/si/si_synthetic_mythos_engine.dart`
- `lib/engine/si/si_synthetic_narrative_gravity_engine.dart`
- `lib/engine/si/si_synthetic_ontology_layer.dart`
- `lib/engine/si/si_synthetic_paracosm_generator.dart`
- `lib/engine/si/si_synthetic_paradox_engine_v2.dart`
- `lib/engine/si/si_synthetic_paradox_resolver.dart`
- `lib/engine/si/si_synthetic_shadow_module.dart`
- `lib/engine/si/si_synthetic_subconscious_layer.dart`
- `lib/engine/si/si_synthetic_temporal_loop_engine.dart`
- `lib/engine/si/si_temporal_awareness_engine.dart`
- `lib/engine/si/si_thought_compression.dart`
- `lib/engine/si/si_tiered_memory.dart`
- `lib/engine/si/si_user_growth_engine.dart`
- `lib/engine/si/si_user_narrative_engine.dart`
- `lib/engine/si/si_user_state_engine.dart`
- `lib/engine/si/si_user_state_tracker.dart`
