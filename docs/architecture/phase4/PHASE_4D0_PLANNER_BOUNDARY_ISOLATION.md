# Phase 4D.0 — Protected Planner / SI Boundary Isolation

## Blocker and Phase 2 preservation proof

HLM-04 is **“Specify a shared planner-input/read-model boundary”** (Phase 3, Group C, P2). Its required continuity crosses Creator, Smart Planner, Nexus, and task read models. The current Nexus route was introduced by protected work, so changing it now would misattribute or overwrite preserved work.

| File | Git status | HEAD Git blob | Current SHA-256 | Phase 2 SHA-256 | Current equals snapshot |
| --- | --- | --- | --- | --- | --- |
| `lib/state/providers/si_pipeline_provider.dart` | tracked, modified | `65f90748ab21ef5e68d09d6a5d83b451c18db9bf` | `2ceaaf22db2bb4de17e50ce48dfffefea8276938ad676c10b2bcddc6070c540b` | `2ceaaf22db2bb4de17e50ce48dfffefea8276938ad676c10b2bcddc6070c540b` | yes |
| `lib/engine/decision/decision_engine.dart` | untracked | absent | `1d9d89a9e9e8d9842bc6d3ab246c5e32e0641bd66724eff24b2daf82f5c29980` | `1d9d89a9e9e8d9842bc6d3ab246c5e32e0641bd66724eff24b2daf82f5c29980` | yes |
| `lib/engine/planning/feasible_planner.dart` | untracked | absent | `69c8eec9974b429b9e74cd0584aae884c154fd3868a3c66dfcd1dc95bc73ecd1` | `69c8eec9974b429b9e74cd0584aae884c154fd3868a3c66dfcd1dc95bc73ecd1` | yes |

Phase 2 `before-state.txt` independently records the SI provider as modified and `feasible_planner.dart` as untracked; the snapshot tree contains both untracked engines. No current/snapshot discrepancy exists.

## Protected SI delta

`si_pipeline_provider.dart` has five focused diff hunks against HEAD:

1. Imports `SiStateEntity`, `DecisionEngine`, and `learningProvider` — planning dependency wiring.
2. Loads active `TaskEntity` records and maps a separate legacy `Task` projection — task read/model compatibility.
3. Replaces `CalendarService.generateAdaptivePlan` with `DecisionEngine.recommend` and `FeasiblePlan` titles — Nexus planning behavior.
4. Replaces `_loadAllActiveTasks` with `TaskEntity` loading and adds `_mapTaskEntitiesToLegacyTasks` — read/model adapter boundary.
5. Changes SI Console integration snapshot access — adjacent integration correction, not planner behavior.

Hunks 1–4 are a coherent protected planning/SI subsystem. Hunk 5 is separate adjacent protected work and must not enter a planner baseline commit.

## Protected engines

`DecisionEngine` is intentional current user work (**A**): it is byte-identical to Phase 2, imported by Nexus, task recommendation/plan use cases, `GenerateSiDecision`, AI agents, and `LegacyDecisionAdapter`. It accepts `TaskEntity`, `SiStateEntity`, `LearningEntity`, optional work windows, and returns `DecisionRecommendation` with a `FeasiblePlan`.

`FeasiblePlanner` is intentional current user work (**A**): it is byte-identical to Phase 2 and consumed by `DecisionEngine`, task-plan use cases, and schedule-adjustment use cases. It accepts `PlanningProblem` (`TaskEntity`, work windows, time blocks, energy, now) and returns `FeasiblePlan` (`TimeBlock`, unscheduled ids, typed issues). The two engines form one coherent planning subsystem; neither is generated nor a known committed duplicate.

## HLM-04 required-region overlap

| Required region | Required purpose | Overlap |
| --- | --- | --- |
| new `lib/domain/planning/` read model/adapter | define canonical shared input contract | NONE, but not yet useful without integration |
| `si_pipeline_provider.dart` imports, task loading/mapping, DecisionEngine call | make Nexus consume shared input | DIRECT |
| `decision_engine.dart` recommendation input | consume canonical shared input | DIRECT |
| `feasible_planner.dart` `PlanningProblem.tasks` | consume canonical shared input or adapted task list | DIRECT |
| Creator provider | prove persisted Creator output reaches input boundary | NONE for code if adapter reads repository `TaskEntity`; protected auth hunks remain separate |
| Smart Planner `ai_controller.dart` / calendar path | migrate legacy planning input | DIRECT: controller is already dirty; its current CalendarService path is distinct |
| task plan/recommendation and SI use cases | migrate raw `List<TaskEntity>` callers | PARTIAL: files are already dirty but have separate call boundaries |
| Nexus display model | consume plan preview | DIRECT through protected SI provider |

## Branch-history provenance

`backup-before-flow-cleanup` and `rescue/chronospark-stabilization` contain prior committed `si_pipeline_provider.dart` history (including `33d11653` and `e781f89a`), but neither contains `decision_engine.dart` or `feasible_planner.dart`. `main` also lacks both engine files. No prior shared planner-input/read-model boundary was found. The current protected pipeline is therefore attributable as a Phase 2-preserved working-tree baseline, not as a known committed implementation. No branch was merged or cherry-picked.

## Baseline strategy

The safest strategy is **remain blocked pending user decision**. Hunk isolation cannot establish HLM-04 because every effective consumer integration overlaps protected work. An adapter outside protected regions would create a second unused truth or bypass the current subsystem. A preservation commit candidate would contain only:

- `lib/engine/decision/decision_engine.dart`;
- `lib/engine/planning/feasible_planner.dart`;
- SI provider hunks 1–4, explicitly excluding hunk 5;
- any direct missing dependencies proven necessary by a focused baseline compilation.

That candidate is **NEEDS USER DECISION**, not justified automatically: the two engine files are coherent and snapshot-proven, but their required SI integration is mixed with a separate protected hunk, and several direct callers are independently dirty. A commit merely to clear status would misrepresent unresolved provenance.

HLM-04 cannot proceed without modifying protected work. The recommended next action is an explicitly authorized preservation-baseline procedure with a complete hunk manifest and focused baseline validation, or user direction to keep the boundary blocked.
