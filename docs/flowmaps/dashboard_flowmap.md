# Dashboard FlowMap

## Trigger
User enters coach/home shell and requests current system status.

## Flow
1. Dashboard/home screen loads.
2. Providers fetch active signals (energy, trajectory, tasks, goals).
3. SI decision output computes next recommendation/advice.
4. UI panels render summary and quick actions.
5. User action routes to feature modules.
6. Interaction events are logged.

## Data and Services
- Screen: SmartCoach/Home shell
- Provider/Controller: SI pipeline + feature providers
- Use case: aggregate state + generate dashboard output
- Repository: tasks/goals/memory/timeline/profile repos
- Data sources: Hive local + synced remote sources
- Services: analytics + error boundary

## Errors
- Partial provider failure
- Stale data

## Fallback
- Render degraded dashboard with available providers
- Display safe fallback advice

## Analytics Event
- dashboard_opened
- dashboard_quick_action_selected
