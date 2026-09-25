# Axiomara public release gate — September 24, 2026

**Status: NOT READY for a full-feature production submission.** This is an
evidence register, not a request to upload or publish. The production track is
inactive. The latest Play-served closed-test release is 2026083081 (Release 22),
available only to selected testers. The September 24 Play Console production
page offered Create new release, and the app dashboard confirmed that Google
has granted production access. Access does not certify the build or close the
project gates below; no production release has been created or submitted.

## Exact artifact boundary

- The latest merged app-code checkpoint is
  `baf802d08b4e6472820e1c229c554d90fdbc12ea`, version
  `4.1.0+2026083084`. This document update will have its own later commit;
  the checks below attest the app-code checkpoint, not that later documentation
  commit. Reviewed PR 133 added bounded push-device registration and a client
  check for declined registrations without enabling public features.
  Exact-main [CI/CD run 36071219646](https://github.com/ghostheart5/fantastic-guacamole/actions/runs/36071219646)
  passed 3,396 Flutter tests and 15 QA configuration tests with zero failures
  or skips, plus static policy, Linux integration and Windows golden checks.
  [CodeQL run 36071219085](https://github.com/ghostheart5/fantastic-guacamole/actions/runs/36071219085)
  and [database gate 36071219667](https://github.com/ghostheart5/fantastic-guacamole/actions/runs/36071219667)
  passed. Exact-main [Maestro Runtime Gate 36071219710](https://github.com/ghostheart5/fantastic-guacamole/actions/runs/36071219710)
  passed on a clean Android 15 guest: five selected Planner, Creator, SI,
  Timeline and Progression journeys, five JUnit cases, zero failures, errors or
  skips, no fatal log markers, and the app alive throughout. Its installed QA
  debug APK SHA-256 was
  `17dbc48b5baea12b3930502745eee774bb45ffea127987269f47390e1a81576c`;
  this is not Play-signed or enabled public-feature evidence. Earlier Android 15
  hosted QA run
  [35943294605](https://github.com/ghostheart5/fantastic-guacamole/actions/runs/35943294605)
  passed 11/11 journeys on earlier QA source `ef85eeaf5e9ea64990afb3322ee3190cff6da426`;
  it used a debug QA APK, not a Play-signed public build. There is no signed
  full-feature AAB from this app-code checkpoint. The small machine-readable
  [exact-main receipts](evidence/axiomara_main_baf802_20260924/README.md)
  are retained with their SHA-256 hashes for reviewer access.
- The most recent signed contained candidate was version 2026083083 from
  `36ec3dda6120af0c39142c6106e1f73b6159e305`, candidate run
  [35932394334](https://github.com/ghostheart5/fantastic-guacamole/actions/runs/35932394334),
  AAB SHA-256 `a37717ed3b4d9625a094c8ec7a5ae3dbeec1ae1312c3d9572d01db3bd2d1aafc`.
  It was not uploaded to Play. It cannot prove current-source or full-feature
  behavior.
- `lib/config/launch_containment.dart` still disables subscriptions, external
  AI, credit spending, cloud sync, and cloud restore. Safety review approval is
  also false. The signed-candidate runner requires these switches to stay off,
  and the server public-AI stage is not deployed or enabled. Do not flip the
  switches or repurpose the contained runner without a separately reviewed
  public build and backend sequence.

## Blocking work with direct evidence needed

| Gate | Current evidence | Exit evidence |
|---|---|---|
| Paid checkout safety | [Draft PR 129](https://github.com/ghostheart5/fantastic-guacamole/pull/129) at `066db430480089f5849e966edd0bd432f9bef552` passed required CI, but remains unmerged/undeployed with one open P1 review thread. An offline pending payment completed after the admission window can be recorded without credits, and no approved refund or fulfillment remedy is in service. | Owner-approved customer remedy, qualified review of its financial/privacy effects, exact-head review with no unresolved findings, migration/backend deployment readback, and Play-signed license-test delayed, canceled, offline, and RTDN-only results. Never use a real charge to close this gate. |
| Public AI safety/privacy | PR 128's default-closed server policy is merged but undeployed. The owner confirmed there are no signed independent privacy/legal or mental-health-safety dispositions. | Qualified, signed, dated assessments of the exact enabled app, backend, data flow, disclosures, English/Spanish distress handling, and fixes; then source-matched deployed policy and runtime tests. Technical code review is not a substitute. |
| Public build provenance | The current workflow builds only a contained private-cohort candidate. | Reviewed public profile, exact merged SHA and green exact-source CI, source-matched backend, verified signing/AAB identity, and Play-signed installed artifact tested without changing the Moto's preserved data. |
| Store and policy parity | Play App content showed no outstanding declaration task for the current closed-test app; the saved Health declaration says no health features. EN/ES descriptions still restrict AI to eligible private testers. The public YouTube promo depicts credit-backed AI. | Qualified Health/Data safety classification for the enabled behavior; saved EN-US, ES-419, ES-US listing and video claims checked against the exact final build; owner-side YouTube monetization and final media parity readback. |
| Android layout and journeys | Play Test and release shows an “Edge-to-edge may not display for all users” advisory for closed release 3081. The September 24 isolated Android 16 QA check below found no system-bar overlap on sampled screens, but it used a debug build with mock login and disabled paywall. | Inspect system-bar and cutout overlap on Android 15 and 16, gesture and three-button navigation, normal and 150% text scale, login, Planner, SI, paywall, and critical bottom controls on the exact signed candidate. Record screenshot/device identity and fix any reproduced overlap. |
| Operations | The historical register in `EXTERNAL_GATES.md` contains open recovery, monitoring, billing lifecycle, and first-time UAT rows. | Current dated deployment parity, reconciliation/alerting, backup restore drill, support and rollback owners, signed test matrix, and dispositioned critical findings. |

At 23:22 UTC on September 24, a read-only inspection of the linked Supabase
project found PR 133 migration `20260924223558_bound_firebase_device_registration`
already applied. All 55 recorded migration names matched the 55 tracked source
names. The live RPC contains the new cap and cross-account token rules, grants
execution only to `authenticated`, and its registration table had zero rows.
The prior closed-test 3081 client ignores the RPC's zero result and may log a
declined push registration as synced, although the path is nonfatal; the new
source checks the result. This inspection did not invoke the live RPC and does
not prove who applied the migration, exercised push delivery, or complete
deployment and operations parity. Do not apply the migration again.

## Evidence rules for the next stage

1. Keep the closed test and production track unchanged while the above gates
   are open. A green host test, a debug APK, a Console button, or a queued paid
   order is not production approval.
2. Use an isolated checkout for source changes and preserve the dirty canonical
   checkout and Moto app data. Do not merge PR 129 or enable public sales to
   make a candidate appear complete.
3. After the owner selects and approves a customer remedy and the independent
   dispositions exist, review the exact public build profile and backend change,
   run exact-source CI, build and inspect the signed AAB, and execute the
   Play-signed license-test and device matrix. Reconcile Play declarations and
   every listing locale to that same artifact.
4. Reassess this register against a final evidence packet. Stop before any
   production upload, review submission, or publication until the owner gives
   separate authorization for the concrete release.

Android's [edge-to-edge guidance](https://developer.android.com/develop/ui/views/layout/edge-to-edge)
explains that Android 15+ enforces drawing behind system bars for apps targeting
SDK 35+. It calls for inset handling and visual overlap checks; the Play
advisory alone does not establish a specific defect.

## Isolated Android 15 and 16 visual check — September 24

The new `axiomara_edge_qa_36` AVD on `emulator-5580` ran Android 16/API 36,
and `axiomara_edge_qa_35` on `emulator-5582` ran Android 15/API 35. The
current-main app code was built once as debug QA version `4.1.0+2026083084`
(APK SHA-256 `66fa45284d595af83e28ae0f38cef3cbf9ad7e2321310dda0279a83d151aff18`,
Android Debug certificate, installer null). A synthetic QA sign-in reached the
Nexus. Visual captures at 100% and 150% text with gesture navigation show the
Nexus, Planner, SI, and Settings controls clear of the system status and gesture
areas. At 150% text, the Planner input and Get Guidance button remained
reachable; the SI composer remained above the gesture area. The Nexus bottom
navigation was also clear of Android's three-button controls at 150% text.
On Android 15 at 150% text, the sampled Nexus navigation, Planner input and
Get Guidance button, and SI composer were also clear of gesture and status
bars. The screenshots, SHA-256 hashes, device identity, and limitations are
preserved in the reviewed tree under
[`evidence/axiomara_edge_qa_20260924`](evidence/axiomara_edge_qa_20260924/README.md),
with separate [Android 16](evidence/axiomara_edge_qa_20260924/validation-result.json)
and [Android 15](evidence/axiomara_edge_qa_20260924/android15-validation-result.json)
manifests.

This narrows the Play advisory to an unproven risk on the sampled QA surfaces;
it does not close the release gate. The check did not exercise a Play-signed
build, public paywall, paid AI, complete Android 15 visual matrix, or every display
cutout and route. A Maestro assertion using an exact standalone Planner heading
failed because that heading was part of a longer accessibility label; the
captured screen shows the heading, so this is a selector issue rather than a
verified display defect.

## Play Health and Data safety classification review — September 24

Read-only Play Console App content inspection found no items in **Need attention**.
That means the current forms are actioned, not that their answers describe a
future full-feature build. The saved **Health apps** form, last edited June 24,
selects **My app does not have any health features**. The **Data safety** form,
last edited September 18, selects ten data types, including **Other in-app
messages** and **Other user-generated content**, but leaves **Health info**
unselected. No form answer was changed or submitted during this inspection.

The app exposes an optional **Emotional state** check-in and tells users to
select it to tune planning guidance (`lib/l10n/chronospark_localizations.dart`,
`lib/features/home/ui/smart_planner_screen.widgets.dart`). It includes an
**anxious** state, a **Mental Wellness** goal label, and a supportive distress
route with crisis resources. The Planner's external-assistant request contract
can include a user-authorized `emotion` value when that path is enabled
(`lib/state/controllers/smart_planner_query_controller.dart`). These are
concrete reasons to reassess the saved “no health features” answer and whether
any off-device emotional or distress data belongs under **Health info**. They do
not, by themselves, establish a medical-device claim or prove that every
currently distributed build transmits this data.

Google's [Health declaration guidance](https://support.google.com/googleplay/android-developer/answer/14738291)
lists **Stress management, relaxation, mental acuity** for guidance on stress,
mindfulness, cognitive health and wellness coaching, and separately lists
**Mental and behavioral health** for mental-health support. Its
[Data safety guidance](https://support.google.com/googleplay/android-developer/answer/10787469)
defines **Health info** as information about a user's health and requires a
single declaration covering all versions presently distributed on Play. The
qualified privacy/legal and mental-health-safety reviewers must disposition
which categories apply to the exact enabled feature set and payloads, including
English/Spanish claims, then reconcile the saved forms and privacy disclosures
before a public build is submitted. Until then, do not treat the actioned forms
as production parity evidence or select categories speculatively in Console.
