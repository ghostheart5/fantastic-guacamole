# Candidate 3030 repair and release validation

App source: `9cc17c549b18bf319dae757070e5f52c6d425711`. Version: `4.1.0+2026083030`. The SI repairs distinguish actual goal-ranking evidence and ties, support bounded saved-record listing, isolate explicit topic changes from unrelated earlier planning context, retain safety screening of recent conversation, and remove duplicated punctuation. Six new regression cases are included in the full suite.

Signed candidate run: `34651614444`, build tooling `a529a415b1201aef2c0da687098d0e612200d8d9`. AAB SHA-256: `5eb6cb4cba8d462ef6af93d4e730d059cf4e0e08a06160a9ce69d4493c70c3b0`. Artifact `10284034790` has independently verified archive SHA-256 `f693d23648bbb5e6f83a08d648b37c9d8c2a04f83617689363de81f9bbc2467d`. Bundle source/version, every signed payload entry, pinned upload certificate, nine legal notices, mapping and nine matching native-symbol pairs were inspected. Three vendor DataStore libraries retain their documented full-debug-symbol limitation.

## Verified automated results

| Gate | Result and exact evidence |
|---|---|
| Source CI | PASS — run `34650514976`: 2,916 Flutter tests, 15 QA configuration cases, 48 Windows visual checks, 17 launcher checks and 8 Linux integration cases. Static analysis, policy and coverage gates passed. |
| Database | PASS — run `34650516835`: 13 SQL files / 350 cases and 142 Edge Function tests. SQL terminal summary and artifact JUnit independently checked. |
| Full Windows suite | PASS — run `34652851508`: 2,919 tests and 15 QA configuration cases. Raw JSONL independently recounted. |
| Native Android | PASS — run `34652851508`: 15/15 across five independent hosts. Raw instrumentation reports, source hashes, provenance, zero-skip counts and owned-process cleanup independently checked using the original tooling parser. |
| Maestro journeys | PASS — run `34650519352`: 11/11 journeys, zero fatal markers. |
| Hosted Monkey | PASS — same QA workflow: five variants, 1,700 injected events, zero fatal markers, successful relaunch after each variant. No Monkey ran on the owner phone. |
| Decision volume | PASS — 60 deterministic scenarios, each containing 1,000 mixed tasks. Valid/finite recommendations, terminal-task exclusion, unchanged input records and repeat determinism checked. These are 60 fixture scenarios, not 60,000 user journeys. |
| Strict 16 KB | PASS ? repaired-tooling run `34654390861`, actual 16384-byte pages, compatibility fallback disabled, onboarding-to-login 1/1, zero fatal markers and complete owned-process cleanup. |

All passing test reports above contain zero failures, errors or skips within their named test suites. Workflow branches for operations not selected are not test cases. Counts across platforms overlap and must not be summed as unique product scenarios.

## Strict 16 KB runner failures and repair

The original post-build workflow remains **failed**, because strict 16 KB job `103438766242` timed out in Maestro launch setup before the onboarding assertions. The initial release cold-launch observation passed without fatal markers. Android had processed the disposable app-data clear; the captured command trace does not establish the precise cause of Maestro's subsequent stall. Failed artifact `10285395480` was SHA-verified and retained; owned emulator, ADB server and collector cleanup passed.

One unchanged isolated repeat, `34653708268`, failed earlier: the runner checked `pidof` immediately after `am force-stop`, while Android was still terminating the process. Failed artifact `10284298504` was SHA-verified and retained. This is distinct from the first Maestro stall, and does not retroactively explain it.

Tooling commit `44f7931e3033b15b3229cd91b2111a17ff453403` adds a ten-second maximum process-termination wait before the existing onboarding reset. It invokes force-stop once, requires actual process absence, rejects invalid ADB output, records every sample and refuses an unowned phone. All 60 runner contract tests passed, including four new boundary cases. The immutable app/flow, emulator/image, strict page-size configuration, onboarding assertions and 180-second Maestro timeout remain unchanged. Repaired strict-only run `34654390861` passed. Artifact `10284978686` was SHA-verified and its actual page-size, strict configuration, same AAB hash, unchanged flow hash, zero-skip JUnit, login screenshot/readback and cleanup receipts independently reconciled. This host observed process absence on its first sample; the delayed-exit branch has contract coverage, not a claim that this host reproduced the race. This tooling-only change does not rebuild or alter the signed AAB.

## Store and installed-device status

The inspected AAB was published to internal release 32 after all named automated gates had passing evidence. Authenticated Console readback confirms version 2026083030, Available to internal testers, September11 at5:40PM. The Moto updated through Google Play; Android independently reports3030 with installer `com.android.vending`, owner user0 and update time17:41:01. Initial app readback retained level20,36212XP and1448 completed tasks. No uninstall, data clearing or sign-out occurred. The installed human acceptance scenarios are still running; older device results remain separately attributed.

## Production boundary

Production remains inactive and has not been published. The private internal billing candidate is not an approved public paid configuration. Qualified signed privacy/legal and mental-health/AI-safety dispositions remain missing under the project's existing release register. The reviewer has current, account-bound complimentary access and 300 credits, but its separate Android user 11 still requires owner setup choices and a complete reviewer-device journey. Public eligibility across client/backend/build preflight, final disclosures/listing/Data safety and production-access approval still require reconciliation after those prerequisites. No approval or public activation is inferred from passing engineering tests.

Compact current receipts are under `test-results/release-3030`. The signed AAB is retained under `artifacts/releases/4.1.0-2026083030-internal-billing-verified/candidate`. Strict 16 KB is complete; installed-device results below remain separately attributed.

## Installed human acceptance and next candidate

The Moto passed four paired energy/fatigue boundaries with Home/Trajectory agreement and restored cleared vitals, explicit goal ties, six-goal/two-task/empty-milestone listing, referential follow-up, explicit-topic evidence isolation, and single-period person-context citations. Smart Planner selected the existing bookkeeping task for a five-minute school-pickup scenario. These observations are captured under `test-results/stress-3027-20260911/installed3030-*`.

Two additional SI routing findings prevent claiming this candidate fully passed: S13, the natural question ?What can I do in five minutes before school pickup to review a bookkeeping example?? was classified unsupported; S14, ?Will it rain tomorrow?? incorrectly used the generic schedule keyword and answered with an unrelated task. The 3031 repair adds bounded available-action phrasing and rejects weather requests before generic schedule routing. Saved weather-related goals remain supported. Two new regression cases cover eight input variants plus a saved-goal control. The focused engine/device/safety suite passed 29 tests; scoped analysis and formatting passed. Hosted 3031 and installed 3031 results are not inferred from these local checks.
