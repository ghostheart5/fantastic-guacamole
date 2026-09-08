# Internal 3018 final validation

Follow-up: the pending-refund-review implementation and expanded provider-failure tests are completed in the [billing follow-up report](BILLING_REVIEW_AND_PROVIDER_FAILURE_COMPLETION_20260908.md). The historical observations below retain their original build and evidence boundaries.

Status: the scoped automated suites, internal release/update, pending-payment instruments, credit-spending checks, and final Moto acceptance passed. Evidence limits below remain explicit; monkey and level-20 testing are excluded.

## Release identity

- App source: `676b19d1855c66d060b3a4994edeb576f46041c0`.
- Version: `4.1.0+2026083018`; package `com.ghostheart5.chronospark`.
- [Signed build 34189228248](https://github.com/ghostheart5/fantastic-guacamole/actions/runs/34189228248), attempt 1, passed.
- AAB SHA-256: `70e98a28ea97b46cc24b7959476465327c661ef840cb193e365d037e668a6d28`; 77,863,886 bytes.
- Local checksum, signature, package/version, target API 36, billing permission, source/CI binding, and two-account test policy verification passed. The canonical AI endpoint and internal credit panel were present in compiled ARM64 code.
- Google Play internal release 20 reports Available to internal testers. Only 3018 is included; no supported-device loss was reported. No production-track release was made.

## Automated evidence

[CI 34188353636](https://github.com/ghostheart5/fantastic-guacamole/actions/runs/34188353636) passed on the exact app source. Retained manifests report:

| Check | Passed | Failures / errors / skips |
|---|---:|---|
| Flutter unit and widget suite | 2,581 | 0 / 0 / 0 |
| Windows checks including golden comparisons | 40 | 0 / 0 / 0 |
| Windows Maestro launcher contracts | 16 | 0 / 0 / 0 |
| QA configuration checks | 15 | 0 / 0 / 0 |
| Linux app integration | 8 | 0 / 0 / 0 |

Static policy, analysis, architecture, release and coverage gates also passed. These test groups overlap; they are not a count of distinct features or 100 percent code coverage.

[Database 34188356789](https://github.com/ghostheart5/fantastic-guacamole/actions/runs/34188356789) passed 341 pgTAP assertions and 99 Edge Function tests, plus schema lint and migration replay checks.

[Maestro 34188355051](https://github.com/ghostheart5/fantastic-guacamole/actions/runs/34188355051) passed all eleven ordered QA journeys with zero failures/errors/skips and zero fatal markers on a disposable Android 15/API 35 emulator. Its exact-source QA APK SHA-256 is `95D2A60D1BDB7148C29B1ECB897D97DF679387CEA3EB230CCFB05F2D4E6849FF`. The suite covers Planner, Creator, SI Console, Timeline, Progression, Settings, containment, logout, account isolation, learning lifecycle, and restart readback. This isolated QA build is separate from real Play Billing evidence.

## Live payment and credit evidence

The detailed [3017/3018 repair report](INTERNAL_3018_PREPAID_REPAIR_20260908.md) records the real Moto tests against the repaired backend:

- Slow decline: pending/restart/Restore preserved access and balance; fresh cancellation notifications processed without errors after repair.
- Slow approve: restart and Restore explicitly remained pending with inactive access and zero credits; completion filled the paid allowance to 300 exactly once; expiry removed paid access and returned the configured free allowance.
- Real synthetic one- and two-credit requests, wallet refresh, same-request replay, insufficient balance at one and zero credits, and consent-off controls passed.
- Prepaid spending reduced 300 to 299; retry and active Restore preserved 299 with one grant for that purchase.
- Second-account real spending changed 20 to 19 while the owner's balance and request count stayed unchanged. Both accounts' external-AI consent was restored off.
- Local SI guidance worked with zero credits and external-AI consent off.
- A-B-A sign-in preserved separate profiles, both Settings Back controls, saved goal/linked actions, note, Daily Rhythm, history, and owner level 2 / 200 XP.

Historical live monthly/annual, renewal, expiration, grace, hold, recovery, pause/resume, and completed chargeback/revocation observations are retained in the [3014 report](INTERNAL_3014_PUBLICATION_VALIDATION_20260907.md), with their exact version and timing boundaries. They are not represented as newly repeated on every later app version.

## Final Play-installed Moto acceptance

The Moto G Stylus 5G 2022 updated through `com.android.vending` to version code `2026083018` at device time `2026-09-08 00:35:04`. No uninstall, data reset, or sideload was used. Startup went directly to the owner Nexus, and the profile remained level 2 / 200 XP / 2-day streak.

- Settings shows the correct internal credit-test availability text. The external-AI consent label toggled once to checked and enabled the synthetic actions; toggling it off restored unchecked state and disabled those actions.
- A fresh slow-approving prepaid purchase stayed inactive with the existing free balance of 20 through restart and pending Restore. Approval filled the allowance to 300; the historical prepaid-grant count increased from one to two, exactly one grant for this new purchase.
- Settings displayed `Premium allowance` and `period ends` at 300 and 299 credits. A real one-credit synthetic reply reduced 300 to 299; retry reported an already completed request and made no second charge.
- A-B-A account switching kept the second account at free 19 with no entitlement. Its Restore found no active purchase while the owner remained active at 299. Returning to the owner restored the active subscription without changing 299 or the two historical grants (server readback `05:42:41Z`).
- Expiration at `05:42:53Z` removed paid access, restored free 20, and cleared the old restored-and-active message on the same paywall screen.
- A fresh slow-declining purchase showed pending, survived app restart without granting access, and ended with no active purchase to restore. Readback at `05:45:41Z` showed free 20, inactive/expired, unchanged two historical grants, two processed notifications, and zero failed notifications for that attempt.
- The 90-day Trajectory label reads `insufficient evidence`; the horizon was restored to seven days. Timeline All retains eight events and Profile retains 200 XP.
- A second fresh slow approval provided an uninterrupted same-screen regression check. The screen showed pending through `05:48:24Z`, then active with no pending message at `05:48:42Z`. The server showed 300 credits and exactly one additional grant for this separate purchase (three historical prepaid grants total). No navigation or Restore action was used during this transition capture.
- Both accounts' Settings header Back returned to Nexus; owner system Back also passed. Returning to the owner preserved the goal and its two linked completed actions, the saved note (visually checked), Daily Rhythm, and eight historical events. The new calendar day's rhythm was left unrecorded; no completion or XP was fabricated.
- SI Console returned an on-device answer grounded in the saved goal. Smart Planner returned an on-device clarifying question. External-AI consent remained off; these local guidance checks made no credit debit.
- A bounded final device crash-buffer check (250 lines maximum) found zero ChronoSpark mentions. Raw logcat was not retained; this is not a guarantee about all historical crashes.
- Final backend readback at `05:52:54Z`: both short approved plans had expired normally; owner free 20 / inactive, second free 19 / no entitlement, three historical owner prepaid grants, zero failed billing notifications since the final device run began, and exactly one new completed owner AI request. Progression still showed level 2 and eight completed historical outcomes. The phone was returned to the owner Nexus.

Device XML captures and bounded readbacks are retained under `test-results/moto-3018-validation/`; they are local evidence, not committed release artifacts.

## Backend and repository alignment

Receipt v20 and RTDN v17 matched all deployed source files after line-ending normalization. The prepaid migration changes only the underlying billing routines; public wrapper definition hashes and access restrictions remain unchanged. Anonymous and authenticated app roles cannot directly execute grant/reconciliation routines.

Supabase recorded the applied migration as `20260908042735_internal_prepaid_credit_grant`. The local planned filename is aligned to that recorded timestamp with an identical-content rename; migration replay policy passes all 47 migrations. That repository bookkeeping and the final evidence report do not change the signed app source.

## Evidence limits and exclusions

- Refund accounting and duplicate-refund protection passed through deployed reserve/settle routines in a transaction that was rolled back. No upstream Anthropic outage was deliberately induced; zero fixture rows were retained.
- Google pending-refund-review response automation is not implemented. The completed chargeback/revocation path was exercised; an ignored review notification is not a claimed review-response implementation.
- No monkey or level-20 endurance testing was run in this phase. No public production-readiness or bug-free guarantee is made.
