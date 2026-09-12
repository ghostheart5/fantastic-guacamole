# ChronoSpark 3032 release validation

Checkpoint started September 11, 2026 (America/Chicago). Application source is
`91d9086ea76ecb10de74e950be3dabfa964e4043`, version `4.1.0+2026083032`.
This report distinguishes app source, build tooling, test tooling, Play state,
installed-device results, and external production requirements. Production
publication is not authorized.

## Repairs included

- SI recognizes a bounded five-minute action request before school pickup.
- An unsupported weather question receives an explicit boundary instead of
  being interpreted as a request to schedule tasks.
- The SI service does not append an unrelated Home recommendation to an
  unsupported answer or a saved-record listing. Supported next-action questions
  retain their eligible shared recommendation.

The service-composition regression was first reproduced as a failing test.
The complete seven-file SI group then passed 44 cases. The full source CI below
includes those repairs. Candidate 3031 was superseded before publication; its
results do not establish acceptance of 3032.

## Signed artifact

Candidate build: [34659446880](https://github.com/ghostheart5/fantastic-guacamole/actions/runs/34659446880).
Build tooling: `44f7931e3033b15b3229cd91b2111a17ff453403`.

- AAB SHA-256: `e266e0795edcb04a298d706fd2f7e4027ff8055cbbdc9c93ea656b4974454b49`.
- GitHub artifact: `10287805029`; original ZIP SHA-256:
  `8a805cf9208463987991234a487e2f0a555d46930416c71ce3669adeb1680b57`.
- Upload certificate SHA-256:
  `D88ECFC61A95B58B533E3896378A2D70894D6EF274D8C56C9F90A77C544E8D79`.
- Package `com.ghostheart5.chronospark`, minimum API 24, target API 36, three ABIs.
- Independent actual-bundle inspection passed, including all nine declared
  dependency notices and nine matching native-symbol pairs. Three vendor
  DataStore libraries lack full debug symbols; that diagnostic limitation is
  recorded separately from runtime compatibility.

## Hosted verification

| Check | Current result | Evidence |
| --- | --- | --- |
| Canonical Flutter suite | PASS: 2,919, zero failures/errors/skips | CI `34658669980` |
| QA configuration | PASS: 15 | Same CI |
| Windows golden comparison | PASS: 48 | Same CI |
| Launcher behavior | PASS: 17 | Same CI |
| Linux integration | PASS: 8 | Same CI |
| Fresh SQL replay/tests | PASS: 350 across 13 files | Database run `34658670054` |
| Edge Functions | PASS: 142 | Same database run |
| Independent complete Windows repeat | PASS: 2,922 plus 15 QA configuration cases | Post-build run `34660285520` |
| Native Android matrix | PASS: 15/15, zero failures/errors/skips | Same post-build run; five raw reports and five distinct hosts independently verified |
| Strict 16 KB signed-release validation | PASS: actual 16,384-byte guest, compatibility fallback disabled, onboarding 1/1 | Same post-build run; AAB hash matches the artifact above |
| Decision-volume exercise | PASS: 60 scenarios of 1,000 tasks | Local deterministic, finite-result, input-preservation and terminal-task checks |
| Maestro journeys | PASS: all 11, zero failures/errors/skips and app fatal markers | Independently parsed JUnit from `34661540608`; the combined workflow later failed during Monkey |
| Bounded Monkey recovery | PASS: 5/5 variants, 1,700 verified events, successful relaunches, zero app fatal markers and no Android ANR | `34666965106`, tooling `c5ff686b0d8e047d850a15a20d6beda981e123a4` |

Hosted fixture tests do not establish Google Play purchase behavior or a signed
Moto human journey. Artifact ZIP hashes and raw terminal/JUnit results were
checked independently; a workflow's green badge alone is not the acceptance
criterion. Native emulator, collector and ADB-server cleanup passed.

### Retained runner failures

The first 3032 journey attempt, `34658669991`, failed its first onboarding
checkpoint while a Google SDK setup ANR dialog covered the app. Only one of the
eleven intended cases ran and Monkey did not start. The screenshot and archive
`10287116410` are retained. This is not a complete passing journey run.

Tooling `02edb6df` added a bounded 60-second first-boot settling window, host and
guest memory samples, readiness checks and whole-system diagnostics. Attempt
`34660587679` then stopped before app tests because the newly added check expected
an uppercase `No`, while Android actually returned
`<no ANR has occurred since boot>`. This was a runner defect, not a new observed
app defect. Artifact `10286839347` retains the actual healthy response.

Tooling `b773c65d` corrects that parser. The actual captured response, its uppercase
equivalent, a real-ANR sample, an empty response and an offline error were tested
against both the Python readiness and shell final checks. All ten checks passed;
the local-host rejection and YAML/Python/shell parsing checks also passed. App
assertions, journey counts, Monkey counts, failure handling and source identity
requirements were preserved. The repaired readiness check passed in `34661540608`; all eleven journeys then
passed, and the final system readback reported no ANR. The precise historical
cause of the first Google setup ANR is not established.

The combined run subsequently stopped after its fourth Monkey variant. All
500 touch-motion events were injected with exit code zero and no fatal markers,
but the newly launched app did not receive foreground focus within 30 seconds.
Window evidence shows the app drawn behind an expanded SystemUI NotificationShade;
Android reported no ANR. This remains a failed relaunch check, not a passing
complete matrix. Artifact `10288033123` retains the evidence.

Tooling `ade79458` adds an emulator-only recovery that collapses an observed
NotificationShade after preserving stress logs and before the existing strict
relaunch checks. It leaves app dialogs untouched and rejects physical phones.
All 22 runner fixture/contract checks passed locally. Recovery attempt `34664579168` stopped in its first seed journey before Monkey
started. Screenshots show the title was already mistyped as `Pririty 8 journey
seed` before submission; the app then saved that exact text. The terminal
assertion correctly rejected it. Whole-system logs also record two Google
keyboard ANRs during this entry (`com.google.android.inputmethod.latin`), while
ChronoSpark fatal markers remain zero. Artifact `10289535540` retains this
failed run; it is not a clean system pass.

Tooling `c8a57c03` adds the existing bounded exact-text-entry helper before
Creator submission. The recovery-only copy changes exactly this input command;
all downstream assertions remain intact, and source/executed flow hashes are
recorded. Run `34665799720` was configured for the two seed journeys and all
five Monkey variants. The final whole-system ANR guard still rejects any ANR, even if a
text-entry retry succeeds.

Run `34665799720` passed the repaired first seed journey, with no app fatal
markers and no Android ANR. The second runner invocation then correctly refused
one untracked report directory: the workflow had selected an output root not
covered by the source checkout ignore rules. This is an orchestration defect.
Artifact `10289217930` retains the successful first journey and overall failed
run. Tooling `c5ff686b` moves recovery reports into the existing ignored
`test-results` tree and verifies every generated root is ignored before compiling.
Run `34666965106` passed both seed journeys and all five Monkey variants with
the clean-source guard enabled. Its complete logs were independently hashed and
rescanned with the committed fatal patterns: zero matches. Actual Monkey
terminal event totals were 100 smoke, 500 balanced, 300 navigation, 500 touch-motion
and 300 lifecycle events. Every relaunch passed. Android reported no ANR.
No notification-panel collapse was needed in this run; that branch passed
the focused fixtures rather than a forced live-panel scenario.

Passing artifact `10289609570` has ZIP SHA-256
`bb37b9f9c9e3c70939e37bbc84363604b6bbd4e21018d1bf4f8fef3b7fa2fcb8`.
The archive contains the executed-flow hash ledger, but GitHub omitted the
hidden `.maestro` flow copies. Every ledger hash was independently compared
with immutable source and the exact single input-entry replacement; the hosted
verifier had also checked the actual files after execution. Downloaded raw flow
copies are not claimed. Future archival-only tooling `4b21abe9` includes those
hidden tracked-source copies; its YAML was checked, and no runtime rerun was
needed for that output-only adjustment. Application source remains
`91d9086e`; separate QA builds are bound to their own compilation and APK hashes.
The runner repair does not substitute a new app build or erase the failed run.

The main checkout now contains the same panel-recovery runner and exact
Creator seed-entry check for future runs. All 25 focused runner/selector tests
and the 30-file Maestro validator passed locally. These are test-tooling changes
after the signed app source; they do not change the published AAB identity.

## Internal testing and Moto

Play accepted 3032 into saved internal release draft 33 with mapping and native
symbols attached. The verified bundle was published to the existing internal
track at September 11, 8:47 PM Central; independent Console readback confirms
`Available to internal testers`. Production was not published. The Moto remains
on Play-installed 3030 pending the Google Play update.

Internal device validation was advanced while the separately documented stress
recovery remained open, after the full source, native, signed-bundle and eleven
journey checks passed. This does not close the stress gate. An automatic tool
policy rejected the command to open the Play Store with only `blocked by policy`;
the owner was asked to open its page and update. No uninstall or sideload was
attempted.

The official Play web interface recognized the authorized license tester and
the Moto. Its targeted Install request then required Google account
reauthentication; delivery was not confirmed. The verification page was left
for the owner, without entering or requesting a password in chat.

Wireless connection was verified against hardware serial `ZY22G665VG` and owner
Android user 0. Owner data was not cleared or uninstalled. The phone was later independently
confirmed unlocked and responsive. Its pre-update Profile display reconfirmed
level 20, 36,212 XP and 1,448 completed tasks. There are no 3032 Moto pass claims yet.

The last observed owner progress remains level 20, 36,212 XP and 1,448 completed
tasks on 3030. Historical 3030 phone evidence remains in its separate report.
Fresh 3032 SI, vitals, Momentum, navigation, context, billing and screenshot
acceptance are pending.

At 2026-09-12 00:13:29 UTC the backend reported the accelerated annual test
subscription expired, with 517 credits: 20 included and 497 purchased. Lifetime
spending remained 64. A second readback at 01:32:32 UTC was unchanged; the Moto Settings and
subscription screen independently matched the 517 balance, its 20/497 split and
the Free tier. This is a pre-update consistency check, not a new spending test.

The old 3030 SI weather defect was reproduced again directly on the Moto.
`Will it rain tomorrow?` produced a saved bookkeeping-task recommendation.
The raw UI and screenshot are retained as the before-update comparison.

## Public release requirements

Fresh HTTPS readback at 2026-09-12 00:21:50 UTC returned 200 for privacy, terms,
support and deletion pages. Terms, support and deletion HTML exactly match the
current source. Reachability of the deletion page does not prove execution of an
account-deletion request.

The public privacy page still has the September 9 text. It lacks the paragraph
already present in the signed app describing the verified Anthropic 30-day
retention, absence of Zero Data Retention, global processing, and disabled
prompt/response feedback. The exact prepared update is `web/privacy/index.html`;
the live/source diff is retained. No public-page change is asserted here.

The following remain outside this engineering pass:

- The signed qualified privacy/legal and mental-health/AI-safety dispositions
  required by the project's release register. They are not presented as universal
  Google certification requirements.
- Completing the separate reviewer Android profile's setup and its restricted
  feature journey. Owner user 0 must remain preserved.
- Final public paid-feature eligibility, matching policies, listing, Data safety,
  and current supported-format screenshots.
- Google's production-access application and approval. Production publication
  remains prohibited even if access is later approved.

The signed-in Play web listing was also read directly. It still displays
`No data collected` and the old short description, `Precision Productivity for
People Who Actually Build Things`. Those public-facing values are not reconciled
with the current authentication/billing/optional-provider data map or prepared
listing copy. The Data safety gate therefore remains open; no form submission
or public-copy update is asserted.

The Console's no-ads answer was freshly verified. ChronoSpark's policy remains no
ads for any user, including no ad watching for credits or features.

Current status: **AUTOMATED CHECKS PASS; INTERNAL 3032 PUBLISHED; MOTO UPDATE
AND UPDATED-DEVICE VALIDATION PENDING; NOT PRODUCTION READY**. Finite tests cannot prove
correctness for every possible input, device, network condition or future service
failure.

Detailed receipts are in ignored `test-results/release-3032/`, with the immutable
AAB under `artifacts/releases/4.1.0-2026083032-internal-billing-verified/candidate/`.
