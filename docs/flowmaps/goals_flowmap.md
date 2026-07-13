# Goals FlowMap

## Trigger
User creates, updates, links, or completes a goal.

## Flow
1. Goals screen receives user action.
2. Provider validates goal input.
3. Goal use case runs create/update logic.
4. Goal repository persists goal.
5. Related providers refresh (tasks/progress/timeline).
6. Optional flowmap/timeline entries are created.
7. UI updates goals list and metrics.
8. Analytics is logged.

## Data and Services
- Screen: Goals screen
- Provider/Controller: goals provider/actions
- Use case: create/update/list goals
- Repository: goal repository
- Data sources: local store, sync pipeline
- Services: analytics + error logging

## Errors
- Invalid goal data
- Save failure

## Fallback
- Prevent invalid commit
- Keep local pending state for retry

## Analytics Event
- goal_created
- goal_updated
- goal_completed
