# Timeline FlowMap

## Trigger
A lifecycle event occurs (task completed, goal changed, streak milestone, reflection).

## Flow
1. Feature emits timeline-worthy domain event.
2. Timeline provider/action maps event to timeline entity.
3. Timeline repository persists event.
4. Timeline list is refreshed and sorted by timestamp.
5. Related features (Nexus/SI/Progression) consume timeline context.
6. UI renders timeline events and milestone markers.
7. Analytics event is logged.

## Data and Services
- Screen: Timeline screen + mirrored timeline panels
- Provider/Controller: timeline provider/actions
- Use case: add/list timeline events
- Repository: timeline repository
- Data source: local persistence + optional sync
- Services: analytics + error logging

## Errors
- Event serialization failure
- Timeline write failure

## Fallback
- Best-effort timeline logging (non-blocking)
- Continue core user flow even if timeline write fails

## Analytics Event
- timeline_event_added
- timeline_milestone_rendered
