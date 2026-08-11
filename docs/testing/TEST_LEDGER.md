# ChronoSpark test ledger

Date: 2026-08-11  
Scope: Phase 4 behavior-first unit and widget coverage  
Source inventory: `ADVANCED_TEST_PLAN.md` (the four legacy ledger documents named
by the Phase 0 request are not present in this checkout).  `AGENTS.md` is present
but empty.

## Coverage inventory

| Feature | Existing evidence | Missing/weak evidence | Primary owner | Blocking | Future test | Priority | Approx. runtime |
|---|---|---|---|---|---|---|---|
| Nexus | `features/nexus/unit`, route integration | No runtime empty/loading/partial/error/offline or persistence matrix; route checks are structural | Nexus | Amber | Provider-backed widget state matrix and restart journey | P1 | <1s |
| Creator | mode unit, route integration, release/behavior contracts | No runtime create/validate/retry/idempotency matrix for all item kinds | Creator | Amber | Device-backed Creator-to-Timeline journey | P1 | <2s |
| Timeline | entity/unit and route integration | No runtime lifecycle matrix or provider failure/retry coverage | Timeline | Amber | Timeline widget with persisted projections and action recovery | P1 | <2s |
| Trajectory | deterministic unit fixtures and provider-overridden widget integration | Complete scenario coverage exists; empty/loading/partial/error/offline/stale semantics are missing | Trajectory | Amber | Snapshot-state widget matrix and scenario labeling | P1 | <2s |
| Progression | policy/unit and route integration | No repeated-award persistence or downstream aggregate behavior | Progression | Amber | Restart and reward idempotency integration | P1 | <1s |
| Profile | ProfileHeader/ProfileScreen widgets | Limited failure/loading/offline input and repeated navigation coverage | Profile | Amber | Auth/session lifecycle widget matrix | P1 | <2s |
| Settings | permission model/provider unit and screen tests | No persistence/retry/offline or max/Unicode input matrix | Settings | Amber | Platform permission and process-death coverage | P1 | <2s |
| Smart Planner | isolated input/output and structural prompt/release contracts | No network-free state/fallback/retry matrix; chat isolation must remain explicit | Smart Planner | Amber | Fake proxy and request-budget evaluation | P1 | <2s |
| SI Console | command/placeholder unit, context assembly, integration/contract tests | No complete source-state/retry/idempotency matrix; chat isolation must remain explicit | SI Console | Amber | Fake proxy grounded-response evaluation | P1 | <2s |

### Classification of current evidence

- Runtime unit behavior: domain entity, policy, provider, repository, and
  controller tests; the new Phase 4 matrix is the focused addition.
- Widget behavior: Profile and Trajectory widget tests; existing screen tests
  remain in place and are not deleted.
- Source/structural contract: `test/behavior`, `test/release`, navigation and
  source-inspection tests. These are drift guards, not runtime proof.
- Integration: feature integration tests and canonical in-process journeys.
- Device integration: `integration_test/` and Patrol assets; not run in Phase 4.
- Maestro/E2E: `maestro/`; not run in Phase 4.
- Backend/security: Supabase and staging assets; not run in Phase 4.
- Accessibility: dedicated accessibility/contract tests; not run in Phase 4.
- Performance: performance assets; not run in Phase 4.
- Fuzz/chaos: monkey/fuzz assets; not run in Phase 4.
- Human/UAT: governed human-root plan is documented, but no live UAT run is
  part of this phase.
- Release guard: workflow/release contract tests; not run in Phase 4.

## Phase 4 addition

Added `test/behavior/phase4_behavior_matrix_test.dart` as test-only coverage.
It uses deterministic timestamps, fixed IDs, real domain entities, a fake
provider/store with explicit empty/loading/success/partial/error/offline states,
and idempotent retry behavior. It covers Creator item construction and input
boundaries, Timeline validation/order/status, Nexus aggregate completeness,
Trajectory cold-start versus complete summaries, Progression boundaries,
Profile widget interaction, Settings permission state, and isolated Smart
Planner/SI Console local output behavior.

No production, persistence implementation, chat, endpoint, credential, or
workflow file was changed.

## Phase 4 validation record

- Targeted command: `flutter test test/behavior/phase4_behavior_matrix_test.dart`
- Result: timed out after 120 seconds in this environment before producing a
  test report. No full suite was run.
- A follow-up `dart test`/format attempt also did not produce output and was
  stopped; this is recorded as an environment warning, not a product failure.
- Pass/fail/skip counts: unavailable because the runner did not initialize.
- Warnings: Flutter/Dart test runner initialization timeout.

## P0 blockers carried forward

1. No current head-level release evidence until the repaired workflow executes.
2. Device/Maestro/backend/UAT layers remain disconnected from this unit/widget
   phase.
3. The existing worktree contains unrelated user changes; they were preserved
   and excluded from the Phase 4 change set.
