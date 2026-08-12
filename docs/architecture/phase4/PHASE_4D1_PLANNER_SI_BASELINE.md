# Phase 4D.1 — Preserved Planner / SI Baseline

## Why this commit exists

HLM-04 requires a shared planner-input/read-model boundary, but the active Nexus planning route and its engines were protected Phase 2 work. The user explicitly authorized a baseline commit so later HLM-04 work can be attributed separately. This is preservation only: it introduces no shared read model and changes no Planner, SI, Nexus, Creator, History, or intervention behavior beyond committing the already-present implementation.

## Snapshot proof

All included content is byte-identical to the Phase 2 snapshot:

| File | SHA-256 |
| --- | --- |
| `lib/state/providers/si_pipeline_provider.dart` protected planning delta | `2ceaaf22db2bb4de17e50ce48dfffefea8276938ad676c10b2bcddc6070c540b` |
| `lib/engine/decision/decision_engine.dart` | `1d9d89a9e9e8d9842bc6d3ab246c5e32e0641bd66724eff24b2daf82f5c29980` |
| `lib/engine/planning/feasible_planner.dart` | `69c8eec9974b429b9e74cd0584aae884c154fd3868a3c66dfcd1dc95bc73ecd1` |

The engines are intentional coherent current work, not generated output: they are imported by Nexus, task plan/recommendation use cases, SI decision generation, AI agents, and the legacy decision adapter. A targeted secret-pattern scan found no credential-like content.

## Included and excluded SI hunks

Included `si_pipeline_provider.dart` hunks are: (1) planning imports, (2) `TaskEntity` loading plus legacy `Task` projection, (3) `DecisionEngine`/`FeasiblePlan` plan preview, and (4) the loading/mapping helpers. Together they establish the current persisted task → DecisionEngine → FeasiblePlanner → Nexus preview route.

Excluded hunk: SI Console integration snapshot access. It is an independent adjacent correction and is not required for DecisionEngine or FeasiblePlanner inputs/outputs. It remains unstaged and byte-identical to the Phase 2 snapshot. Creator auth/session changes, all other dirty work, and all HLM-04 read-model work are excluded.

## Validation and known debt

Raw-SDK targeted analysis of `decision_engine.dart`, `feasible_planner.dart`, and the current SI pipeline completed successfully. It reported one existing informational `unnecessary_import` diagnostic in the SI pipeline.

The available SI pipeline and Smart Planner tests did not collect because unrelated repository defects prevented test loading: missing `authUserProvider` in `adaptive_guidance.dart`, obsolete `si:` parameters in AI agents, and a stale `SecureStore` test fake missing `readAll`. No planner/feasible-planner diagnostic was reported. These are preserved baseline debt; no code was changed to mask them.

## Future HLM-04

The committed baseline makes the current system attributable. HLM-04 still needs an explicit canonical planner input/read model and migrations of Nexus, Smart Planner, SI/task use cases, and legacy `Task` compatibility. That refactor is intentionally out of scope here.
