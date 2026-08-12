# Flaky-test control policy

Version: 1.0.0
Status: active governance policy

## Definition and evidence threshold

A test is flaky when the same immutable revision and declared environment show
both a pass and a failure without an intentional source, fixture, or environment
change. A suspected flake becomes a registry entry after either two intermittent
failures, or one pass/fail/pass sequence, across at least three recorded runs.
A timeout, device disconnect, or unavailable dependency is not silently called a
flake: record it as blocked with the exact environment evidence.

Every registry entry must identify a test owner, first-seen date, reproduction
command, affected environments, suspected cause, linked defect (or an explicit
investigation reference), and the retained replacement coverage. Record the
original failure log/artifact before any evidence-gathering retry.

## Failure and retry rules

- Critical release tests are blocking. Their first failure remains visible and
  must fail the candidate; an automatic retry may gather evidence but cannot
  erase, overwrite, or convert that failure into a pass.
- A non-critical retry may classify intermittence, but the original result and
  attempt count remain attached to the result record.
- A quarantine requires a named owner, reason, expiry date, linked defect, and
  stronger or equivalent replacement coverage. There is no permanent
  non-blocking exception.
- An expired quarantine blocks release until renewed with new evidence or
  resolved. Quarantined critical coverage still requires its replacement pack.
- A skipped test requires a reason, named reviewer, and review date. A skipped
  result is pending for release purposes unless an approved non-applicable
  decision is documented.
- A conditional test states its exact execution command, required define/device
  or environment, and terminal assertion. A condition cannot become an optional
  pass.

## Quarantine lifecycle

1. Preserve the first failing evidence and open/link the defect.
2. Assign an owner and reproduce with the recorded command where possible.
3. Add a time-limited quarantine entry only after the release owner accepts the
   risk and replacement coverage is identified.
4. Reassess before expiry. Resolve by fixing the test/product defect and
   retaining a stable result history; otherwise renew explicitly with new
   evidence. Expiry without resolution is release-blocking.

## Regression packs

| Pack | Purpose | Selection rule | Blocking rule |
|---|---|---|---|
| PR critical | Fast, deterministic risks from changed files plus architecture/release guards | `select_phase12_tests.ps1 -Mode pr` | Critical first failures block; no silent retry |
| Feature | Full behavior/unit/widget pack for each changed product area | Owner mapping plus feature dependencies | Required before feature merge |
| Nightly full | Full Flutter, structural, performance-contract, and available nonproduction layers | All packs, no changed-file reduction | Failures triaged next business day |
| Pre-release | Complete suite, device/Maestro/staging/human gates where applicable | Always `test`; never selection-reduced | Every required gate is blocking |
| Post-release monitoring | Crash/ANR, auth, sync, payment, notification, and release-veto signals | Exact released binary/environment | P0/P1 starts incident process |

## Duplicate-analysis process

Compare tested behavior and failure mode, not filenames. The ledger identifies
one primary owner per behavior, while tests at different layers remain when they
prove different risks (for example, a source contract versus runtime behavior,
or a unit transition versus a real-device journey). Record runtime, failure
yield, dependency/fixture cost, and unique assertion in the duplicate registry.

A deletion is only a proposal after equivalent or stronger replacement coverage
is proven by current execution evidence. The behavior owner and release owner
must approve it. This policy does not authorize automatic deletion, merging, or
weakening of tests.
