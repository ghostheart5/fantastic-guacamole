# Phase 3 Human Life Model Map

| Concept | Trace and downstream use | Status |
| --- | --- | --- |
| Goals | Creator → `goalsProvider` → `GoalEntity`/use cases → `GoalRepository` → local storage → Nexus, Timeline, SI | VALID WITH DEBT |
| Tasks | Creator → `taskProvider` → `TaskEntity`/`Task` → `TaskRepository`/Hive → planner, Timeline, progression, SI | VALID WITH DEBT |
| Habits | UI/provider → `HabitEntity`/`HabitRepository` → Hive → streak/Timeline/SI | VALID WITH DEBT |
| Plans | Planner/provider → `PlanEntity`/`PlanRepository` → daily-plan storage → planning views | VALID WITH DEBT |
| Priorities | task integer plus `Priority` value object and ranking engines → consumers | CONFLICTING |
| Notes | Creator task kind and `NoteEntity.toTaskEntity`; no clear first-class repository/read path | CONFLICTING |
| Reflections | Smart Coach input → workspace/SI reflection payload and Timeline; no shared aggregate | AMBIGUOUS |
| History | Timeline, log, completion-event, memory, and workspace histories | CONFLICTING |
| Progress | progression entity/service, task completion, streak/session scores | VALID WITH DEBT |
| Timeline events | feature/provider → `TimelineEventEntity` → `TimelineRepository` → UI/SI/trajectory | VALID WITH DEBT |
| Smart Planner inputs | creator/form/provider and planning engines; no canonical input aggregate | AMBIGUOUS |
| SI Console conversations | console/controller → SI/workspace stores → response state | AMBIGUOUS |
| Emotional/context signals | emotion selector/provider and coach request context | AMBIGUOUS |
| Preferences | settings/profile/theme and feature-local preference services | AMBIGUOUS |
| Accepted interventions | suggestion feedback in AI/controller paths; no intervention record/repository | MISSING |
| Dismissed interventions | rejection feedback in AI/controller paths; no intervention record/repository | MISSING |

SI and Trajectory consume tasks, goals, timeline, completion/log, emotion, profile, and progression signals, but their data dependencies do not establish a unified Human Life Model.
