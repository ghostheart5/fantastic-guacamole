# Phase 3 Duplicate Truths

| Concept | Representations | Assessment |
| --- | --- | --- |
| Task | `TaskEntity`, domain `Task`, task views, Creator task kinds, subtasks | Architecture duplication; mapper boundary is not consistently authoritative |
| Habit/routine | `HabitEntity`, `RoutineEntity`, recurring `TaskEntity` | Conflicting business truth |
| Note | `NoteEntity`, task kind `note`, workspace reflections | Conflicting business truth |
| History | Timeline events, log entries, memories, completion events, SI workspace | Conflicting business truth |
| Priority | task integer, value object, ranker/provider scores | Uncertain/duplicated calculation boundary |
| Progress | progression entity, XP/streak/session/learning providers | Architecture duplication with private metrics |
| Preferences | settings, profile, theme, feature services, SharedPreferences keys | Architecture duplication |
| Conversation/reflection | controller state, SI memory, workspace store, persisted summaries | Uncertain boundary |

DTO conversion is appropriate only where one aggregate remains authoritative. The audit found no written rule establishing that boundary for the conflicting rows.
