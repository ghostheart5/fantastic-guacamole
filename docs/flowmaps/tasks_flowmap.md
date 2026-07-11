# Tasks FlowMap

## Trigger
User creates, completes, skips, edits, or deletes a task.

## Flow
1. Task action is initiated from Task/Plan screen.
2. Task provider validates operation.
3. Task use case executes domain mutation.
4. Repository writes task state.
5. Side effects execute (learning, logs, timeline, notifications).
6. SI/coach decision is refreshed.
7. UI list/plan updates.
8. Analytics event is logged.

## Data and Services
- Screen: Tasks screen / Plan screen
- Provider/Controller: task provider/actions
- Use case: create/complete/skip/update/delete task
- Repository: task repository
- Data sources: Hive local + sync pipeline
- Services: analytics, notifications, error handling

## Errors
- Task not found
- Save/update failure
- Side-effect failure

## Fallback
- Core mutation prioritized; side effects are best-effort
- UI refreshes from latest available state

## Analytics Event
- task_created
- task_completed
- task_skipped
- task_deleted
