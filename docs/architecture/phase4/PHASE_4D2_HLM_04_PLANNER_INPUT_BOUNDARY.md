# Phase 4D.2 — HLM-04 Shared Planner-Input Boundary

## Exact Phase 3 definition

HLM-04 / Group C / P2: **“Specify a shared planner-input/read-model boundary.”** The required Phase 3 test is Creator-to-planner/Nexus continuity.

## Decision

`PlannerInput` and `PlannerInputAdapter` in `lib/domain/planning/` are the canonical shared planning read model and conversion boundary. `TaskEntity` and its existing task repository/storage remain canonical persisted task truth. `PlannerInput` has no repository or persistence; it carries only existing planning fields: identity, title, priority, difficulty, energy need, completion/cancellation, prerequisite ids, recurrence, duration, schedule, and deadline.

## Before and after

Before, Nexus mapped `TaskEntity` to legacy `Task` locally while giving raw `TaskEntity` to `DecisionEngine`; FeasiblePlanner took raw tasks; Smart Planner CalendarService took legacy `Task`; and task/SI use cases independently called planner engines with raw task lists.

After, `TaskEntity -> PlannerInputAdapter -> PlannerInput` is the canonical current-task direction. Nexus adapts repository records once, sends `PlannerInput` to DecisionEngine, and derives its legacy SI aggregation projection through the same adapter. DecisionEngine and FeasiblePlanner consume `PlannerInput`. Smart Planner CalendarService consumes `PlannerInput`; its existing legacy Task callers use `PlannerInputAdapter.fromLegacyTasks` at the controller boundary. The engine retains explicit temporary `List<TaskEntity>` compatibility parameters so independently protected task/SI use cases continue through the same adapter rather than defining new mappings.

## Continuity and compatibility

Creator remains upstream: HLM-01 `IntakeRequest` creates canonical task persistence, then planner readers adapt the persisted `TaskEntity`. Creator does not persist PlannerInput or learn planning internals. Legacy `Task` is transitional UI/SI compatibility only, with one conversion path in `PlannerInputAdapter`.

No plan/goal/habit persistence was folded into this read model. Existing task properties express recurrence and goal association where consumers currently use them; no additional planner source of truth was introduced. HLM-02 history and HLM-03 intervention outcomes remain separate facts/outcomes and are not planner inputs in this scope.

## Dirty isolation and validation

The committed 4D.1 planner baseline was modified only in its planning regions. The pre-existing SI Console integration correction remains unstaged. CalendarService’s pre-existing comment-only hunk and AI controller’s separate feedback hunk were preserved through selective staging. Known repository-wide load blockers remain out of scope: missing `authUserProvider`, obsolete AI-agent `si:` calls, and the incomplete Smart Planner test fake.

Focused tests cover TaskEntity and legacy Task conversion, field preservation, DecisionEngine, FeasiblePlanner, Calendar Smart Planner consumption, and source-level Creator/Nexus continuity. Branch review in 4D.0 found no prior shared planner read model.

## Remaining debt

The temporary raw `TaskEntity` engine compatibility entry points exist for independently protected use cases. A later scoped migration may make all callers construct PlannerInput directly, after their dirty provenance is isolated. No algorithms, UI, persistence, Timeline, SI reasoning, Trajectory, or Progression behavior was redesigned.
