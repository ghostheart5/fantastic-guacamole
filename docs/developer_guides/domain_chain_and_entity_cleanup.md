<style>
a {
    text-decoration: none;
    color: #464feb;
}
tr th, tr td {
    border: 1px solid #e6e6e6;
}
tr th {
    background-color: #f5f5f5;
}
</style>

## Real app behavior chain

Feature/UI action
  -> state/provider/controller
  -> domain/usecase
  -> domain/interface
  -> data/repository implementation
  -> storage/service/engine

Separation of concerns in this repo should follow that path consistently for persisted user data.

## Entity risks / cleanup points

| Risk | Evidence from tree | What to do |
| --- | --- | --- |
| Duplicate naming | task.dart + task_entity.dart; calendar_entry.dart + calendar_entry_entity.dart | Keep one active convention and treat the other as explicit legacy only. |
| Wide entity layer but uneven flows | goal_entity.dart, memory_entity.dart, timeline_event_entity.dart, flowmap_node.dart | Each persisted or user-editable entity needs an interface, a repository owner, and a usecase path. |
| Binder concepts larger than current domain | Projects, plans, routines, templates, rules, automations, notes, categories, tags, alerts | Do not add domain entities unless they are real v1 concepts with UI and lifecycle. |
| Derived view concepts mixed with core entities | timeline_event_entity.dart, progression_entity.dart, insight_entity.dart | If derived, prefer query/generation usecases over full CRUD repositories. |

Entity completeness test:
Can you explain identity, lifecycle, owner repository, mutations, and UI consumers? If not, the entity is still under-specified.

## Gaps addressed in current code

The following now have real domain contracts:
- i_goal_repository.dart -> goal_repository.dart
- i_memory_repository.dart -> memory_repository.dart
- i_timeline_repository.dart -> timeline_repository.dart
- i_flowmap_repository.dart -> flowmap_repository.dart
- i_identity_repository.dart -> identity_repository.dart

The following provider chains now route through domain usecases instead of SharedPrefs directly:
- goals_provider.dart
- memories_provider.dart
- timeline_provider.dart

## Remaining cleanup guidance

- task/task_entity and calendar_entry/calendar_entry_entity still need convention cleanup.
- identity_provider.dart still contains direct SharedPrefs persistence for identity-state modeling; keep separate from identity_repository.dart unless that state becomes shared domain data.
- Derived entities like insight/progression/timeline should avoid full CRUD unless they become user-authored records.
