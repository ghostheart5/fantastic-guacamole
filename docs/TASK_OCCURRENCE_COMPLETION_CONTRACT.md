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
If cloud replication fails, local completion remains authoritative. The
account-scoped occurrence record retains the operation ID in its cloud outbox.
Explicit retry, process restart recovery, or an idempotent replay uses that
same operation ID until the immutable Supabase upsert is acknowledged. A
successful remote upsert followed by a local crash is safe because retry uses
the same unique key.

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
| `TaskOccurrence.id` + `transition.operationId` | `id` | Immutable transition-row ID unique inside `user_id`. |
| `transition.operationId` | `operation_id` | Replay equality key. Duplicate operation IDs are ignored. |
| `taskId` | `task_id` | Required, non-blank. |
| `seriesId` | `series_id` | Stable across generated recurring task instances. |
| `occurrenceKey` | `occurrence_key` | Required, non-blank. |
| `initialScheduledFor` | `original_schedule_identity` | UTC instant for the original scheduled slot. |
| `transition.at` | `resolved_at` | UTC commit instant. |
| `transition.rescheduledFor` | `rescheduled_to` | UTC target instant for reschedules. |
| `pendingOperation` | none | Local-only recovery state; never exported as committed SQL. |
| `pendingCloudOperationIds` | none | Account-scoped local outbox; cleared only after remote acknowledgement. |

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
5. durable cloud-outbox entry inside the final ledger
6. immutable cloud-replica upsert
7. local outbox acknowledgement (safe to replay)

## Account-transition matrix

| Pause point | Provider/account transition rule |
| --- | --- |
| Before pending ledger | Do not start while account storage scope is unsafe. |
| After pending ledger | The old account stops at the next boundary; later retry resumes from pending. |
| After task-state write | The old account stops before successor/final writes; retry converges. |
| After successor write | The old account stops before final ledger; retry must not duplicate successor. |
| After final ledger | The old account cannot replicate under a new auth user; the durable cloud outbox remains. |

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

- series identity: stable parent recurrence concept persisted as `series_id`;
- task instance ID: concrete local task row;
- occurrence key: stable actionable slot for one scheduled occurrence;
- operation ID: idempotency key for one user mutation on one occurrence.

Mutation serialization is keyed by account namespace and task ID, not by one
coordinator object. Two provider containers or overlapping coordinator
lifetimes therefore converge through the same in-process lock. Every awaited
persistence boundary rechecks account ownership.

Malformed ledger members are isolated into the bounded account-scoped
`task_occurrences_v2_quarantine` record. Valid occurrence members remain
readable; malformed records are never silently rewritten into valid outcomes.
