# Internal 3012 publication and validation

## Release identity

- App source: `934eaa1b202bb25630fe5dc74c9b7aa3d7ad5b01`.
- Version: `4.1.0+2026083012`; package `com.ghostheart5.chronospark`.
- Signed build: [34159755543](https://github.com/ghostheart5/fantastic-guacamole/actions/runs/34159755543).
- AAB SHA-256: `a9f3bfeadd97ad8dcedfdbfce9f126cf80ab41604217ba427cbd254dc25935c4`.
- AAB size: 77,613,111 bytes. Download checksum, existing upload signing certificate, JAR signature, compiled manifest artifact, source/CI binding, and internal billing flags verified locally.
- Google Play internal release 16 published September 7, 2026 at 20:44 UTC. Console readback: available to internal testers, version 2026083012, no supported-device reduction. No production-track publication.
- The AAB and verification files are retained under `artifacts/releases/4.1.0-2026083012-internal-billing-verified/`.

## Exact-source host checks

[CI 34158833725](https://github.com/ghostheart5/fantastic-guacamole/actions/runs/34158833725) passed:

- 2,525 Flutter tests, 15 QA configuration contracts, 38 Windows comparisons, 16 Windows Maestro launcher checks, and 8 Linux app-root integration tests; no failures, errors, or skips in their retained manifests.
- Static policy and coverage contracts passed.
- [Backend 34158837097](https://github.com/ghostheart5/fantastic-guacamole/actions/runs/34158837097) passed, including 96 Edge Function tests with zero failures/errors.
- Exact-source full Maestro journeys: run 34158835325 passed nine journeys, then failed in the learned-lifecycle Creator review scroll; the final readback journey did not execute. Fatal-marker scan found zero. The retained screenshot shows the multiline notes field consuming center-screen scrolling while the outer review control remains below the viewport.
- Harness-only repair `b7bd1118d1a1f65ad75dd138d2e176cb1b65a976` uses five bounded outer-gutter swipes and retains the mandatory review assertion and subsequent confirmation checks. All 27 Maestro files passed local validation. Full rerun 34161033922 failed its first Planner journey: the screenshot reads `Finish the elease evidence today`, missing a character from the submitted test input. The mandatory exact-input assertion stopped the flow before submission; the other ten flows did not run. App source is unchanged from the signed 934eaa1b release.

## Repairs and live evidence

- Settings opens the paywall with `push`, preserving the Settings route for Android Back. Both Manage plan and View credits have regression tests that reproduce the old missing-stack failure and pass after the repair.
- Planner request limits and referential follow-ups were exercised on Play-installed 3011: desk planning at 10 minutes, then 5 minutes, then a simpler version retaining the five-minute limit.
- Backend receipt verification and RTDN repairs were merged to main in PR 101 and live deployment source was checked. A later publication therefore retains the repaired runtime. Live annual renewal at 20:27 UTC processed successfully without a failure code.
- On 3011, Creator task creation, review, edit, completion, Timeline readback, process restart, and XP persistence passed. Profile grew from 125 to 150 XP through one confirmed completed task.
- A goal named `QA journey - verify release workflows` and its linked 15-minute task `QA journey - verify Settings Back after update` were saved through Creator confirmation. Nexus and Trajectory recognized the active task immediately. Both survived the Play update. After both repaired Back paths passed on 3012, the linked task was completed through Nexus, producing a reviewable learned-fit change and increasing XP from 150 to 175.
- Trajectory 7/30/90-day controls and recalculation were exercised; unavailable availability/energy remained identified as missing or estimated. Previewing did not award XP.
- Learning evidence and observation correction controls were inspected without resetting history. Opening the newly generated completion notification reduced unread count by one.

## Evidence boundaries and pending work

- Moto updated through Google Play at 20:48:22 UTC. Package readback confirms 2026083012, target SDK 36, installer `com.android.vending`. Signed-in profile, 150 XP, history, and linked task were retained on first launch. Both Manage plan and View credits return to Settings with hardware Back. Restore reports `Subscription restored and active.`
- On 3012, a five-minute Planner recommendation reached the unsaved Creator preview and confirmation using the outer-gutter scroll. Cancel and Discard preview created no active task. A process restart retained 175 XP and four completed Timeline tasks. At the 20:57 annual renewal boundary, Settings briefly showed `Billing test ready`; it recovered to `Test subscription active` without navigation or Restore within the configured one-minute authority refresh cycle. Backend renewal was recorded at 20:57:32.528659 UTC with expiry 21:27:25.543 UTC.
- Monthly and annual license-test approval, decline, checkout cancellation/retry, restoration, backend activation, and renewals were exercised during this session on earlier builds with the repaired backend. Monthly final expiration was observed continuously in an awake foreground app; access became inactive without user input. This does not establish every lifecycle case on 3012.
- Billing Lab still exposes only Renew for the annual test subscription, including after restart/sign-in. Grace period, account hold/recovery, pause/resume, and chargeback have not all been verified live. Requested manual payment-method change remains pending.
- Pending-purchase instruments were not offered by the observed checkout. Unsupported/unexecuted cases are not passes.
- Live ownership isolation requires the requested second authorized test account. Hosted QA isolation is separate evidence.
- AI and credit spending remain deliberately unavailable; no token-spending success is claimed.
- Level-20 endurance has not started because material live billing prerequisites and the full journey rerun remain incomplete. The growing Moto profile is at level 2 with 175 XP after the two completed validation tasks. Monkey testing is excluded by request.

## Follow-on material repair for 3013

- On 3012, Creator confirmed `QA rhythm - review test evidence`, daily target one. There was no reachable library to read or record outcomes for saved rhythms. The record is preserved on the Moto for the next Play update.
- 3013 adds a Creator entry to a Daily Rhythms library using existing account-scoped habit and occurrence services. Completion and skip record one outcome per cadence period; rename, pause/resume, and confirmed removal use existing mutations. Target completion means the entire configured period target is met.
- Twenty focused Creator, Daily Rhythms, provider, and coordinator tests pass locally, including account changes during dialogs, failed writes, duplicate-outcome prevention, and completion/skip controls. Focused static analysis and 28 Maestro YAML contracts pass. Hosted and Play-delivered validation of 3013 remain required.
- Planner test input now retries only the focused field up to three times, clears the short request between attempts, and still requires exact readback before submitting. No submitted application mutation is retried.

## Minor observations retained for follow-up

- Creator's 90-minute option reads `1 hours 30 min`.
- Linked-goal confirmation identifies the goal by its internal ID rather than repeating the selected title. The selection screen displays the title correctly.

These copy observations did not cause the material navigation failure repaired in 3012. Neither all application variables nor 100% live billing coverage is claimed.
