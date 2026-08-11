# Phase 10 property, fuzz, Monkey, and chaos testing

Version: 1.0.0
Status: implemented local harness; device and staging cases NOT RUN

## Safety boundary

Phase 10 does not contact production, staging, a store, or a chat feature. The
local property suite is deterministic and uses only in-memory fakes and live
pure/domain/provider code. Android Monkey is an explicit device command, never
a CI side effect or local test side effect.

Historical Monkey seeds 260726, 260801, 260802, and 260803 were recovered from
old artifacts. Their historical runs ended with nonzero exit codes, so they are
replay/investigation inputs only, never passing evidence.

## Local deterministic coverage

The fixed seed bank exercises recurrence values, task serialization and
rescheduling fields, goal transitions, habit/routine/note round trips, Timeline
ordering, Unicode/emoji and 0-to-4096-character boundaries, malformed task and
sync payloads, retry queues, duplicate/final-outcome behavior, XP/level bounds,
and deterministic Trajectory simulations.

The enforced invariants are:

1. A second task-completion attempt cannot award a second progression update.
2. A rescheduled task retains its identity and scheduling data through a round
   trip.
3. A successful retry removes exactly its one queued operation.
4. Timeline ordering is monotonic for the selected time comparator.
5. Valid entity serialization preserves required identity and lifecycle data.
6. A retry for User A does not alter User B's queued operation.
7. A queue storage failure leaves the original operation present and the runner
   can subsequently produce one final result.

These local properties are not proof of remote authorization or deployed
backend behavior. User A/User B database isolation remains a Phase 8
approved-staging requirement.

## Deterministic fault-injection design

| Fault | Local-safe representation | Device/staging status |
|---|---|---|
| latency, packet loss, offline, DNS failure, timeout | Retryable SyncApplyResult fixture | Device network proxy/radio run pending |
| HTTP 401, 409, 429, 500 | Retryable response-category fixture | Staging pending explicit approval |
| HTTP 403 | Fatal/unauthorized response fixture | Staging authorization test pending |
| malformed JSON, missing fields | SyncOperation decode failure | Local deterministic test |
| duplicate or out-of-order response | Deterministic retry/final-outcome fixture | Device/server protocol run pending |
| partial write, local storage failure, disk full | Queue-update failure fixture; disk-full device test pending | Local partial-write test only |
| plugin failure | Retryable category fixture | Patrol/device test pending |
| process death | Recovery invariant design only | Dedicated device run pending |
| clock skew | Fixed generated timestamps | Device time-change run pending |

No planned fault case is recorded as passing until the corresponding local or
device command completes against its declared target.

## Android Monkey levels

Profiles live in tool/chaos/phase10_monkey_profiles.json:

| Level | Events per seed | Seed policy | Purpose |
|---|---:|---|---|
| PR smoke | 1,000 | Two recorded seeds | Explicit opt-in device smoke only |
| Nightly | 10,000 | Three recorded seeds | Feature resilience campaign |
| Pre-release | 50,000 default; may be raised to 100,000 | Five recorded seeds | Candidate resilience campaign |

Every level uses a distinct documented touch/motion/navigation/app-switch
distribution and disables system-key events. A device run is allowed only when
the APK's package ID ends in .maestro, .staging, .debug, or .test. This blocks
the production package even if an operator supplies it by mistake.

Example planning command, which does not execute events:

    pwsh ./tool/chaos/run_phase10_monkey.ps1 -Level pr-smoke -ApkPath <isolated-apk> -DeviceId <adb-id>

Add -Execute only after the isolated candidate, device, and operator are
explicitly approved. A nonzero Monkey exit, crash, ANR, or native crash creates
a replay-command.txt file containing the exact seed, count, APK path, device,
and level. Replays are explicit and never silently retried.

## Required Monkey evidence

Each run metadata record contains the seed, event count, application ID, binary
SHA-256, device, OS, event distribution, crash result, ANR result, native-crash
result, dropped-event count, final state, and replay flag. Logs and metadata
are diagnostic artifacts, not approved visual baselines or release passes.

## Commands

Local deterministic suite only:

    flutter test test/phase10

PowerShell parser validation only:

    powershell.exe -NoProfile -Command "Invoke-ScriptAnalyzer is not required; [void][scriptblock]::Create((Get-Content -Raw ./tool/chaos/run_phase10_monkey.ps1))"

Neither command contacts a network or launches Monkey.
