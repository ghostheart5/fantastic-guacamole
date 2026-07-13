# Domain Entity Index

This document is the canonical index for core domain entities and where each concept is represented.

## Normalization Standard

For domain consistency, normalized entities should include:

- `id`
- `userId` (nullable when appropriate)
- `createdAt` and/or equivalent creation timestamp
- `updatedAt` (or an explicit equivalent lifecycle timestamp)
- explicit status enum for lifecycle state

Legacy boolean fields are still accepted during deserialization where applicable, and map into status enums for backward compatibility.

## Core Productivity Entities

- Task: `lib/domain/entities/task_entity.dart`
- Project: `lib/domain/entities/project_entity.dart`
- Plan: `lib/domain/entities/plan_entity.dart`
- Goal: `lib/domain/entities/goal_entity.dart`
- Milestone: `lib/domain/entities/milestone_entity.dart`
- Routine: `lib/domain/entities/routine_entity.dart`
- Habit: `lib/domain/entities/habit_entity.dart`
- Subtask: `lib/domain/entities/subtask_entity.dart`

## Scheduling And Time Entities

- Event: `lib/domain/entities/timeline_event_entity.dart`
- TimeBlock: `lib/domain/entities/time_block.dart`
- WorkWindow: `lib/domain/entities/work_window_entity.dart`
- Reminder: `lib/domain/entities/notification_entity.dart`
- Deadline: represented by due/target fields on
  - `lib/domain/entities/task_entity.dart` (`dueDate`)
  - `lib/domain/entities/milestone_entity.dart` (`targetDate`)
- Duration: represented by
  - `lib/domain/entities/task_entity.dart` (`estimatedDuration`)
  - `lib/domain/value_objects/duration_vo.dart`

## Intelligence Entities

- Status: `lib/domain/entities/si_state_entity.dart`
- Template: `lib/domain/entities/template_entity.dart`
- Rule: `lib/domain/entities/rule_entity.dart`
- Automation: `lib/domain/entities/automation_entity.dart`
- Score: `lib/domain/entities/score_entity.dart`
- Suggestion: `lib/domain/entities/suggestion_entity.dart`
- Decision Output: `lib/domain/entities/si_decision_entity.dart`

## Related Supporting Entities

- Profile: `lib/domain/entities/profile_entity.dart`
- Progression: `lib/domain/entities/progression_entity.dart`
- Insight: `lib/domain/entities/insight_entity.dart`
- Learning: `lib/domain/entities/learning_entity.dart`
- Memory: `lib/domain/entities/memory_entity.dart`
- Notification: `lib/domain/entities/notification_entity.dart`
- Session: `lib/domain/entities/session_entity.dart`
- Workspace: `lib/domain/entities/workspace_entity.dart`

## Barrel Export Surface

The canonical import surface is:

- `lib/domain/domain.dart`

All entities listed above are exported through the domain barrel.

## Normalized Entity Snapshot

The following entities currently implement the normalized metadata and lifecycle pattern.

| Entity | File | Identity And Metadata | Lifecycle Enum | Legacy Compatibility |
| --- | --- | --- | --- | --- |
| Project | `lib/domain/entities/project_entity.dart` | `id`, `userId`, `createdAt`, `updatedAt` | `ProjectStatus { active, archived }` | `archived` bool maps to `status` |
| Habit | `lib/domain/entities/habit_entity.dart` | `id`, `userId`, `createdAt`, `updatedAt` | `HabitStatus { active, paused, archived }` | `active` bool maps to `status` |
| Routine | `lib/domain/entities/routine_entity.dart` | `id`, `userId`, `createdAt`, `updatedAt` | `RoutineStatus { active, paused, archived }` | `active` bool maps to `status` |
| Subtask | `lib/domain/entities/subtask_entity.dart` | `id`, `userId`, `createdAt`, `updatedAt` | `SubtaskStatus { pending, completed, canceled }` | `isCompleted` bool maps to `status` |
| Rule | `lib/domain/entities/rule_entity.dart` | `id`, `userId`, `createdAt`, `updatedAt` | `RuleStatus { enabled, disabled, archived }` | `enabled` bool maps to `status` |
| Automation | `lib/domain/entities/automation_entity.dart` | `id`, `userId`, `createdAt`, `updatedAt` | `AutomationStatus { enabled, disabled, paused, archived }` | `enabled` bool maps to `status` |
| Template | `lib/domain/entities/template_entity.dart` | `id`, `userId`, `createdAt`, `updatedAt` | `TemplateStatus { draft, active, archived }` | `active` bool maps to `status` |
| WorkWindow | `lib/domain/entities/work_window_entity.dart` | `id`, `userId`, `createdAt`, `updatedAt` | `WorkWindowStatus { planned, active, completed, canceled }` | No legacy boolean fallback needed |
| Suggestion | `lib/domain/entities/suggestion_entity.dart` | `id`, `userId`, `createdAt`, `updatedAt` | `SuggestionStatus { proposed, accepted, rejected, dismissed }` | No legacy boolean fallback needed |
| Score | `lib/domain/entities/score_entity.dart` | `id`, `userId`, `recordedAt`, `updatedAt` | `ScoreStatus { provisional, validated, archived }` | No legacy boolean fallback needed |

