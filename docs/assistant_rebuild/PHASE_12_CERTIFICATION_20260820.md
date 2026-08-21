# Assistant rebuild Phase 12 certification

Date: 2026-08-20

Implementation branch: `codex/phase12-launch-certification-20260820`

Verified source head: `aec3d791cbd1769cfbfd78685e1f92c48d83bc88`

## Decision

- Implementation certification: **passed**
- Automated rebuild verification: **passed**
- Production launch authorization: **awaiting live evidence**

The implementation is complete and the available local gates passed. Production
launch is intentionally not declared from local tests: the executable Phase 12
gate requires three consecutive production evidence windows with at least 1,000
sessions each. No synthetic values were recorded as production evidence.

## Phase lineage and implementation result

| Phase | Commit | Verified result |
|---:|---|---|
| 1 | `5946f0b4` | Planner and SI runtimes isolated |
| 2 | `b738cb6e` | Typed request, response, and evidence boundaries |
| 3 | `e8780d95` | Immutable evidence plane with provenance and freshness |
| 4 | `c9dafada` | SI shortcuts unified with explicit argument preservation |
| 5 | `798689f8` | Read-only Planner V2 contract and options |
| 6 | `9daa4f43` | Creator preview, explicit confirmation, receipt, and undo |
| 7 | `91028cc7` | Read-only SI V2 evidence lens and inspectable analysis |
| 8 | `75f34725` | Account- and surface-scoped governed memory |
| 9 | `71f39be5` | Deterministic safety validators and bounded critic |
| 10 | `5f93f17e` | Semantic controls, large-text reflow, speech, and recovery |
| 11 | `8edde268` | Internal/beta/canary cohorts and four rollback switches |
| 12 | `d3900827` | Executable implementation and live-launch certification gate |

Post-certification integration fix `aec3d791` aligned the Phase 9 injection
marker with the current product terminology contract without weakening the
adversarial safety suite.

## Verification evidence

The repository verifier `tool/verify_assistant_rebuild.ps1` completed from the
verified source head with these results:

| Gate | Result |
|---|---|
| Phase 1-11 ancestry and exact commit subjects | Passed |
| `check_architecture.ps1` | Passed; no boundary violations |
| `flutter analyze --no-fatal-infos` | Passed; zero issues |
| Full `flutter test` suite | Passed; 1,318 tests, zero failures |
| Android debug build | Passed; `build/app/outputs/flutter-apk/app-debug.apk` |
| Phase 9 adversarial injection-to-action matrix | Passed; 10,000 combinations, zero successful action claims |
| Phase 10 200% text and semantic widget checks | Passed |
| Phase 11 10,000-account deterministic canary assignment | Passed |
| Phase 12 fail-each-gate certification tests | Passed |

The first full-suite attempt correctly found one retired terminology occurrence
in the Phase 9 policy. It was fixed, the safety and product-canon suites passed,
and then the complete 1,318-test verifier was restarted and passed.

## Live gates still required for production authorization

Each of three consecutive production windows must carry evidence for every gate:

- cross-surface or cross-account leakage: 0
- unconfirmed writes: 0
- SI writes: 0
- fabricated critical facts: 0
- provenance coverage: at least 99%
- shortcut argument loss: 0
- hidden memory: 0
- deleted-memory retrieval: 0
- injection-to-action success: 0
- explicit corrections honored: 100%
- crisis XP, streak, or planning-pressure side effects: 0
- critical accessibility defects: 0
- crash-free sessions: at least 99.9%

The gate also requires the independent Planner V2, SI V2, governed-memory, and
safety-critic rollback switches. Missing metrics, missing evidence identifiers,
an undersized window, a gap/overlap, or any failed threshold denies launch.

## Verification boundary

The passed local accessibility checks do not substitute for a physical-device
TalkBack review. The successful debug APK is build evidence, not Play Store
release evidence. Crash-free sessions and sustained cohort metrics can only be
verified after a controlled deployment. Phase 12 reports those limits as
`awaitingLiveEvidence` instead of inventing a launch pass.
