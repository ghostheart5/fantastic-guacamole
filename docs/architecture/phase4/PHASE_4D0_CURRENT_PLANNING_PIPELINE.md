# Phase 4D.0 — Current Protected Planning Pipeline

## Evidence boundary

This is an evidence-only record. The Phase 2 protected snapshot at `phase2-20260812-164222` contains the current bytes for all files below. No runtime file was modified during this subphase.

## Current flow

```text
CreatorFormData
  -> IntakeRequest (HLM-01 canonical interpretation)
  -> TaskEntity / TaskRepository
  -> List<TaskEntity>
  -> si_pipeline_provider (Nexus)
       -> List<Task> compatibility projection for SI aggregation
       -> DecisionEngine.recommend(List<TaskEntity>, SiStateEntity, LearningEntity)
            -> FeasiblePlanner.plan(PlanningProblem)
            -> FeasiblePlan / TimeBlock titles
       -> SIStateAggregation.planPreview -> NexusScreenModel
```

Creator writes task-backed task/routine/note/plan records through `TaskEntity` and the task repository. That persistence record is the current state source; it is not a planner-specific aggregate.

The protected Nexus/SI path loads active `TaskEntity` records, retains them for `DecisionEngine`, and separately maps them to legacy `Task` records for `SIStateAggregation.tasks`. `DecisionEngine` filters active tasks and creates a `PlanningProblem`; `FeasiblePlanner` produces `FeasiblePlan`, `TimeBlock`, unscheduled identifiers, and issues. Nexus currently consumes only the first three block titles as `planPreview`.

## Parallel planning and compatibility paths

- `GenerateTaskPlanUsecase` takes raw `List<TaskEntity>` and creates `PlanningProblem` directly.
- `GenerateTaskRecommendationsUsecase` takes raw `List<TaskEntity>` and calls `DecisionEngine` directly.
- `GenerateSiDecision` reads `List<TaskEntity>` from `ITaskRepository` and calls `DecisionEngine` directly.
- `LegacyDecisionAdapter` maps legacy `List<Task>` to `TaskEntity` for `DecisionEngine` compatibility.
- Smart Planner controller paths still use legacy `Task` with `CalendarService.generateAdaptivePlan`; `ai_controller.dart` is already dirty and remains untouched.
- `futureDecisionEngineProvider` is a distinct future-self projection and does not call the protected decision/planner subsystem.

## Boundary defects relevant to HLM-04

There is no shared planner read model. `TaskEntity`, legacy `Task`, and direct input lists cross the Creator, Smart Planner, Nexus, SI, and planner boundaries independently. HLM-04 would need one domain read model/adaptation point, but it must not bypass the preserved DecisionEngine/FeasiblePlanner path or claim that Timeline, History, or intervention outcomes own current planning state.