## Notes

- `ScoreEntity` uses `recordedAt` instead of `createdAt` as its primary creation-time semantic.
- `SubtaskEntity` adds `completedAt` to preserve completion timing independent of status.
- `RuleEntity`, `AutomationEntity`, and `WorkWindowEntity` default `createdAt` and `updatedAt` via constructor fallback to epoch when omitted.

## Ownership Cross-Reference

This matrix maps each normalized entity to the current primary provider and use-case touchpoints.
If no concrete touchpoint exists in `lib/state/providers` or `lib/domain/usecases`, it is marked as pending integration.

| Entity | Primary Provider Touchpoint | Primary Use-Case Touchpoint | Integration Status |
| --- | --- | --- | --- |
| Project | `lib/state/providers/domain_usecase_providers.dart` (`domainProjectRepositoryProvider`) | `getProjectsUseCaseProvider`, `createProjectUseCaseProvider`, `updateProjectUseCaseProvider`, `deleteProjectUseCaseProvider`, `saveProjectsUseCaseProvider` | Wired through `ProjectRepository` and use-case provider layer |
| Habit | `lib/state/providers/habits_provider.dart` (`habitsProvider`) | Pending integration | Active provider wiring via `HabitRepository` |
| Routine | `lib/state/providers/domain_usecase_providers.dart` (`domainRoutineRepositoryProvider`) | `getRoutinesUseCaseProvider`, `createRoutineUseCaseProvider`, `updateRoutineUseCaseProvider`, `deleteRoutineUseCaseProvider`, `saveRoutinesUseCaseProvider` | Wired through `RoutineRepository` and use-case provider layer |
| Subtask | `lib/state/providers/domain_usecase_providers.dart` (`domainSubtaskRepositoryProvider`) | `getSubtasksUseCaseProvider`, `createSubtaskUseCaseProvider`, `updateSubtaskUseCaseProvider`, `deleteSubtaskUseCaseProvider`, `saveSubtasksUseCaseProvider` | Wired through `SubtaskRepository` and use-case provider layer |
| Rule | Pending integration | Pending integration | Indexed in domain; no dedicated provider/use-case wiring yet |
| Automation | Pending integration | Pending integration | Indexed in domain; no dedicated provider/use-case wiring yet |
| Template | Pending integration | Pending integration | Indexed in domain; no dedicated provider/use-case wiring yet |
| WorkWindow | Pending integration | Pending integration | Indexed in domain; no dedicated provider/use-case wiring yet |
| Suggestion | Pending integration | Pending integration | Indexed in domain; no dedicated provider/use-case wiring yet |
| Score | `lib/state/providers/session_score_provider.dart` (`sessionScoreProvider`) | Pending integration | Active view-state provider; no domain use-case binding yet |

Additional context:

- Task domain flows are wired through `lib/state/providers/task_provider.dart` and task use-cases exposed via `lib/state/providers/domain_usecase_providers.dart`.
- Repository implementations for this matrix live in `lib/data/repositories/project_repository.dart`, `lib/data/repositories/routine_repository.dart`, and `lib/data/repositories/subtask_repository.dart`.
- The normalized entities in this section are exported and available through `lib/domain/domain.dart` even when not yet fully wired in provider/use-case layers.
