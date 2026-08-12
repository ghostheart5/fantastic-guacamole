# Phase 3 Source-of-Truth Matrix

| Concept | Domain type / repository / persistence | Read path and consumers | Status |
| --- | --- | --- | --- |
| Goals | `GoalEntity` / `GoalRepository` / local Hive-style storage | goals provider; Creator, Nexus, Timeline, SI | VALID WITH DEBT |
| Tasks | `TaskEntity` plus `Task` / `TaskRepository` / Hive | task provider; all planning consumers | VALID WITH DEBT |
| Habits | `HabitEntity` / `HabitRepository` / Hive | habits/streak providers | VALID WITH DEBT |
| Plans | `PlanEntity` / `PlanRepository` / daily-plan storage | planner/provider | VALID WITH DEBT |
| Priorities | int + `Priority` + rankers / none singular | task/planner/SI | CONFLICTING |
| Notes | `NoteEntity` and task kind / no clear note repo | Creator/SI context | CONFLICTING |
| Reflections | workspace entries and Timeline / workspace store | Smart Coach/SI | AMBIGUOUS |
| History | Timeline/log/memory/completion repositories | feature-specific consumers | CONFLICTING |
| Progress | progression/streak/session types / progression repository | progression/Nexus/SI | VALID WITH DEBT |
| Timeline | `TimelineEventEntity` / `TimelineRepository` / SharedPreferences-style store | Timeline, SI, trajectory | VALID WITH DEBT |
| Planner inputs | form/provider types / mixed stores | Smart Planner | AMBIGUOUS |
| SI conversations | response/workspace/SI memory / secure workspace store | SI Console/coach | AMBIGUOUS |
| Emotion/context | emotion state/request context / mixed | Coach/SI | AMBIGUOUS |
| Preferences | settings/profile/theme / mixed local stores | all features | AMBIGUOUS |
| Intervention outcomes | no aggregate/repository | AI feedback only | MISSING |
