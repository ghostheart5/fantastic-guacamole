# FIX-007 — First-class Note domain authority

## Decision

`NoteEntity` is a first-class, account-owned domain entity. It is not a
`TaskEntity`, is not actionable planning work, and receives neither reminder
ownership nor Profile/Progression credit.

Canonical fields are `id`, `title`, `body`, `createdAt`, `updatedAt`, optional
`goalId`/`taskId`/`habitId`, `isArchived`, and optional `userId` metadata.

## Authority graph

| Concern | Authority | Boundary |
| --- | --- | --- |
| Durable Note truth | `NoteRepository` | Hive box `notes_v2.<AccountStorageScope.v2Namespace>` |
| Runtime state and commands | `notesProvider` / `NotesNotifier` | Account-scoped, signed-out fail-closed |
| Creator | `CreatorActions` | Sends the canonical Note command only |
| Notes UI | `NotesScreen` | Presentation and notifier commands only |
| Timeline | `NoteTimelineAdapter` | Best-effort projection, never durable Note truth |
| Sync | `SyncMutationDispatcher` / queue | Replication after local persistence |
| Remote transport | `NotesRemoteGateway` | Owned `notes` table transport only |
| SI | `siNoteContextProvider` | Read-only `SIContextEntityType.note` context |

No active Note consumer writes directly to Hive, `TaskRepository`, a sync queue,
a Timeline repository, or the remote gateway. The Notes UI exposes loading,
empty, populated, error/retry, view, edit, and archive behavior with Note
accessibility labels/tooltips. It has no Task completion, due-date, priority, or
streak controls.

## Account and lifecycle behavior

The repository is constructed from `AccountStorageScope`; an unavailable
repository throws while signed out. A retained repository or sync dispatcher
remains bound to its original account and cannot write another account’s scope.
The normal owner policy is unchanged: A→signed-out and signed-out→A are allowed;
A→B and retained-A→B are rejected until the certified lifecycle handoff permits
them. Restart restores only the current account’s Note box and queue.

Legacy Task-backed Note records are deliberately preserved, inactive,
unclaimed, unread, unwritten, and unmigrated. There is no fallback to those
records and no automatic migration.

## Timeline and sync

Create, update, archive, and repository-level delete can be projected using
`noteCreated`, `noteUpdated`, `noteArchived`, and `noteDeleted`. Projection IDs
are deterministic:

`note:<note-id>:<mutation>:<updated-at-utc-microseconds>`

Projection failure cannot roll back canonical Note persistence. The current
implementation treats Timeline projection as best effort; it does not maintain
a separate durable projection retry ledger.

Local Note persistence occurs before an account-owned sync mutation is queued.
The replication table is `notes`; payloads carry canonical Note values and
ownership is enforced by `NotesRemoteGateway` against the authenticated user.
Delete is a remote soft delete. Retryable remote failures retain generic queue
retry/backoff metadata; fatal failures retain the existing fatal classification.

`SupabaseSyncExecutor.apply` awaits all six registered asynchronous dispatch
branches (Tasks, Goals, Habits, HabitOccurrences, Settings, Notes) inside its
existing classifier. This ensures asynchronous PostgREST/network failures are
classified as the existing `SyncApplyResult` rather than escaping the queue
contract.

## SI, planning, and reminders

`SINoteContext` is typed as `SIContextEntityType.note`. Active Notes are
read-only SI context; archived Notes are excluded. Notes do not become Tasks,
Goals, Habits, or Smart Planner actionable items. No SI provider has Note write
authority, and `si_pipeline_provider.dart` remains unchanged.

Voice Note intent is supported only through the existing Creator handoff; there
is no direct voice persistence bypass. Notes have no reminder integration and
do not affect Profile/Progression.

## Deferred product decisions

- Note reminders
- Note-to-Task conversion
- User-confirmed migration of legacy Task-backed Notes

## Certification

| Group | Tests |
| --- | ---: |
| FIX-007A core authority | 18 |
| Notes UI | 2 |
| FIX-007B Timeline/Sync/gateway | 8 |
| SI Note context | 1 |
| Exact staged candidate | 193/193/0 |
| Targeted analyzer | 0 diagnostics |

All tests in the exact staged candidate, plus its targeted analyzer, must pass
before the FIX-007 commit is created.
