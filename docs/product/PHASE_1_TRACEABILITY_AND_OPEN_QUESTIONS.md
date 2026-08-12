# ChronoSpark Phase 1 Traceability and Open Questions

**Status:** Phase 1 delivery record
**Reviewed:** 2026-08-12

## Traceability table

| Existing document | Relationship | Governing contract coverage | Notes |
| --- | --- | --- | --- |
| `CHRONOSPARK.md` | Supports; superseded for product intent | Product Constitution; Human Life Model | Supports planning, reflection, execution, Timeline, SI, and preferences. Superseded where it does not state agency, anti-shame, privacy, non-diagnosis, or uncertainty limits. |
| `README.md` | Supports; superseded for product intent | Product Constitution | Supports ChronoSpark as a planning, reflection, and focused-execution product with SI guidance. The governing contract supplies behavioral limits. |
| `docs/SI_ENGINE_BOUNDARY.md` | Supports | SI Intelligence Model | Supports a bounded SI surface and behavior-first naming. It is architectural, not a statement of permitted inference. |
| `docs/developer_guides/si_assistant_layer_contract.md` | Supports; superseded for product intent | SI Intelligence Model | Supports a layered SI boundary. The governing contract controls SI behavior and user-facing accountability. |
| `docs/developer_guides/si_hallucination_prevention_and_memory_layers.md` | Supports; conflicts | Human Life Model; SI Intelligence Model | Supports grounded outputs and summarized-memory privacy intent. Conflicts are recorded as C-03 because user control and retention boundaries are absent. |
| `docs/developer_guides/si_console_communication_flow.md` | Supports | SI Intelligence Model | Supports validation, ranking, deduplication, and a response/memory flow. The governing contract adds explainability and user-control requirements. |
| `docs/flowmaps/si_console_flowmap.md` | Supports; conflicts; superseded for product intent | Human Life Model; SI Intelligence Model; Intervention Engine | Supports context, reasons, degraded-state marking, and deterministic fallback. C-04 records the persistence-control conflict. Intervention requirements are now governed by Phase 1. |
| `docs/flowmaps/timeline_flowmap.md` | Supports | Human Life Model | Supports Timeline events as relevant context. The governing contract bounds their use to explainable, user-centered inference. |
| `docs/flowmaps/memory_engine_flowmap.md` | Supports; superseded for product intent | Human Life Model; SI Intelligence Model | Supports structured, purpose-related memory and SI personalization. The governing contract adds minimization and user control. |
| `docs/smart_coach_followup_focus_insight_logic_audit.txt` | Supports; conflicts | Human Life Model; SI Intelligence Model; Intervention Engine | Supports explicit energy/emotion/reflection context and explainable insight surfaces. C-05 records rationale-source divergence. |
| `docs/smart_planner_control_clarity_report.txt` | Supports | Human Life Model | Supports user-facing explanation that emotional state changes guidance tone/intensity. The governing contract clarifies non-diagnostic limits. |
| `docs/trajectory_feature_audit.txt` | Supports; conflicts | Future / Trajectory Model | Supports evidence-based assessment of forecast inputs/outputs. C-01 and C-02 remain open. |
| `docs/chronospark_data_model_domain_audit.txt` | Supports; superseded for product intent | Human Life Model; Intervention Engine | Supports goals/tasks/routines/timeline/history as product inputs and identifies note/routine questions. It does not define product-permitted inference or intervention controls. |

## Open questions

These questions do not block the governing contracts. They must be resolved before the related capability is expanded or represented as fully conformant.

1. What user-facing memory controls are required: view, edit/correct, delete, retention period, export, and a global SI-memory disable control?
2. Which SI context is essential to persist, which is session-only, and which—if any—requires explicit opt-in before retention?
3. What severity vocabulary and delivery policy will distinguish quiet planning suggestions from high-urgency product/safety notices without making SI guidance coercive?
4. What confidence scale and minimum-evidence threshold will be standardized across SI, Smart Planner, Smart Coach, notifications, and Trajectory?
5. How should a user inspect an intervention’s evidence while protecting private details and avoiding an overwhelming technical explanation?
6. Will notes remain a task-kind representation or become a first-class entity, and will routines remain distinct from habits? These open domain-model questions affect future Human Life Model precision but not its current category boundaries.
7. What trajectory horizons and scenario labels best communicate possibility and changeability without implying a fixed personal future?

## Phase 1 verification boundary

This delivery adds only the three documents in `docs/product/`. It deliberately does not change runtime code, architecture, data models, tests, existing documentation, or implementation behavior.
