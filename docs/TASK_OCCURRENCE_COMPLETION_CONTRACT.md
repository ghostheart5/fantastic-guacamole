# Task occurrence completion contract

This is the governing contract for task occurrence completion, skip, and
reschedule behavior.

## Authority decision

`task_occurrences` is an active-replication design:

- local authority: account-scoped Hive `task_occurrences_v2`;
- cloud replica: Supabase `public.task_occurrences`;
- pending operation state is local-only recovery state;
- committed transitions replicate as immutable SQL rows.

The Supabase table is not a future placeholder and not merely a backup export.
If cloud replication fails, local completion remains authoritative and later
sync may replay the immutable transition by `operation_id`.

## Completion-result boundary

Only an `applied` occurrence mutation may trigger one-time side effects:

| Outcome | Reward | Learning | Analytics | Log | Timeline | Guidance | Notification | Event |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| applied | yes | yes | yes | yes | yes | yes | yes | yes |
| idempotent | no | no | no | no | no | no | no | no |
| conflict | no | no | no | no | no | no | no | no |
| blocked | no | no | no | no | no | no | no | no |

Read-model invalidation is allowed for every outcome so the UI converges to the
current durable state without duplicating rewards or history.

## Crash convergence

| Failure point | Expected local state | Recovery |
| --- | --- | --- |
| Before pending ledger write | No committed occurrence. Task remains unchanged. | User-triggered retry. |
| After pending ledger write | `pendingOperation` exists; task may still be unchanged. | Automatic convergence on retry using the same operation. |
| After task-state write | Task may show completed/skipped/rescheduled before final ledger. | Automatic convergence on retry; no new operation is created. |
| After successor write | Recurring successor may already exist. | Automatic convergence on retry; successor identity prevents duplicates. |
| After final ledger write | Terminal transition exists. | Duplicate retries are idempotent and side effects stay suppressed. |

## Local-to-SQL mapping

| Local field | SQL field | Rule |
| --- | --- | --- |
| `TaskOccurrence.id` | `id` | Row ID unique inside `user_id`. |
| `transition.operationId` | `operation_id` | Replay equality key. Duplicate operation IDs are ignored. |
| `taskId` | `task_id` | Required, non-blank. |
| `occurrenceKey` | `occurrence_key` | Required, non-blank. |
| `initialScheduledFor` | `original_schedule_identity` | UTC instant for the original scheduled slot. |
| `transition.at` | `resolved_at` | UTC commit instant. |
| `transition.rescheduledFor` | `rescheduled_to` | UTC target instant for reschedules. |
| `pendingOperation` | none | Local-only recovery state; never exported as committed SQL. |

## Timezone semantics

- Occurrence identity is based on the task's user-visible scheduled slot at
  mutation time, stored as an instant.
- SQL and local JSON persist instants as UTC ISO-8601/timestamptz values.
- DST gap: a nonexistent wall-clock schedule must resolve to the next valid
  local instant before mutation.
- DST overlap: the selected instant is retained; replay equality uses
  `operationId` and `occurrenceKey`, not formatted clock text.
- Travel/device timezone changes do not rewrite committed occurrence identity.
- Future scheduling may use the user's current planning timezone, but committed
  transitions remain immutable.

## Occurrence-specific offline order

Occurrence mutations cannot rely on full-backup object ordering. Queue items
must preserve this order:

1. pending-ledger
2. task-state
3. successor-task, when recurring
4. final-ledger
5. immutable cloud-replica upsert

## Account-transition matrix

| Pause point | Provider/account transition rule |
| --- | --- |
| Before pending ledger | Do not start while account storage scope is unsafe. |
| After pending ledger | `cancelAndDrain` waits for the queued mutation; after process death, retry resumes from pending. |
| After task-state write | Drain waits for the final ledger; process-death recovery finalizes on retry. |
| After successor write | Drain waits for final ledger; retry must not duplicate successor. |
| After final ledger | Account transition may continue after read-model invalidation. |

## Edge-case matrix

Priority cases:

- duplicate completion suppresses all one-time side effects;
- skip/complete races produce one applied outcome and one conflict;
- reschedule records `rescheduled_to` and does not create reward side effects;
- successor-write failure leaves pending operation for automatic retry;
- final-ledger failure leaves task/successor state recoverable by retry;
- DST gap/overlap/travel/timezone-change never rewrite committed occurrence
  identity.

## Series identity

Recurring series identity, task-instance identity, and occurrence identity are
separate:

- series identity: stable parent recurrence concept; future cross-device work
  should add an explicit series ID rather than deriving it from a task row;
- task instance ID: concrete local task row;
- occurrence key: stable actionable slot for one scheduled occurrence;
- operation ID: idempotency key for one user mutation on one occurrence.
