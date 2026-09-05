# Closeout Phase 2 - Firebase and backend hardening

Status: **DEFERRED BY OWNER - remaining provider-credit gate is not passed. On September 5 the owner explicitly directed Phase 3 to start without further Claude setup. Other agreed Phase 2 gates are verified or explicitly accepted; temporary diagnostic cleanup is verified. No Phase 2 completion claim**.
Started 2026-09-04 America/Chicago; checkpoint saved across 2026-09-05.
This is Phase 2 of the new nine-phase closeout plan, not earlier binder numbering.

## Scope and preserved boundaries

- Checkout: `ChronoSpark-app-only-priority2`, branch
  `fix/app-only-readiness-priority2-20260902`, base HEAD
  `0c2449016a36a0cb3ff3e431cbf799cb291c7aea`.
- Exactly two existing helpers were used with no model/reasoning override.
- Phase 1 backend executable source remains identical to tested
  `1f07020e309c10b1b3942349cd436948811f2759`; database gate
  [33944999190](https://github.com/ghostheart5/fantastic-guacamole/actions/runs/33944999190)
  passed and was not rerun.
- Initial preflight involved no production mutation. The subsequently approved
  two-function deployment and sole forward cron migration are recorded below.
  No domain/DNS/TLS work, phone use, build/install, full-suite rerun, Firebase or
  Auth setting change, key creation/rotation, commit or push occurred.
- The installed signed client remains `61c7331d`; neither the new client deletion
  guard nor the Phase 2 native messaging defaults are installed/device-verified.

## Local repair completed

The explicit notification flow already requests permission before its Dart
`getToken()` call, but native FCM auto-initialization was not disabled. Firebase
documents that automatic token creation can upload identifier/configuration data
without waiting for that explicit call.

Added native build-time defaults:

- Android: `firebase_messaging_auto_init_enabled=false` in
  `android/app/src/main/AndroidManifest.xml`; existing Analytics and Crashlytics
  default-off settings preserved.
- iOS: `FirebaseMessagingAutoInitEnabled=false` in `ios/Runner/Info.plist`.
- Extended the existing `test/config/launch_containment_test.dart` native guards.
  No Dart push-flow redesign or runtime auto-init enablement was added.

**PASS:** three targeted tests, zero failures, including the unchanged
explicit-permission-flow contract in
`test/release/source_remediation_contract_test.dart`. Formatting made zero
changes; XML parsing, key uniqueness/default-value and whitespace checks passed.
This proves source/configuration, not zero network traffic, existing-install token
revocation or notification delivery. Initial install, upgrade, permission changes,
token refresh/revocation and delivery remain later signed-candidate/device checks.

Reference: [Firebase FCM auto-initialization controls](https://firebase.google.com/docs/cloud-messaging/flutter/get-started#prevent_auto_initialization).

## App Check requirement corrected

Current direct Firebase integrations are Core, FCM, Remote Config, Analytics and
Crashlytics; the latter two are contained off, and the signed workflow disables
runtime Remote Config flags. Account authentication and user-data authority are
Supabase, not Firebase Auth/Firestore/Storage.

FCM, Remote Config, Analytics and Crashlytics are not on the current built-in
App Check protected-service list. The blanket App Check blocker was corrected in
`EXTERNAL_GATES.md` and `docs/google_play_release_checklist.md` to
**NOT_APPLICABLE_CURRENT_SERVICES / REASSESS_ON_CHANGE**. This is an applicability
decision for this inspected client, not a project-wide claim about other apps.
A Firebase Console switch does not attest Supabase requests. Custom-backend
attestation or new supported Firebase services require separate design, valid
signed-client tokens and staged tests before approved enforcement.

Reference: [Firebase App Check service coverage](https://firebase.google.com/docs/app-check).

## Live key-to-client mapping - read-only verified

Browser account: `domnichols39@gmail.com`, project `chronospark-app`, number
`956622397052`. The installed Firebase CLI instead lists
`ghostheart131517@gmail.com`; it was not switched or used to modify this project.
Live browser-visible key strings were hashed in memory and not printed or saved.
All three full SHA-256 fingerprints match the local client configuration.

| Cloud key record ID | SHA-256 fingerprint | Known configured consumers |
| --- | --- | --- |
| Android `e184f343-0f57-41b9-8306-293c9040ed69` | `d5b8b2238486b7849028268f44500f6b9afa1290fe7f93faf7d2c6325bcdf66e` | Production Android plus old `com.example.chronospark` Android entry |
| Browser `78970ff4-1470-42a9-a66b-f44bbb7e38c7` | `9a20afa692a7f629619e364ff8fd290548b993289ab4ddb8ae9d1de17d7e221a` | Web and native Windows, sharing the same Firebase app ID |
| iOS `4f3d50ad-9883-4166-9f29-bb54852f7eb1` | `ff151fdd4b319554013f6515df6035ddf435bd9181bbfe7016c2ae89a4746dba` | iOS and macOS |

For all three records, current readback shows **25 selected API restrictions**
and application restriction **None**. The listed APIs do not include Generative
Language API; Firebase AI Logic API is listed, which is not proof it is used or
enabled in the app. No restriction, rotation, deletion or Save action was taken.
These public Firebase identifiers are not substitutes for authentication/RLS.

Shared-consumer blockers before changing application restrictions:

1. Android: both production and old package entries use the same key. The native
   OAuth configuration has SHA-1 `21331d8fda42ff612dbf33b17863d388e9db24fc`;
   the workflow upload certificate is `8A24D7BAACAB52F0A3777DD047C907962E82FAA5`.
   Neither proves all consumers or the Play App Signing certificate. Do not
   restrict to a single assumed package/certificate and break another client.
2. Browser: Windows registers native Firebase Core/Remote Config and shares the
   web key/app ID. Website-referrer restrictions are not proven compatible with
   native Windows requests; separating clients requires a scoped decision/test.
3. Apple: Dart options declare `com.ghostheart5.chronospark`, but native macOS
   `macos/Runner/Configs/AppInfo.xcconfig:11` still uses
   `com.example.chronospark`. iOS matches the production identity. Do not rename
   the macOS bundle or restrict the shared key before intended scope/identity is
   confirmed. This is a verified configuration inconsistency, not runtime proof.

Reference: [Firebase API-key restrictions and compatibility guidance](https://firebase.google.com/docs/projects/api-keys).

## Supabase deployment preflight - read-only verified

Production project: `qpwhuckyirnqtmvhpede`.

- Live migration history still has 44 version/name entries. The sole pending
  local migration is `20260905041637_consolidate_subscription_expiry_schedule`.
  No earlier migration file changed in the tested Phase 1 repair.
- Live `account-delete` is ACTIVE, version 8, `verify_jwt=true`.
  Live `account-delete-reconcile` is ACTIVE, version 6, `verify_jwt=false`;
  its existing custom reconciliation authentication must remain unchanged.
- Complete seven file instances for both bundles were downloaded as rollback
  source and independently compared with `61c7331d`: all match after newline
  and trailing-whitespace normalization.
- Snapshot: `artifacts/phase2-predeploy/0c244901/`, including manifest, versions,
  JWT settings, bundle hashes and all dependency files. Keep it out of commits;
  preserve it through the authorized deployment/readback window.
- Both cron jobs retain the exact expected command, 15-minute schedule,
  database/user `postgres`, host `localhost`, port `5432`: job 1 inactive,
  job 5 active. Exactly one matching expiry schedule is active.
- Naturally scheduled job 5 executions at 04:00, 04:15, 04:30 and 04:45 UTC
  succeeded. Job 1 had no executions in that inspected hour. No expiry function
  was manually called.
- Aggregate deletion-request and provider-recheck counts were both zero. This
  does not prove a real deletion or billing-reconciliation journey.
- Existing Firebase production alert selections remain E-mail for new fatal,
  nonfatal and ANR issues. No alert preferences or collection flags were changed.

## Approved deployment scope

Apply only the already-tested forward cron migration and deploy only these two
function closures, preserving JWT flags and existing environment/secret setup:

- `account-delete`: its entrypoint, `recent_sign_in_policy.ts`, shared deletion
  state machine and storage cleanup.
- `account-delete-reconcile`: its entrypoint, the same shared deletion state
  machine and storage cleanup. Its executed reconciliation logic is unchanged,
  but the bundled shared dependency must match the tested source.

The user subsequently approved this exact scope. Live identity, versions, queue
state and sole-pending-migration scope were rechecked before execution; deployment
and independent readback are recorded below. No deletion-capable POST was sent.
Real disposable-account session/deletion proof remains Phase 3.

Rollback requires the captured former bundles, not reconstruction from memory.
Reverting deletion authentication restores a known flaw and needs an explicit
incident decision. Preserve the captured cron active state (older job false);
blindly reactivating it would reintroduce the duplicate. Never delete migration
history or assume a rollback can undo an account deletion.

## Approved production deployment - 2026-09-05 05:09 UTC

**PASS for the approved deployment scope.** The production project remained
`qpwhuckyirnqtmvhpede`; both predeployment versions and bundle hashes still
matched the preserved rollback snapshot. Backend source had zero diff against
tested commit `1f07020e309c10b1b3942349cd436948811f2759`.

- Supabase CLI 2.116.0 dry run listed only
  `20260905041637_consolidate_subscription_expiry_schedule.sql`. The approved
  push used explicit project identity and `--skip-vault`; no seeds, roles,
  include-all operation, migration repair or credential update was requested.
  It succeeded. Independent history readback shows **45 records**, exactly the
  new version `20260905041637` added and no earlier record removed.
- `account-delete` is now **ACTIVE version 9**, `verify_jwt=true`.
  Bundle SHA-256:
  `f79eddf9b098a77fc342df03490cff159134e5bebaf721b02c9165bae296b2eb`.
- `account-delete-reconcile` is now **ACTIVE version 7**, `verify_jwt=false`;
  its custom-secret authentication source is unchanged. Bundle SHA-256:
  `0c858b44742bc4af1aea06f22ac6d30a12bb5aff4646062567706f45fb41af99`.
- Both complete deployed closures were independently retrieved after deployment:
  **all seven file instances exactly match the tested local source strings**,
  without normalization or missing/extra dependency files. The other five Edge
  functions retain their previous versions, hashes and JWT settings.
- Before/after comparison of all five cron rows is identical. Older expiry job
  **1 remains inactive**, keeper **5 remains active**, with exactly one active
  matching expiry job. The migration therefore recorded the already-correct
  operational state without changing any live cron row or manually expiring data.
- Deletion-request and provider-recheck counts are both **zero** at readback.
  Job 5's most recent natural execution succeeded at **05:00 UTC**, before this
  migration; a post-migration natural execution was not yet observed. No waiting
  loop or forced expiry invocation was used.
- Non-mutating, unauthenticated GET checks: `account-delete` returned expected
  gateway **401 / UNAUTHORIZED_NO_AUTH_HEADER**; reconciler returned handler
  **405 / method_not_allowed** with contract `account-delete-reconcile-v1`.
  These establish gateway rejection and reconciler startup/method containment,
  not live session recency, custom-secret validation or successful deletion.

Evidence: `artifacts/phase2-deploy/20260905/production-readback.json`, including
versions/hashes, seven exact-source comparisons, migration identity, complete
before/after cron rows, aggregate queue counts and bounded GET results. Preserve
it and `artifacts/phase2-predeploy/0c244901/` unstaged. No new source/test changes
were needed for this deployment; the passing database suite was not rerun.

This does not install the new client, prove a disposable deletion journey,
validate provider credentials, enable contained features or establish readiness.
Firebase keys/settings, Auth redirects, domain, secrets and phone were untouched.

## Follow-up verification - 2026-09-05, through 12:15 UTC

- Repaired one retained-platform omission: macOS registers Firebase Messaging but
  lacked `FirebaseMessagingAutoInitEnabled=false`. Added that value to
  `macos/Runner/Info.plist` without renaming the bundle or enabling an SDK/feature.
  The existing Apple containment test now checks both iOS and macOS for exactly
  one key and one false value, rejecting conflicting duplicates. **PASS: one
  focused test, zero failures**, using `flutter test --no-pub
  test/config/launch_containment_test.dart --plain-name 'Apple telemetry
  collection defaults are contained' --reporter expanded`. Both plists also
  parsed successfully as XML and passed independent uniqueness/value checks;
  `git diff --check` passed. No full-suite rerun or device/build/install occurred.
  This is local configuration evidence, not observed macOS network behavior.
- The first **29 naturally scheduled keeper executions after deployment all
  succeeded**, from 05:15 through 12:15 UTC. The inspected interval contains no
  execution of the paused older job. No manual expiry or new deployment ran.
  This closes the earlier not-yet-observed scheduled-execution checkpoint.
- Fresh production Auth UI readback confirms Site URL
  `chronospark://auth-callback` and exactly six additional redirect entries:
  `http://localhost:3000`, `http://localhost:8000`, `https://chronospark.ai`,
  `https://www.chronospark.ai`, `chronospark://auth-callback`, and
  `https://chronospark.app/app/auth/callback`. No URL was changed.
- Source mapping found no current runtime consumer for the `.ai` or localhost
  entries, but absence in this checkout does not rule out older clients or build
  overrides. Owner confirmation is required before removing those consumers.
  Current email signup/resend/reset calls rely on the Site URL; it is not `.ai`.
- Corrected stale `docs/SPECIAL_INTEGRATION_POINTS.md` instructions that could
  reintroduce obsolete redirects and confuse the provider callback
  (`https://qpwhuckyirnqtmvhpede.supabase.co/auth/v1/callback`) with the app
  callback. GitHub Pages is informational/legal content, not an Auth client.
- Live Android key UI still shows 25 selected APIs and application restriction
  None under the correct Firebase owner account. No key was revealed, restricted,
  copied, rotated or deleted. Platform/legacy-client scope remains undecided.
- Read only Supabase secret names and update timestamps; custom required entries
  are present. `ANTHROPIC_API_KEY` reports update time
  `2026-09-02T14:08:20.659Z`, which is **not** evidence that the exposed credential
  was revoked or that its replacement is valid. No secret value or digest was
  printed and no paid provider request was made. The Claude Platform keys page
  is signed out; provider-side status requires the owner's authenticated session.

### Account-recovery handoff to Phase 3

The focused redirect trace also identified a source-level recovery-routing gap:
`AuthService.authStateChanges()` maps events to users and drops the
`passwordRecovery` event; the general link parser rejects custom schemes;
authenticated Auth routes redirect onward, while the recovery form is in the
signed-out AuthGate branch. Record this as a required focused event/route/UI repair
and real recovery journey before Phase 3 completion. It was not repaired or
device-tested in this Phase 2 configuration pass. A correct URL allowlist alone
does not prove password reset works.

## Live gate progress - 2026-09-05, 12:31 UTC checkpoint

**Auth redirect cleanup: CONFIGURATION PASS.** The user confirmed that both `.ai`
addresses and localhost ports 3000/8000 were unused by all current/older clients
and development work, and explicitly approved removing all four. The production
removal dialog listed exactly those four URLs. Saved state and an independent
browser reload now show exactly these two retained entries:

- `chronospark://auth-callback`
- `https://chronospark.app/app/auth/callback`

Site URL remains `chronospark://auth-callback`. No provider, template, DNS, domain,
client configuration or account was changed. Restore only a confirmed legitimate
owner-controlled callback under explicit approval; do not automatically re-add
the old domains. This closes the configuration cleanup, not sign-in/recovery or
HTTPS app-link runtime proof; those retain their later phase evidence requirements.

**Firebase: exact live allowlists verified, baseline not yet fully closed.** All
three previously mapped key records were re-read under `domnichols39@gmail.com`.
They have identical lists of 25 selected APIs, no Generative Language API, and
application restriction None. No key string was revealed or setting saved.

The current [Firebase API-key guidance](https://firebase.google.com/docs/projects/api-keys)
permits default lists to contain unused Firebase APIs; presence of an API list
does not authorize users to backend resources. Twenty-two entries map to the
required-API table. Three extensions need a specific retained-consumer justification:
Cloud SQL Admin API, Firebase App Hosting API and Firebase SQL Connect API. The
latter two are Firebase products, but that does not prove a client-key allowlist
requirement. No matching direct client dependency was found in the current
`lib`, `pubspec.yaml` or lockfile; external/legacy workflows are not ruled out.

Application restrictions are recommended additional hardening, not a universal
Firebase production prerequisite. This corrects the blanket requirement, but does
not silently waive this project's existing hardening commitment. Scope/certificates
and staged compatibility proof remain required before changing shared keys.
The three unexplained API extensions remain an open baseline review item.

Evidence: `artifacts/phase2-gates/20260905/redirect-and-firebase-readback.json`
records exact before/after redirects, the three key record IDs, all API names,
classification and limits. The provider console is still signed out; its page
was marked for handoff so it remains available after the turn. No credential
rotation, paid request, test suite, commit or push occurred.

## Firebase allowlist reduction preflight - 2026-09-05

The owner approved the recommendation to test the narrower API allowlist before
changing production keys. The earlier live service inspection and two independent
source/workflow reviews found no current consumer for the three extra APIs:

- Cloud SQL: the instance URL opened setup/billing onboarding; no existing
  instance was shown. This is console evidence, not an exhaustive historical query.
- Firebase SQL Connect: an unconfigured Get started page was displayed.
- Firebase App Hosting: onboarding required a project pricing-plan upgrade; no
  deployed backend was shown. Traditional Firebase Hosting configuration exists
  and is a different service; preserve it and the GitHub Pages deployment workflow.

Current live Credentials readback still lists only the three production key
records, each with 25 APIs. No spare test key exists. No key was created, revealed,
changed or deleted, and no service request or app/device test has run in this
preflight. HEAD remains `0c2449016a36a0cb3ff3e431cbf799cb291c7aea`.

The focused proposed check uses one isolated temporary key with the original
policy, then the exact 22-API policy. Use documented Firebase Installations
registration/token behavior and, if applicable, a client Remote Config fetch;
compare real successful responses, retain no token/key values in reports, and
clean up only the exact new test resources. Generic HTTP success or merely saving
22 permissions is not a compatibility pass. This cannot prove native FCM delivery
or all-platform runtime behavior, which remains later candidate/device evidence.

Stopped before the UI action that creates a persistent API key: action-time
security confirmation is pending. Production allowlist changes remain conditional
on the focused check passing. Preserve all other 22 API entries, application
restrictions, quotas, service enablement, app configurations and key identities.

## Executed Firebase compatibility check - 2026-09-05

The owner explicitly approved temporary-key creation, isolated real Firebase
requests and cleanup. The new-key UI only offered enabled APIs, so the test key
used 13 enabled retained entries, a strict subset of the proposed 22. No API was
enabled to reproduce disabled allowlist entries. The test therefore proves only
the exercised protocol paths under that stricter subset, not an exact-22 rehearsal.

Temporary key `chronospark-phase2-disposable-20260905`, resource ID
`1f4879bb-4d01-4f85-86a4-37a1270c2e9b`, was created with application restriction
None and no service-account binding. Its saved 13-name list was read back.
Values were transferred only in memory through a loopback-only, one-shot test
form and were not written to app configuration or retained evidence.

The isolated Node protocol probe followed official Firebase JS request shapes
(`w:0.6.24` Installations, `12.18.0` Remote Config protocol metadata), not native
Flutter SDK execution. All four distinct configured app IDs were exercised;
Windows shares the web app ID. No phone, emulator, notification, telemetry,
Remote Config activation, full suite or app build was used.

- First run, 12:58:56-12:59:01 UTC: all four baseline-key legs passed. Temporary
  subset Android, web and iOS passed. Temporary-subset macOS registration returned
  200 with valid initial tokens, but fresh token generation returned 404; its
  Remote Config step was not attempted. The first report remains FAILED, 7/8.
- One retry of only the failed macOS leg, 13:03:07-13:03:08 UTC, used a fresh
  disposable installation and passed registration, token generation, Remote
  Config fetch and deletion, all HTTP 200. Original 404 cause is not established.
- Each successful Remote Config fetch returned UPDATE with eight entries; no
  values were logged or activated. This is protocol access, not feature behavior.
- Deletion was accepted for all nine disposable installations: zero pending or
  uncertain creations. This is not a claim of immediate erasure across Firebase.
- Temporary-key deletion was confirmed by exact name/ID and the active credential
  list was independently reloaded: only the three original keys remain, each
  Available with 25 APIs. The deleted key is recoverable for 30 days according to
  the console; it was not restored. The local test server was stopped.

**Production save BLOCKED by the approval system, not completed.** Android's
unsaved form was reduced by exactly the three named entries to 22, but the Save
action was rejected for insufficient explicit production-key authorization. No
alternate route was attempted. The unsaved edit was canceled; web and Apple keys
were not edited. Fresh active-key readback confirms all three still have 25 APIs.
Request explicit approval naming Android, Browser/web-Windows and iOS/macOS keys,
the three API removals and the requirement to preserve all other 22 entries and
application restrictions. Do not repeat successful tests merely to retry Save.

Evidence (preserve unstaged):
`artifacts/phase2-gates/20260905/firebase-api-probe.mjs`,
`firebase-api-probe-results.json`, `firebase-api-probe-macos-retry-results.json`,
and `firebase-allowlist-execution-checkpoint.json` in that same directory.
Syntax checks and `git diff --check` passed. Both result JSON files were scanned
without printing content for API-key/JWT patterns; none were found. No production
credential rotation, enabled-service change, quota change, commit or push occurred.

## Production Firebase allowlist configuration PASS - 2026-09-05 13:25 UTC

The owner explicitly approved removing Cloud SQL Admin API, Firebase App Hosting
API and Firebase SQL Connect API from all three named production keys, preserving
all other 22 permissions and existing application restrictions. This supersedes
the earlier blocked-save checkpoint; that history and test failures remain intact.

Each key's current 25-name set was checked before editing. Only the three approved
selections were removed; the complete 22-name draft and application restriction
None were checked before Save. After each save completed, its exact key record
was independently reopened/reloaded and the complete saved list compared with the
expected 22-name set. All three passed. The final Credentials inventory shows
only the original three keys, each Available with 22 APIs; the disposable key is
still absent.

| Key / retained consumers | Unchanged key record ID | Independent saved-set readback UTC |
| --- | --- | --- |
| Android | `e184f343-0f57-41b9-8306-293c9040ed69` | 13:19:35 |
| Browser / web and Windows | `78970ff4-1470-42a9-a66b-f44bbb7e38c7` | 13:21:59 |
| iOS / iOS and macOS | `4f3d50ad-9883-4166-9f29-bb54852f7eb1` | 13:23:31 |

Removed service mappings: `sqladmin.googleapis.com`,
`firebaseapphosting.googleapis.com`, `firebasedataconnect.googleapis.com`.
Traditional Firebase Hosting remains allowed. All 13 APIs exercised by the
temporary-key protocol check are present in the retained 22; the nine other
retained permissions were preserved even though the new-key form did not offer
them. Application restriction None is unchanged on every key. No key value was
revealed, replaced or rotated; no quota, enabled-service, account, application,
domain or device setting was changed by this operation.

Evidence: `artifacts/phase2-gates/20260905/firebase-allowlist-execution-checkpoint.json`
records exact retained names, key IDs, before/after counts, per-key readback times,
explicit approval and prior blocked history. Existing protocol evidence is reused,
not rerun: 7/8 initial legs passed, and the failed macOS leg passed on its sole
fresh-installation retry. The original 404 remains unexplained and preserved.

This is a saved-configuration PASS, supported by the earlier 13-entry-subset
protocol check. It is not literal post-change testing under the 22-entry policy,
native FCM delivery, all-platform behavior or a production-readiness declaration.
The console warns settings may take up to five minutes to take effect; no claim
of independently measured enforcement propagation is made. No new test, build,
phone use, deployment, commit or push ran for these saves.

## Production Android signing fingerprints - CONFIGURATION PASS - 2026-09-05

The owner explicitly approved adding the four missing public fingerprints to the
existing production Android app, preserving every existing fingerprint and key
restriction. The target was verified before editing and after a full page reload:
Firebase project `chronospark-app` (project number `956622397052`), app
`1:956622397052:android:3ecf5fcda0f2e1ef9133f9`, package
`com.ghostheart5.chronospark`, display name ChronoSpark - Production Android.

The public certificate ZIP was downloaded from this app's Google Play signing
page (developer `7769568821533010883`, app `4976364997895633041`). The archive
`C:\Users\keegan radetski\Downloads\certificates (2).zip` contains three public
DER certificates, not private signing keys. Its SHA-256 is
`A90795C642CD0C3F9071D4FB3B493FCD8B74BBDF6DC0361B4FF21B05E8C7E7AC`.
An independent helper rehashed the archive and confirmed all four approved values.

| Public certificate | Added SHA-1 | Added SHA-256 |
| --- | --- | --- |
| `deployment_cert.der` | `02AAEC19CEA32F4515ADBDBAFC5C9B4C336C0AC0` | `B83E421ACC081168EA6F7A1672532659DC87B00D69779E86E4B802064FB7D7DB` |
| `hybrid_pqc_cert.der` | `CE03D3932FE9EDE28DDC7D50CE77DAF171E3CC5E` | `6FF01E7366A89872ED2FB96A495C71F692BC57E5E3C27B071FBD442B156390F9` |

All four saves completed. At **2026-09-05T14:10:48.223Z**, independent readback
after reloading the page confirmed **exactly 10 unique fingerprints: all six
originals plus exactly the four approved additions**. Both fingerprints for
`hybrid_classical_cert.der` were already registered and remain unchanged. No
fingerprint was removed, no signing identity changed, and no API key or key
restriction was edited during this operation. The separately verified three-key
22-API policy remains the prior configuration evidence, not a new runtime test.

Evidence: `artifacts/phase2-gates/20260905/firebase-signing-fingerprint-checkpoint.json`
retains the exact before/additions/after sets, archive hash, target identity,
approval scope and readback timestamp. The second helper reviewed the completion
wording and evidence limits; neither helper changed cloud settings or files.

This closes the identified Play certificate inventory/registration gap only. It
does not prove native SDK/auth/notification behavior, propagation, final-candidate
signing parity, staged API application-restriction compatibility or production
readiness. No app test, build, phone/emulator use, deployment, private-key access,
provider request, commit or push was performed for this repair.

## Completion attempt and exact handoff - 2026-09-05 14:16 UTC

The owner requested complete Phase 2 closure. Exactly the same two helpers were
reused, without changing model/reasoning settings. The remaining restriction and
provider gates were reviewed against current official documentation; completed
test suites and production changes were not repeated.

Fresh provider Console readback shows `ghostheart131517@gmail.com`, Dom's
Individual Org, only the Default workspace, and **API keys 0**. The page still
offers Evaluation access and billing setup. This is not evidence identifying or
revoking the previously disclosed key, and it supplies no replacement-key ID.
Fresh production Supabase secret-metadata readback still shows
`ANTHROPIC_API_KEY`, updated **2026-09-02 14:08:20 UTC**. Only names/timestamps
were inspected; no secret value was revealed or retrieved. Presence and date do
not establish which provider key is installed or whether it authenticates.

The public Supabase changelog was checked; no relevant breaking change was found
for this metadata inspection and credential-verification planning. No schema,
function, cloud setting, credential or feature-enable flag was changed.

### Firebase baseline - OWNER ACCEPTED; per-app hardening remains a follow-up

[Firebase guidance](https://firebase.google.com/docs/projects/api-keys) requires
appropriate API allowlists, treats these client identifiers as public, and
instructs developers to stage restriction changes before production. Google
recommends application restrictions, but allows only one restriction type per
key. The exact-22 Firebase-only allowlists already have saved readback; that does
not prove per-application restriction compatibility.

The owner explicitly answered **"Yes-accept the baseline and retain the hardening
follow-up"** to the specific request to accept the verified Firebase-only API
allowlists for Phase 2 while deferring extra per-app restrictions until native
compatibility testing. This resolves the Phase 2 Firebase baseline disposition;
it does not report per-app restrictions implemented, not applicable, or tested.

Retain all three existing keys and their verified API allowlists. Application
restrictions remain None. Additional per-app hardening is an accepted residual
follow-up, not erased from the closeout plan. Before any such production change:

- Android: verify package/SHA-1 pairs for production and retained legacy signers,
  then stage native compatibility on an approved isolated test key.
- Web/Windows: do not apply browser-referrer restrictions to the shared key;
  establish actual web origins and a separately approved browser-key migration
  while preserving Windows and older clients.
- iOS/macOS: establish the actual bundle identity sent by both native clients
  and stage compatible restrictions. Preserve the current identities; do not
  rename the macOS bundle merely to make a restriction fit.

No client was retired, key split, credential created or restriction saved by
this acceptance. Native compatibility remains unverified; Phase 6 still requires
the replacement-phone handoff and final-candidate proof.

### Provider credential closure - exact remaining sequence

1. Access the provider account/workspace owning the disclosed key. Establish
   its exact non-secret key ID and revoked/disabled/archived status from provider
   metadata or a provider-confirmed record. Do not reuse the exposed key for a
   probe. A newly created account or replacement does not revoke the old key.
2. Identify or create an explicitly approved replacement scoped to the intended
   workspace. The current proxies use `x-api-key` without
   `anthropic-workspace-id`; do not silently introduce a key requiring new
   workspace-selection handling. Credential entry and submission require owner
   handoff; never paste a key into chat or a committed file.
3. Install the intended replacement as `ANTHROPIC_API_KEY` in production project
   `qpwhuckyirnqtmvhpede`, with a sanitized record linking its non-secret ID to
   that destination. Preserve feature containment and other secrets.
4. With separately scoped approval for a protected server-side execution path,
   run one provider credential check using that installed server-held secret.
   Anthropic explicitly documents `POST /v1/messages/count_tokens` as free;
   use the configured model, a fixed nonpersonal string, no tools or history,
   and no message-generation request. Require HTTP 200 and a valid nonnegative
   integer `input_tokens`; record timestamp, request ID and provider identity
   metadata only. Do not expose a public diagnostic route. Any temporary
   diagnostic deployment and its cleanup need an exact approved scope.

A successful local check of a separately copied key would not prove the installed
production secret. A token-counting authentication pass would not prove paid
generation, privacy approval, model safety, billing, or final-device behavior.
The current proxies have no suitable non-generating diagnostic route, so none
was invoked and no temporary route was deployed during this attempt.

References: [Claude authentication](https://platform.claude.com/docs/en/manage-claude/authentication),
[free token counting](https://platform.claude.com/docs/en/build-with-claude/token-counting#pricing-and-rate-limits),
[Supabase secret handling](https://supabase.com/docs/guides/functions/secrets).

Phase 2 remains **incomplete at an owner/credential-access handoff**, not a test
failure. No new key, purchase, provider request, device use, build, test-suite
run, commit or push occurred in this completion attempt.

## Provider account corrected; organization-level key found - 2026-09-05 14:26 UTC

After the owner signed in again, live account readback confirmed
`domnichols39@gmail.com` / Dom Keegan Radetski, not the earlier
`ghostheart131517@gmail.com` session. The Default workspace still showed zero
keys, but that workspace-only result was incomplete for organization-scoped
credentials. Organization settings > API keys, with Created by Anyone, Type All,
Status All and Workspace All, showed one key:

- Name: **Dom**; record ID `apikey_01JxbP8RRmLPrBaaZkR1fRbb`.
- Status: **Active**; type Personal; scope Organization.
- Created by `domnichols39@gmail.com`; created September 2, 2026.
- Expires October 2, 2026; Last used displayed a dash (not proof of no use).
- Its masked preview's visible ending matches the previously disclosed key's
  ending. This is a strong candidate, not a full-secret comparison or proof that
  the same key is installed in Supabase.

The account-access blocker is resolved. The earlier zero-key workspace reading
must not be presented as a current organization-wide inventory. The exact key's
inspector exposes Disable API key and Delete API key; neither was activated.
The owner was asked to approve disabling only this identified candidate, with
the explicit warning that consumers using it would fail until replacement. No
deletion, new-key creation, replacement, provider request or secret-value reveal
occurred. The display preview was suppressed in tool output; only a boolean
ending-match result was retained. Key status and replacement verification remain
open pending the exact action and readback.

## Approved provider-key disablement - PASS - 2026-09-05 14:28 UTC

The owner explicitly approved disabling the exact exposed-key candidate Dom,
created September 2 under `domnichols39@gmail.com`, with the warning that any
consumer using it would stop authenticating until a replacement was installed.
Immediately before the action, the inspector still showed the exact record
`apikey_01JxbP8RRmLPrBaaZkR1fRbb`, Personal / Organization, Active, and the expected
owner. Disable API key was selected, followed by confirmation of Disable key?
for Dom. No other record was changed.

After the save completed, both the table and inspector showed **Disabled**.
A full page reload independently confirmed the same exact record ID and owner,
Disabled status, no Active status, and one organization-level key record at
**2026-09-05T14:28:01.899Z**. This supersedes the pending-disablement checkpoint
above. The owner-approved candidate is now disabled; no full-secret comparison
or proof of identity with the currently installed Supabase secret was performed.

Anthropic documents Disable as reversible (Admin API status `inactive`), unlike
permanent Delete/archive. Record this as **saved disablement verified**, not
permanent deletion. No request used the old credential to test enforcement. Do
not re-enable this exposed-key candidate as a recovery shortcut.

No replacement key, service account, paid request or diagnostic route was created.
The existing Supabase secret was not read, replaced or removed. Any consumer
still using the disabled key needs an approved replacement. The remaining gate
is a scoped replacement-credential handoff, installation provenance and a
protected, non-generating check using the installed server-held replacement.
Source/client containment and all Firebase settings remain unchanged.

Reference: [Claude disable versus delete semantics](https://platform.claude.com/docs/en/manage-claude/authentication#api-keys).

Replacement preparation only: the corrected account's Active service-account
inventory shows no service accounts. A draft Create service account form is
prepared with name `chronospark-supabase-prod`, organization role **Developer**
(not Admin), and only the Default workspace displayed. It has not been submitted.
Creation of this new API identity requires exact owner approval; creation of a
replacement key and direct secret-entry handoff remain subsequent steps. No
federation issuer, rule, payment or additional workspace is proposed here.

## Owner-created service account - PASS; replacement key draft only - 2026-09-05

The owner reported clicking Create on the prepared service-account form. Fresh
table/inspector readback and an independent full reload verified the saved account
at **2026-09-05T14:32:49.142Z**:

- Name `chronospark-supabase-prod`; ID `svac_01ErTRqsVrWv8YS4qNsPubbA`.
- Listed in Active accounts; organization role **Developer**, not Admin.
- Exactly one workspace: **Default**, with **Workspace User** role.
- **Zero API keys** and **zero federation rules**.

This supersedes the earlier unsubmitted-service-account checkpoint. It proves
the account configuration, not creation or installation of a replacement key.

From that account's inspector, a Create API key form was opened and prepared:
name `chronospark-supabase-prod-20260905`, linked identity exactly the service
account above, scope **Default workspace**, expiry **30 days (October 5, 2026)**.
The form explicitly states that this scope cannot use the Admin API. The **Add**
button was not clicked by the agent; creation and subsequent secret entry are
handed to the owner. No key value was generated, read, copied or installed.

If the owner creates this 30-day credential, record its actual saved expiry and
complete rotation before that deadline; do not silently extend it to Never or
claim a rotation reminder/automation has been created. No payment, federation,
additional workspace or role change was made by the agent during this check.

## Replacement created; production installation handoff - 2026-09-05

After the owner requested installation, the existing service-account inspector
showed **API key created**, **API keys 1**, and the expected key name
`chronospark-supabase-prod-20260905`, Default scope, created September 5, 2026.
This supersedes the draft-only key checkpoint. The key record ID and saved
expiration still need metadata readback; the previous draft selected October 5.
Credential text was suppressed from returned output. No clipboard read, secret
copy, credential entry or paid provider request was performed by the agent.

The production Supabase secrets page was reopened for exact project
`qpwhuckyirnqtmvhpede`, main PRODUCTION. The existing `ANTHROPIC_API_KEY` still
displayed the September 2 14:08:20 UTC update time. Only the Name field in Add or
replace secrets was filled with `ANTHROPIC_API_KEY`; Value remained empty and
Save was not clicked. The owner must paste the new full key directly there and
complete Save. Do not paste it into chat or use the masked preview as a secret.
Installation is **not yet verified**; saved metadata and the protected server-held
credential check remain required afterward. Other secrets were not modified.

## Owner-saved secret update - metadata PASS; server authentication pending - 2026-09-05

After the owner reported completing Save, production project
`qpwhuckyirnqtmvhpede` showed `ANTHROPIC_API_KEY` updated at
**05 Sep 2026 14:44:19 (+0000)**. An independent full reload confirmed that
timestamp at **2026-09-05T14:48:00.949Z**. The entry form was cleared. Other
custom-secret names and update times were unchanged. This supersedes the
installation-handoff checkpoint above: the owner's secret update is saved.
No credential value was revealed, copied, or printed by the agent.

The provider organization inventory separately confirmed replacement name
`chronospark-supabase-prod-20260905`, created by `domnichols39@gmail.com`, linked
to service account `chronospark-supabase-prod`
(`svac_01ErTRqsVrWv8YS4qNsPubbA`), scope **Default**, created September 5,
and saved expiration **October 5, 2026**. It was the only record returned by
the **Status Active** filter. The unfiltered inventory also showed the old Dom
record still **Disabled**. The replacement's exact key record ID was not
retrieved. Rotate before October 5; no reminder automation was created.

These are saved-update and provider-metadata checks, not a comparison of secret
contents or proof that the installed value authenticates. No provider request
was made. The existing production functions have no dedicated non-generating
credential check. A proposed temporary, admin-only server-side check would read
the installed secret inside Supabase and make one fixed, non-personal token-count
request, then be deleted and independently checked absent. Deployment, invocation,
and cleanup require scoped owner approval and a verified protected invocation
path; none has been performed. Existing functions, database data and billing
were not modified by this verification.

## Approved server-held check - credit-blocked; cleanup PASS - 2026-09-05 15:03 UTC

The owner approved temporary admin-only deployment, a non-generating credential
check, and removal. Only `phase2-credential-check-20260905` was deployed
(ID `216f1fcc-8dfc-49fc-a2b3-9d710776c10a`). The handler used fixed
`claude-sonnet-4-6` token counting with the server-held `ANTHROPIC_API_KEY`;
no user data, arbitrary input, generated message, or database access was used.

Current Supabase dashboard authorization uses a secret key on `apikey`.
Accordingly, this temporary function alone used `verify_jwt=false` with explicit
fail-closed equality validation against existing `SUPABASE_SECRET_KEYS`, not
public access. It also had a fixed 15:20 UTC expiry, POST-only invocation,
15-second upstream timeout, no secret/error-body logging and no-store responses.
The dashboard inserted an existing administrative key; its value was suppressed
from tool output and was not saved to local artifacts. Existing function auth
settings were unchanged. An unauthenticated live request returned **403**.

Local Deno check and lint passed for the diagnostic. Deployed v1 source was read
back. The first admin request returned upstream HTTP **400** at
`2026-09-05T15:02:06.268Z`, request `req_011CekVeC95qFr9dteZdcG9C`.
One focused retry followed a diagnostic-only update adding an allowlisted error
classification (no raw provider message). At **2026-09-05T15:02:37.776Z**, it
returned **400**, `insufficient_provider_credits`, request
`req_011CekVgWyDgNarwkKJ4BY2A`, with organization
`481a4381-f1cb-43b2-a749-0d2a408395ac` and expected Default workspace
`wrkspc_015MTvox1RzbTyqFSYqZxUqe`. This establishes a real installed-secret
request reaching the expected provider context; it is not an HTTP-200 operation,
full-secret/key-ID equality proof, or paid-generation readiness. No further
provider retries were made. Anthropic documents token counting as free, but this
account's actual request was still rejected by its credit gate.

The exact temporary function was deleted after inspection of its named
confirmation. Independent MCP inventory then showed only the original seven
functions, all with unchanged IDs, versions, hashes and JWT settings from this
turn's preflight. A direct request to the removed endpoint returned **404**;
cleanup was verified by **15:03:22 UTC**. The production function is gone;
non-secret local source and result evidence remain under
`artifacts/phase2-gates/20260905/credential-check/` for auditability.
No funds, recurring payment, replacement key, user-data change, app-function
change, commit/push, suite rerun, phone action or Phase 3 work occurred.

Sources: [Supabase function authorization](https://supabase.com/docs/guides/functions/auth)
and [Anthropic token-count pricing](https://platform.claude.com/docs/en/build-with-claude/token-counting#pricing-and-rate-limits).

## Phase 2 items still open

- The narrow production deployment above is complete; remaining gates follow.
- Firebase API-allowlist reduction is complete for the configuration scope above.
  The identified Android Play signing-fingerprint registration gap is now closed.
  The owner explicitly accepted this baseline for Phase 2; additional application
  hardening remains a recorded compatibility-dependent follow-up, not an open
  Phase 2 exit gate or a claim of implemented application restrictions.
- Auth redirect ownership/cleanup is now verified as recorded above; no further
  legacy-redirect decision is pending.
- Establish rotation/revocation evidence for the previously disclosed AI-provider
  credential and validity of required server configuration. Secret-name presence
  and the freshly read-back update timestamp do not prove current validity.
  The exact owner-approved organization-level Dom candidate is now Disabled,
  independently reloaded as recorded above. The Default workspace's zero count
  did not include that record. The owner's saved replacement update and the
  provider's Active replacement metadata are now verified above; a real
  server-held check has now run and reached the expected provider context, but
  its successful-operation gate remains blocked by insufficient provider credits.
  Never paste keys into chat. The owner performed provider-secret entry; no
  provider secret was retrieved, printed or entered by the agent. It was used
  only inside Supabase for the two fixed non-generating requests above.
- Carry native FCM initial-install/upgrade/permission/delivery proof to the final
  candidate and Phase 6 replacement-phone testing. Do not use the old phone now.

Phase 2 remains incomplete. The owner subsequently explicitly directed Phase 3
to start while the provider-credit gate is deferred. No further Claude checks
or funding work is required to proceed with Phase 3 source repairs. No
production-ready claim.

Remaining Phase 2 owner action: resolve the provider's insufficient-credit gate
in the correct organization, then authorize a bounded recheck. No funding or
payment was authorized or performed. The temporary check and cleanup approval
was used and cleanup is complete. The dedicated service account is verified;
the corrected provider account is accessible and
the exact approved old-key candidate is disabled. Retained
client scope and staged per-app restrictions remain the accepted follow-up above.
No platform-retirement choice is inferred. Do not delete projects, keys or signing
identities. Any exact live restriction/rotation plan retains scoped approval.
