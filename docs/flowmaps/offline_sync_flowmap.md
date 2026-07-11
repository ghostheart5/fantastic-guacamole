# Offline Sync FlowMap

## Trigger
Network state changes or queued offline operations are available.

## Flow
1. Sync provider detects connectivity or manual sync request.
2. Offline queue is loaded.
3. Operations replay to remote endpoint in order.
4. Successful operations are removed from queue.
5. Failed operations are retained with retry metadata.
6. UI sync status updates.
7. Diagnostics/analytics events are logged.

## Data and Services
- Provider/Controller: sync provider/queue service
- Use case: enqueue, replay, reconcile
- Repository: offline queue + affected feature repositories
- Data sources: local queue store + remote API/Supabase
- Services: connectivity, analytics, error logging

## Errors
- Network timeout
- Remote validation failure
- Conflict during reconciliation

## Fallback
- Preserve queue, exponential retry, user-visible sync state

## Analytics Event
- sync_started
- sync_operation_succeeded
- sync_operation_failed
- sync_completed
