# ChronoSpark release-readiness audit — c2d83bc0

Audit date: September 8, 2026, America/Chicago; some evidence timestamps are September 9 UTC.

**Decision: NO-GO for a new Google Play internal-testing release of this revision.** Confirmed account-boundary and recovery defects, backend policy discrepancies, and missing current-source production artifact/device evidence prevent approval. A passing unit suite would not remove these blockers.

**Audit execution complete:** the scheduled local and emulator checks have terminal outcomes. Fourteen findings below distinguish application/data defects, release/configuration gaps and test-tooling defects. Unavailable production-build, physical-device and store requirements remain explicitly UNVERIFIED; they are not passes.

## 1. Candidate, authorization, and preservation

| Item | Observed state |
| --- | --- |
| Repository | `C:\Users\keegan radetski\Documents\Codex\2026-09-01\t\ChronoSpark-app-only-priority2` |
| Origin | `https://github.com/ghostheart5/fantastic-guacamole.git` |
| Branch | `fix/aab-prebuild-cleanup-20260905` |
| Audited source | `c2d83bc0dd0c7b512e2d2b152a7ca2a230c73b30` |
| Commit performed before audit | `Repair planning context and domain connections`; 42 files, 2,118 insertions, 173 deletions |
| Source version | `4.1.0+2026083021` |
| Android application ID | `com.ghostheart5.chronospark` |
| Intended distribution | Existing Google Play **internal-testing** track, cloud production flavor with the private internal billing cohort; no public production rollout |
| Build snapshot | Detached, clean source worktree at `C:\src\chronospark-audit-c2d83bc0`, used to avoid changing or cleaning the working checkout |
| Existing dirty files preserved | `docs/engineering/LEVEL20_REPAIRS_20260908.md`, `public-surface/google-play/GRAPHICS_REQUIREMENTS_20260908.md`; pre-existing untracked release reports/artifacts also preserved |
| Instructions found | No applicable `AGENTS.md` found in the repository or its ancestors |

The user's explicit **COMMIT** instruction authorized the completed planning repairs to be committed once, before the attached audit began. The subsequent audit did not authorize app repairs, dependency upgrades, additional commits, push, upload, publication, or production account/data/settings changes. Test fixtures, local builds and this evidence report are within scope. No monkey or level-20 endurance run is part of this audit.

The repair commit's 41 source/test files were compared with the frozen hashes from the preceding repair validation before staging. The repair report was the 42nd committed file. Pre-existing release-note and graphics edits were excluded. **No push was performed.** `R/source-preservation.json` confirms no source diff in the working checkout or clean build snapshot, matching lockfiles, ignored signing inputs, unchanged preserved QA APK hash, and the same two pre-existing tracked dirty documentation files. This report and audit evidence were created separately and were not committed.

Requirements were derived from the attachment; `docs/CI_CD_RELEASE_GATES.md`; `docs/RELEASE_TEST_PLAN.md`; internal billing/release documentation; production configuration and source contracts; and current official Play requirements. Historical release notes are evidence of their named earlier source/build only. Current source documentation cannot establish current Console or deployed behavior by itself.

## 2. Evidence boundaries and environment

Evidence roots, relative to the repository:

- **R** — `test-results/release-audit-c2d83bc0/`: command ledger, static gates, current full-suite output, build attempts, emulator preparation, dependency inventory and historical AAB reinspection.
- **S** — `test-results/audit-security-c2d83bc0/`: account-race diagnostic fixture and result, read-only deployed backend source/catalog/grant/scheduler evidence, `LIVE_BACKEND_AUDIT.md`.
- **F** — `test-results/audit-feature-c2d83bc0/`: additional synthetic feature diagnostics. These deliberately test required behavior; a failed diagnostic is a reproduced defect, not a successful regression check.
- **Prior repairs** — `test-results/planning-connections-20260908/`: 2,632 passing Flutter tests, 143 focused rechecks, clean analysis and coverage evidence tied to the frozen source hashes. This is earlier evidence, kept separate from the fresh audit run.
- **Historical release** — `artifacts/releases/4.1.0-2026083021-internal-billing-verified/`: an already produced artifact from source `c5564ef2c920047a3aa1a335b46eb58b4d8d17b6`, **not** the audited revision.

| Evidence lane | What was actually available | Limit |
| --- | --- | --- |
| Code review | Current commit, feature/provider/use-case/repository paths, Android manifests/Gradle, Edge Functions, migrations, release and public-site files | Establishes implemented contracts and source defects; cannot prove live runtime outcomes |
| Automated tests | 2,632 canonical Flutter tests passed; 15 QA configuration tests passed; fresh formatting/analysis/release scripts; 131 Deno tests; 20 candidate-build contracts; seven billing-backend contracts; five additional diagnostic invariants failed and reproduced defects | Mocks and host execution do not prove Android/Play purchase flows or gateway acceptance; diagnostic failures are separate from the passing canonical suite |
| Emulator | Fresh Android 16/API 36 ATD on `emulator-5580`, 320 × 640; canonical QA APK installed/launched; 11 terminal Maestro cases total: seven PASS, four FAIL; manual Creator title entry worked; native 200% font probe captured and restored | ATD is not a Google Play billing test device, and QA/mock authentication is not the cloud production candidate |
| Android app-root integration | Same commit/device, separately built default integration profile/test fakes, no QA define file: original four-file run nine cases/eight PASS/one ERROR at 320 × 640; unchanged auth-file retry six PASS at 411 × 891 | Integration-test APKs differ from the retained QA APK; larger-viewport success does not erase the original small-screen harness error or establish production authentication/billing |
| Physical device | Previously used Moto was offline during the audit; reconnect details awaited | Earlier installed-build acceptance and level-20 history do not validate this source |
| Live backend | Read-only management metadata, nine deployed source files, migration IDs, catalog/grants, advisors and latest scheduler statuses; synthetic invalid deletion-status capability probe returned gateway HTTP 401 | No production account writes, credit spending, live provider request or destructive deletion test |
| Store Console | Existing authenticated internal-track tabs identified; three controlled-tab reads timed out | No fresh maximum version, release state, license tester, product, reviewer access or declaration attestation |
| Production artifact | Guarded build of exact source attempted and stopped before compilation for missing required configuration | No current-source signed AAB, installation or runtime proof |
| Historical artifact | Previous 3021 AAB freshly checked for hash, signature, manifest, native alignment and bundled mapping | Useful baseline only; cannot inherit a PASS for the new source |

Host: Windows; Flutter 3.44.6 / Dart 3.12.2; Android SDK at `C:\Android\Sdk`; current Android work uses JDK `C:\Users\keegan radetski\AppData\Local\Programs\jdk-17.0.20.1+1`; PowerShell 5.1, Python 3, Node 24.19.0, Deno 2.9.4 and Git 2.54.0 available. Local Deno differs from the CI pin of 2.1.4; these are local results, and exact CI-environment parity remains unverified. Version outputs are preserved in `R/tool-versions.json`; individual historical inspection commands remain in its inspection JSON. Exact per-command executable/arguments, duration and exit code are recorded in `R/static-checks.json` and the named manifest files.

The host has approximately 15.16 GiB RAM. Concurrent suite/build/emulator execution reduced free memory to approximately 0.02 GiB. The auditor stopped only the audit-owned Gradle client/daemon and `emulator-5580`, then sequenced work. The first local QA APK attempt was explicitly canceled, producing no APK; this is a **host resource limitation**, not an app compilation error or an observed app memory leak. `android/gradle.properties` permits an 8 GiB JVM heap plus 4 GiB metaspace. Later bounded debug observations are recorded below; representative release performance remains unverified. Approximately 26.65 GiB disk space was free at audit start; historical artifacts were preserved.

Final disposition is recorded in `R/final-disposition.json`: all test sessions completed; owned Gradle PID 50328 and emulator/QEMU PIDs 89916/98404 stopped, with no owned process remaining in that check. The readback showed 2,427.3 MiB free RAM and 21.22 GiB free on C:. Evidence, the preserved QA APK and the build snapshot were retained. `R/source-preservation.json`, refreshed at approximately 02:50 UTC on September 9, confirms unchanged app source, equal root/snapshot lock hashes and the retained QA APK hash. No push was performed.

## 3. Requirement matrix

PASS is confined to the stated evidence and requirement. FAIL means an executed check or inspected contract contradicts the requirement. UNVERIFIED means evidence is incomplete or unavailable. No percentage is assigned.

| Requirement | Status | Evidence | User impact | Next action |
| --- | --- | --- | --- | --- |
| Exact source, version, branch and release channel identified | PASS | Section 1; commit and frozen source-hash comparison | Prevents testing or shipping the wrong revision | Keep this identity attached to all subsequent evidence |
| Existing work preserved and authorized commit scoped | PASS | 42-file commit; `R/source-preservation.json` confirms no source diffs and unchanged lock/APK hashes; unrelated dirty docs/artifacts preserved; no push | Preserves ongoing release work | Keep the audit report/evidence separate from the committed repairs |
| Formatting clean without rewriting source | PASS | `R/format.txt`: 1,161 files, zero changed | Consistent source formatting | No repair required |
| Static analysis with fatal infos | PASS | `R/analyze.txt`, exit 0 | No analyzer findings in this environment | Preserve result with source identity |
| Architecture, workflow and script validation | PASS | `R/static-checks.json`; architecture/workflow/PowerShell logs | Required structural/tooling checks pass | Do not equate with app runtime proof |
| Tracked secret-content checks | PASS | `R/secret-content.txt`, `secret-contract.txt` | No tracked secret-content match reported | Retain distinction from ignored local files and binary scan limits |
| Clean committed snapshot secret-location guard | PASS | `R/clean-snapshot-secret-guard.txt` | No committed signing-secret location failure | Keep signing material external to build snapshots |
| Local signing-secret location policy | FAIL | `R/secret-filenames.txt`: populated passwords in ignored `android/key.properties` | Workspace fails its required secret guard | Relocate signing inputs outside the checkout under a separately authorized repair; no secret values are in this report |
| Current full Flutter suite completes with no failures/skips | PASS | `R/flutter-suite-manifest.json`: 2,632 passed, zero failures/errors/skips, exit 0, terminal success, 1,917.871 seconds | Existing canonical regression suite passes | Add the newly failing audit invariants during authorized repairs |
| Required repeated non-build validation | UNVERIFIED | Prior frozen-source repair run and fresh audit run each passed 2,632 tests independently; other gates have not all been repeated twice | Repository release plan calls for two independent executions of the full non-build gate | Record which checks satisfy both runs; rerun only outstanding required checks after repairs |
| Required coverage ratchet | PASS | `R/coverage-ratchet-console.txt`: 73.7% overall / 91.5% critical; exit 0 | Required coverage floors pass | Preserve LCOV provenance; do not equate line coverage with complete behavior |
| Higher feature coverage targets | FAIL | `R/coverage-target-console.txt`: domain use cases 82.4% vs 85%; paywall 86.6% vs 88%; backup 94.5% vs 95%; auth 89% vs 90% | Desired coverage remains below target in consequential feature areas | Add meaningful outcome/failure-path tests; target debt is separate from the passing required ratchet |
| QA environment configuration contract | PASS | `R/qa-config-manifest.json`: 15 completed/passed, zero failures/errors/skips | Canonical QA defines resolve as tested | Still inspect the built APK and actual runtime profile |
| Golden assertion presence | PASS | `R/golden-assertions.txt` | Golden suites contain expected assertions | Separately complete rendered baseline comparisons |
| Current Windows golden comparisons | PASS | `R/golden-readback.json`: 41 passing tests across four golden files, including eight exact logical comparisons; no baseline regeneration | Current host rendering matches reviewed Windows references in those fixtures | Preserve screenshots and exact-source linkage; this is not phone rendering evidence |
| Linux golden comparisons | UNVERIFIED | Current execution was Windows; Linux rendering not exercised | Platform-specific rendering regressions remain possible | Run the same logical comparisons against approved Linux baselines in the required CI environment |
| App-root integration suites complete with all cases passing | FAIL | `R/android-integration-summary.json`: original nine cases/eight PASS/one ERROR/zero skips, all terminal; unchanged auth retry at 411 × 891 passes six of six | The original small-screen run is not green; larger geometry confirms viewport dependence without repairing the harness | Correct scrolling and interaction assertions, then rerun both viewports; retain original failure |
| Native persistence and Planner identity integration fixtures | PASS | `R/persistence_recovery_test-manifest.json` and `planner_learning_identity_test-manifest.json`: one passing case each, no failures/errors/skips | The tested storage recovery and Planner identity roundtrips pass on Android | Keep fixture close/reopen distinct from cold-process termination, production upgrade or cross-account device proof |
| Maestro flow syntax/contracts | PASS | `R/maestro-contracts.txt`: 28 files validated | Scripts are structurally valid | Execute selected flows on a suitable installed app |
| Canonical Maestro journey suite completes with all flows passing | FAIL | `R/maestro-combined-result.json`: original two cases plus nine independent remaining flows = 11 terminal cases, seven PASS/four FAIL; not an uninterrupted canonical suite pass | Release automation cannot currently prove the full intended journey set | Repair stale selectors, successfully create the dependent lifecycle fixture, then rerun the canonical suite through completion |
| Independent remaining Maestro journeys complete with all flows passing | FAIL | `R/remaining-journeys.json`, `maestro-remaining/`: nine terminal runs, six PASS/three FAIL | Independent execution exposed two more title-selector failures and a dependent missing-fixture readback failure | Fix the shared selector compatibility and rerun account/lifecycle creation and readback together |
| Candidate build tooling contracts | PASS | `R/candidate-build-contracts.txt`: 20 tests pass | Guard behavior covered by fixtures | Actual candidate build still required |
| Required remote CI gates succeed for the exact committed candidate | UNVERIFIED | Commit is local and was not pushed; historical CI runs refer to older source | Approved candidate-build provenance and Linux/database platform gates are not established for this SHA | After separately authorized repairs/push, run required workflows for the final SHA and retain completed run IDs/results; do not substitute local tests or old CI |
| Billing backend preflight contracts | PASS | `R/billing-backend-contracts.txt`: seven tests pass | Configuration drift and authorization preflight logic covered by fixtures | Rerun authoritative preflight for the exact candidate under authorized release setup |
| Edge Function format, lint, type checks and tests | PASS | `R/edge-functions.txt`, JUnit: 38 source files; seven entrypoints; 16 test files; 131 passed, zero failed/errors/skips | Tested handler and billing/deletion failure contracts pass | Add gateway/cohort cases that current tests miss |
| Edge gate wrapper contract under local PowerShell | FAIL | `R/edge-gate-contract.txt`: PowerShell 5.1 treats benign Deno stderr as `NativeCommandError` before assertions | Local wrapper validation is unreliable in this shell; actual Edge suite still passed | Repair shell-compatible stderr handling and rerun the contract in supported shells |
| Supabase migration policy contract | PASS | `R/migration-policy.txt` | Migration tooling policy fixture passes | Complete database runtime fixtures separately |
| Dependency graph and advisory inventory | PASS | `R/dependencies/`: lock hash, SBOM, resolved/outdated manifests; 195 OSV queries, 195 results, zero matches | No matching advisories were reported by this query | Complete license/maintenance triage; no blanket security guarantee |
| Dependency license approval | UNVERIFIED | Dependency manifest explicitly does not infer license approval | Unreviewed third-party obligations | Record resolved-package license review and any accepted exceptions |
| New upload has an unused, increasing version code | FAIL | Source still `2026083021`; prior 3021 artifact/release history already exists | A new repair release cannot reuse an uploaded version code | Read live Console maximum and increment all authoritative version inputs before the next authorized build |
| Exact-source signed production AAB builds | FAIL | `R/production-build-attempt.json`: exit 1, no production AAB | No production release AAB exists for this commit | Supply reviewed cloud production inputs and rerun guarded build after repairs |
| Current-source canonical QA APK builds | PASS | `R/qa-x64-build.json`: x64 debug APK built, exit 0 in 450.49 seconds; source/hash recorded in section 7 | A current-source Android QA runtime is available for isolated device tests | Install/run it; do not treat QA mock authentication as production or Play billing proof |
| Current-source QA fresh installation and first activity launch | PASS | `R/qa-install-start.json`: package initially absent, install exit 0, cold start `Status: ok`; Welcome screenshot/UI hierarchy | Current QA app installs and reaches its first visible screen on API 36 | Continue onboarding/navigation/persistence checks; no production upgrade/authentication claim |
| Current production AAB signature, endpoints, flags, assets, secrets and symbols verified | UNVERIFIED | No current production AAB; current QA APK and historical release inspection are explicitly separate | Wrong signing/configuration or missing assets could block updates or expose data | Inspect newly built production AAB and bind every result to its SHA-256/source |
| Target API, Billing library and native-page compatibility in current AAB | UNVERIFIED | Source targets API 36; historical 3021 uses Billing 8 and aligned native libraries | Store rejection or device incompatibility possible if new artifact differs | Inspect current merged artifact; exercise 16 KiB runtime where required |
| Production-candidate fresh install, completed onboarding and return visit | UNVERIFIED | QA installation/first screen and seven scoped normal-state flows passed; no current cloud production candidate/device | Genuine onboarding/authentication and release return behavior remain unproven | Run complete fresh-install and signed-in/return paths on exact production candidate |
| Restart, background/resume and previous-Play-build upgrade preserve data | UNVERIFIED | Physical Moto offline; no current Play-delivered update | Account and local progress preservation not established | Reconnect device and test in-place Play update; do not uninstall/delete the user's data |
| Goal creation/update/completion stays within its initiating account | FAIL | `R/security-diagnostics-manifest.json`, console: delayed account A operation publishes A's goal title under B and awards 12 XP after provider fence | Private goal history and progression may enter another account | Fence every post-await continuation/side effect to the originating account; add regression coverage |
| Goal partial-save failure and retry cannot create duplicates | FAIL | `R/security-diagnostics-console.txt`: canonical save succeeds, injected reminder exception escapes, retry leaves two identical intended goals | Durable save is reported as failure, inviting duplicate retry | Separate durable-save result from recoverable notification/history side effects; make retry idempotent |
| Malformed stored goal records cannot be silently discarded | FAIL | `R/feature-diagnostics-console.txt`: three input entries become one goal with corruption false; next save overwrites original and creates no quarantine | A later mutation permanently removes omitted records from the saved payload | Treat partial parsing as unavailable/corrupt and preserve original data before mutation |
| Task/goal/rhythm/note/emotion planning connections are implemented | PASS | Current committed use-case/entity/provider review; prior focused repair tests | The repaired context connections are present in source | Complete runtime journey validation; PASS here does not cover all failure paths |
| Progression review distinguishes unavailable evidence from healthy zero workload | FAIL | `R/feature-diagnostics-console.txt`: failed inputs produce exact zero workload, manageable pressure and no unavailable-evidence acknowledgment | Users receive reassuring planning judgments based on missing data | Propagate evidence health and give an explicit unavailable/retry state |
| Creator, Planner, SI, Timeline and progression journeys complete on device | UNVERIFIED | QA Planner/SI/Timeline/Progression flows passed; Creator is blocked by F13 automation; only manual title entry confirmed | Covered normal paths work in QA; complete Creator save/restart and production behavior remain unproven | Repair the automation and complete all entry-to-result/failure journeys on exact candidate |
| Offline, timeout, interrupted save and repeated-tap recovery | FAIL | Reproduced account race; source-confirmed partial save; remaining device cases UNVERIFIED | Privacy leakage, duplicate actions or misleading success/error states | Repair confirmed paths, then fault-inject each required journey in an isolated test profile |
| Session expiry/account switch/termination recovery on device | UNVERIFIED | Unit and source evidence only; no current production device run | Users may become stuck or see stale account state | Exercise delayed responses, logout/login, kill/relaunch with two synthetic accounts |
| Server tables have RLS enabled and restricted policyless surfaces | PASS | `S/live-supabase-readback.json`, `live-table-grants.json`: all 56 public tables RLS-enabled; 15 policyless surfaces have no inspected client grants | Inspected catalog avoids accidental broad table access | Full negative account fixtures remain separately required |
| Complete end-to-end account authorization/isolation | FAIL | Goal race; `S/LIVE_BACKEND_AUDIT.md`; catalog review is not an adversarial fixture | Cross-account local side effects confirmed; other surfaces need runtime proof | Repair goal fencing and run isolated account/role authorization tests |
| Local storage protection, encryption/key handling and Android backup exclusion | UNVERIFIED | Source/storage review and account-scoped fixtures; current QA and historical release manifests have `allowBackup=false` and cleartext disabled; no current production device-at-rest inspection | Sensitive goals, notes and emotional context require appropriate local protection | Inspect current production artifact backup/extraction rules and scoped storage/key handling; use a safe device fixture to verify logout/switch and recovery without exposing data or keys |
| Backup/export/restore preserves ownership and data safely | UNVERIFIED | Host backup-service coverage is 94.5%; no fresh current-build device export/import/restore roundtrip | Backup could lose data, expose personal content or restore it into the wrong account | Use synthetic data to test protected export, import validation, account binding, corrupt/wrong-key backup, interrupted restore and recovery readback |
| Diagnostic logging and third-party SDK privacy match claims | UNVERIFIED | Tracked secret-content scan passes; historical manifest disables automatic analytics/Crashlytics collection; current compiled/runtime network and logs unverified | Personal content or identifiers could be logged or transmitted unexpectedly | Inspect effective current flags, consent transitions, redacted device logs and SDK traffic using synthetic inputs; verify no purchase tokens, notes or credentials appear |
| Pending account deletion status works after sign-out | FAIL | App no-bearer status request; deployed `account-delete` v11 `verify_jwt=true`; synthetic no-bearer status probe HTTP 401 in `S/deletion-status-gateway-runtime.json` | A legitimate signed-out deletion-status request is rejected before its capability branch | Provide a gateway-compatible capability status path and test it through an isolated gateway |
| Complete account deletion and recovery evidence | UNVERIFIED | 131-test backend lane covers state-machine fixtures; no fresh destructive production test | Cannot certify completion, retention and failure reconciliation end-to-end | Use disposable test account in safe environment; verify auth/storage/database/status/reconciliation results |
| AI internal cohort enforced by trusted backend | FAIL | Deployed `ai-proxy` v15 and live reservation/principal definitions; `S/LIVE_BACKEND_AUDIT.md` | Client containment does not limit authenticated server callers to the intended testing cohort | Add server-owned cohort authorization before quote/reserve/provider access; test denial without spending |
| One consistent, authoritative credit spending policy | FAIL | Live legacy `consume_monetization_credits` remains client-executable and differs from current allowance/spend-order policy | Older/direct callers can follow incompatible debit rules | Revoke or safely migrate obsolete endpoint after compatibility review; test rollover and order |
| Current purchase, pending instruments, restore and subscription lifecycle on Play | UNVERIFIED | Backend contracts and historical device evidence; no current Console/device confirmation | Real purchase/entitlement changes are not validated for this source | Use license testers/test payment methods on exact Play build; verify backend and UI readback |
| Current credit quote, consent, debit, refund and top-up journeys | FAIL | Backend policy mismatch above; contract tests pass; current runtime remains UNVERIFIED | Spending policy and promised isolation are not fully trustworthy | Correct authority boundaries, then test successful/failed/repeated and interrupted spending safely |
| Notifications, denied permissions, deep links, audio and sync behavior | UNVERIFIED | Source/configuration review and scoped QA flows; full representative integration/permission/audio runtime not demonstrated | Lost reminders, permission dead ends or broken links/audio remain possible | Test each enabled integration and document intentionally disabled cloud sync |
| Small screen, large text, screen reader, touch targets, focus/keyboard, contrast and reduced motion | UNVERIFIED | Current Windows pixel-match evidence/four inspected masters; native QA 200% font probe kept Continue visible but wrapped branding; no complete scroll or screen-reader walkthrough | Users may be unable to navigate, tap or understand controls outside covered fixtures | Run rendered/manual assistive and touch-target checks at supported text/device settings |
| Onboarding branding fits the narrow supported screen | FAIL | `R/qa-first-launch.png`, UI hierarchy: `CHRONOSPARK` leaves the final K alone on a line at 320 × 640 | The first impression appears visually broken at ordinary text scale | Make title layout responsive and verify narrow widths, text scaling and localized content |
| Startup, responsiveness, app memory and crash/resource behavior | UNVERIFIED | QA debug cold start 5,514 ms; process PSS 418,250 KiB; captured app log had no fatal markers; `gfxinfo` returned zero frames and cannot establish frame latency | Representative release performance/ANR risk remains unmeasured | Measure current release build under repeatable workload; retain debug observations without applying a production SLO |
| Deployed migration inventory and selected Edge source match repository | PASS | `S/live-parity.json`: 49 local/deployed migration IDs; nine retrieved source files match after newline normalization | Selected deployed handlers match reviewed source | Inventory parity is not byte-identical migration history or full schema equivalence |
| Scheduled maintenance jobs are active and last invocation succeeded | PASS | `S/live-cron-metadata.json`: four active jobs with successful latest records | Scheduler is executing inspected tasks | Separately test full expiry/refund/scrub outcomes and deletion-reconciliation pipeline |
| Privacy/support/deletion disclosures match enabled internal feature scope | FAIL | Live public pages 200 and match local source; universal no-AI/no-subscription/no-credit claims conflict with enabled private cohort | Testers receive inaccurate disclosures for available features | Reconcile copy with public containment and internal feature availability before distribution |
| Live Console declarations, reviewer access, license testers and catalog verified | UNVERIFIED | Controlled existing tabs timed out three times | Release setup or paid testing may be incomplete | Restore Console access and read each field/status without inferring from repo files |
| Enabled permissions are necessary, accurately disclosed and recoverable when denied | UNVERIFIED | Historical AAB declares microphone, notifications and billing among other permissions; no current merged-manifest/permission-prompt runtime or live declaration check | Unnecessary access, unclear prompts or denial dead ends could prevent use or violate disclosures | Compare current artifact permissions with enabled features and Console declarations; test first denial, permanent denial, settings return and unaffected local alternatives |
| Current content rating and target-audience declarations fit enabled features | UNVERIFIED | Live Console could not be read; repository copy cannot attest submitted answers/rating | Incorrect audience/rating answers could misrepresent app content or block distribution | Read the current rating questionnaire, target audience and generated rating; compare with enabled AI, user-content and emotional-state features, then record the result |
| Final store screenshot/graphic acceptance | UNVERIFIED | Existing graphics requirements/history are not fresh final-candidate Console acceptance | Listing may misrepresent build or fail asset requirements | Verify each required form factor/asset; capture real functioning state and avoid fabricated level claims |
| Monitoring, support and bad-release containment operationally verified | UNVERIFIED | Public support page available; historical build disables automatic analytics/crash collection; scheduler metadata only | Limited production incident detection and unproven response path | Verify effective consent/configuration, crash ingestion, alert owner, support intake and rollback/disable procedure |
| Public production rollout approval | NOT APPLICABLE | User selected internal testing; this audit performs no publication | No public distribution is authorized | Reassess production-specific approvals before any later public rollout |
| iOS/App Store, Windows or web-store release approval | NOT APPLICABLE | Intended distributable is Android AAB through Google Play internal testing | Host tests do not authorize other platform releases | Open separate platform gates if distribution scope changes |
| Monkey and level-20 endurance execution in this audit | NOT APPLICABLE | Current authorized audit excludes those runs; existing user progress is preserved | Avoids unrequested stress/data changes | Obtain a later scoped request before resuming endurance work |

## 4. Findings and reproducible evidence

Severity uses **P1** for release-blocking privacy, data-integrity, server-authority or required-deliverable defects; **P2** for significant recovery/trust/configuration defects; **P3** for nonblocking maintenance concerns. The severity is tied to impact, not solely to a test's exit code.

### F1 — P1: delayed goal work crosses the account boundary

- **Location:** `lib/state/providers/goals_provider.dart:90`, `:126`, `:153`, `:176`.
- **Expected:** work initiated by account A may persist only under A; switching to B invalidates A's remaining UI/history/XP side effects.
- **Actual:** goal persistence awaits, then reads current providers for reminders/history/timeline/XP. The synthetic diagnostic held A's save, switched the active scope to B, invoked the full account-provider fence, released A's save and observed A's private goal title published with B's current owner scope. The canonical goal repositories remained scoped; the defect concerns post-save fan-out, not a demonstrated cross-account server-table write.
- **Reproduction:** run `S/goal_account_race_test.dart` through the repository Flutter wrapper; its first test uses two synthetic scopes and delayed storage, with no real account data. An initial isolated reproduction is in `S/goal-race-manifest.json`. The final `R/security-diagnostics-manifest.json` records both this and F5: two completed diagnostics, two failed, zero errors/skips, terminal exit 1. Console evidence shows canonical A has one goal, canonical B zero, B owns the emitted A-title history, and 12 XP is awarded.
- **Repair/verification:** capture and recheck the initiating account through every asynchronous boundary, including side effects; verify create/update/complete and logout/switch cases. Retain the diagnostic as an expected-pass regression after repair.

### F2 — P1: current source has no verified production artifact, and its version is already used

- **Location:** `pubspec.yaml`; `android/app/build.gradle.kts:89`; `scripts/build_android_aab_prod_guarded.ps1`; `R/production-build-attempt.json`.
- **Expected:** a new repaired candidate has an unused higher version code, guarded production configuration and a signed AAB whose source and SHA-256 are recorded.
- **Actual:** source still uses `2026083021`, already represented by the prior delivered artifact/source. Gradle's pinned version override must be considered; a Flutter CLI build-number alone is not sufficient evidence of the final manifest. The exact-source guarded attempt returned exit 1 before compilation for six missing required environment variables. No bundle was produced.
- **Missing inputs:** `CHRONOSPARK_SUPABASE_URL`, `CHRONOSPARK_SUPABASE_ANON_KEY`, `CHRONOSPARK_RECEIPT_VERIFY_ENDPOINT`, `CHRONOSPARK_AI_PROXY_ENDPOINT`, `CHRONOSPARK_ACCOUNT_DELETE_ENDPOINT`, `CHRONOSPARK_ANDROID_SHA256_CERT`. Only variable names are reported.
- **Configuration readback:** `R/local-production-config-presence.json` confirms the tracked local production define file's endpoint/key fields are empty; the required environment inputs were genuinely unavailable to the guarded attempt. No populated secret was exposed in this presence-only evidence.
- **Repair/verification:** after source defects are repaired, read the live maximum version, update authoritative version inputs and supply the reviewed production profile through the approved signing workflow. Build, inspect, install and run the exact artifact. A previous AAB cannot substitute.

### F3 — P1: internal AI containment is not enforced at the trusted service

- **Location/evidence:** `supabase/functions/ai-proxy/index.ts:131` authenticates, `:188` reaches quote construction and `:215` calls reservation without an intervening cohort gate; `supabase/migrations/20260830152232_harden_phase8_billing_authority.sql:456` and `:2187` define principal/wrapper authority, with current principal reservation at `supabase/migrations/20260908205414_monthly_allowances_and_credit_topups.sql:342`. Deployed `ai-proxy` v15 source and live principal/reservation definitions are in `S/deployed/` and `S/live-supabase-readback.json`; analysis in `S/LIVE_BACKEND_AUDIT.md`.
- **Expected:** the private internal AI/credit cohort is checked by a trusted authority before quote/reservation/provider access.
- **Actual:** the inspected deployed path checks authentication and billing context but lacks the intended internal-cohort authorization. A modified authenticated client can reach that path without the app's cohort UI gate. This is a source-and-deployed-contract finding; the audit did **not** call a provider or spend a noncohort account's credits. It is not a claim that unauthenticated callers receive free AI or that cross-account wallet theft was observed.
- **Repair/verification:** add a server-owned cohort gate ahead of costly actions; test unauthenticated, authenticated noncohort, authorized cohort and expired/revoked cohort identities with a stub provider and unchanged wallet assertions.

### F4 — P1: mixed malformed goal lists can be silently shortened and overwritten

- **Location:** `lib/data/repositories/goal_repository.dart:49`, `:54`, `:94`, `:126`.
- **Expected:** malformed entries make the read visibly incomplete; original data is preserved before any write, allowing recovery.
- **Actual:** `whereType<Map<String, dynamic>>()` silently filters primitive/list records; the method then clears the corruption flag. The quarantine method returns immediately when that flag is false. A subsequent save can replace the original payload with only accepted records plus the new goal.
- **Related source-only recovery gap:** even when corruption is recognized, quarantine read/write errors are caught at `goal_repository.dart:140`; the flag is then cleared at `:148`, allowing the caller's primary write to proceed. A failed preservation attempt should block destructive replacement. Runtime reachability and failure under deployed storage conditions are unverified for this variant; it is not included in the five reproduced diagnostic failures. Add a failed-quarantine regression before declaring data preservation repaired.
- **Reproduction:** synthetic in-memory payload containing one valid goal, a string and an array; read using the canonical repository, then save a new goal and inspect the primary/quarantine payload. `F/feature_diagnostics_test.dart` contains the isolated fixture. Final `R/feature-diagnostics-manifest.json` records three completed failures, zero errors/skips, including the two F4 invariants and F6. The F4 console shows three inputs becoming one returned goal with `lastReadCorrupted=false`; the subsequent save leaves neither primary nor quarantine preserving the original payload and no quarantine is present.
- **Repair/verification:** reject or explicitly represent partial reads, preserve original bytes, and block unsafe mutation until recovery is possible. Verify malformed JSON, mixed entry types and quarantine-write failure without altering real data.

### F5 — P2: post-save reminder failure is reported as a failed goal save

- **Location:** `lib/state/providers/goals_provider.dart:82`, `:90`, `:96`, `:153`; `lib/features/goals/ui/goals_screen.dart:288`.
- **Expected:** once canonical storage succeeds, the user receives an accurate durable-save result; retrying auxiliary work does not create another goal.
- **Actual:** canonical save completes before awaited reminder/history work. An auxiliary exception escapes as a general save failure. Retrying creation generates a new timestamp ID and duplicates the intended goal. The second `S/goal_account_race_test.dart` fixture injects one reminder exception after a successful save. `R/security-diagnostics-console.txt` confirms the first error and two identical intended goals after retry; the final manifest completes both security diagnostics with two failed invariants and zero errors/skips.
- **Repair/verification:** represent persisted success plus retryable side-effect failure, or use a durable idempotent operation record. Verify every fan-out failure, rapid retries, restart and accurate UI wording.

### F6 — P2: Progression review converts missing evidence into reassurance

- **Location:** `lib/state/providers/advisor_provider.dart:32`, `:39`, `:80`, `:109`; Progression review rendering at `lib/features/progression/ui/progression_screen.dart:751`.
- **Expected:** failed task/goal/log/trajectory reads produce an explicit unavailable review with recovery guidance.
- **Actual:** unavailable tasks fall back to zero, goals can appear empty, and default scores feed text such as manageable pressure and a zero-workload count. The summary does not carry input-health evidence through the review builder.
- **Reproduction:** override task/goal/log sources to failed states and trajectory to `error`, then read the actual weekly summary provider. The synthetic fixture in `F/feature_diagnostics_test.dart` asserts that unavailable evidence cannot yield healthy zero-workload advice. `R/feature-diagnostics-console.txt` confirms all three contrary outcomes: exact zero-workload text emitted, manageable-pressure reassurance emitted, and no acknowledgment of unavailable evidence. The final diagnostic manifest completes three failures, zero errors/skips, covering this and the two F4 invariants.
- **Repair/verification:** propagate source health before composing advice; distinguish legitimately empty history from errors and loading. Verify the rendered unavailable state and successful recovery.

### F7 — P1: signed-out deletion-status capability conflicts with deployed JWT enforcement

- **Location:** `lib/data/services/auth_service.dart:430`; `supabase/functions/account-delete/index.ts:108`; `supabase/config.toml:13`; deployed account-delete v11 metadata.
- **Expected:** after logout, a legitimate stored request ID/receipt capability can retrieve the account-deletion status as designed, without restoring a deleted account session.
- **Actual:** the app's status request intentionally omits Authorization and the handler has a capability branch, but deployed `verify_jwt=true` rejects the request at the gateway before that branch. A fresh POST using the same no-Authorization status shape and a synthetic invalid request ID/receipt returned HTTP 401 with `UNAUTHORIZED_NO_AUTH_HEADER` / `Missing authorization header`. This confirms the gateway rejection path without testing a real receipt or account. Existing no-Authorization mocked tests do not execute the gateway. No destructive production deletion was attempted. Evidence: `S/deletion-status-gateway-runtime.json`.
- **Repair/verification:** use a separately exposed capability endpoint or another design that preserves deletion authorization and makes status polling gateway-compatible. Exercise both valid and invalid capabilities through the actual test gateway, including expired/revoked sessions and reconnect/restart.

### F8 — P2: obsolete client credit-debit RPC contradicts current policy

- **Location:** `supabase/migrations/20260816210206_fix_monetization_credit_rpc_ambiguity.sql:60`, `:76`, `:111`, `:137`; deployed `public.consume_monetization_credits(integer,text,jsonb)` and grants in `S/live-supabase-readback.json`.
- **Expected:** all debit paths use the reviewed allowance, spend order and quote/reservation/settlement authority.
- **Actual:** the authenticated role retains execution on a SECURITY DEFINER direct-debit path. Its free-daily/250-monthly/4,000-yearly reset rules and purchased-first spending differ from the current 20/300 included allowance and included-first policy. No current Flutter call site was found. It is scoped to `auth.uid()`; this is **not** evidence of cross-account wallet theft.
- **Repair/verification:** assess legacy compatibility, then revoke or route through the canonical authority. In an isolated database, test direct-call denial or canonical behavior, rollover, insufficient balance and included/purchased order. Do not demonstrate by debiting production wallets.

### F9 — P2: current public disclosures contradict the enabled private cohort

- **Location:** `web/privacy/index.html:29`, `:32`, `:41`; `web/support/index.html:28`; `web/delete-account/index.html:35`.
- **Expected:** disclosures accurately distinguish public containment from AI, subscription and credit features available to internal testers.
- **Actual:** live privacy/support/deletion pages returned HTTP 200 and matched the local files, but universal disabled-feature claims do not describe the internal billing/credit candidate. Current Play listing fields remain unverified because Console reads failed.
- **Verification:** reread [privacy](https://chronospark.app/privacy/), [support](https://chronospark.app/support/) and [account deletion](https://chronospark.app/delete-account/) after separately authorized wording changes; cross-check current compiled feature profile and Console disclosures.

### F10 — P2: the working checkout fails its own signing-secret guard

- **Location/evidence:** ignored `android/key.properties`; `R/secret-filenames.txt`.
- **Expected:** real signing inputs remain external to the repository working tree according to the guard.
- **Actual:** the guard detected populated `storePassword` and `keyPassword` fields and exited 1. The separate tracked content scan passed. This is a local secret-location policy failure; no tracked leak or external disclosure was established. Values were not printed or included in the report.
- **Repair/verification:** move to the approved external signing-input location during an authorized repair, update local references safely, and rerun both secret guards. Assess rotation only if actual exposure evidence exists.

### F11 — P2: local Edge gate contract stops on benign stderr under PowerShell 5.1

- **Location/evidence:** `scripts/edge_function_gate_contract.ps1`; `R/edge-gate-contract.txt`, `supplement-static.json`.
- **Expected:** the gate contract reaches its assertions and judges the child process by the intended completion/exit behavior.
- **Actual:** PowerShell 5.1 promotes Deno's harmless `Checked 4 files` stderr output to `NativeCommandError`, stopping the contract before its assertions. The actual Edge gate independently completed 131 tests successfully; this tooling failure does not invalidate those test results or establish an Edge Function defect.
- **Repair/verification:** handle child-process stderr without mistaking routine output for failure; retain strict exit-code/terminal checks. Rerun the contract under the supported Windows shell and CI shell.

### F12 — P2: onboarding brand leaves a single orphan letter on a narrow screen

- **Location:** `lib/features/onboarding/ui/onboarding_screen.dart:220` and title style around `:463` (`fontSize: 40`).
- **Expected:** the ChronoSpark title remains deliberately composed and readable on a 320 × 640 device at normal text size.
- **Actual:** the current-source QA APK's first Welcome screen wraps the final K of `CHRONOSPARK` onto a separate line. The screenshot visibly confirms the broken title layout; this is independent of the earlier host resource stall.
- **Large-text observation:** the isolated native `font_scale=2.0` probe wraps the brand as `CHRONOSP` / `ARK`; the fixed Continue button remains visible. `R/qa-font-200.png`, `.xml` and `qa-font-200-probe.json` record the state and restoration to the original 1.0 scale. This limited capture is not a successful scroll/screen-reader/full-accessibility walkthrough.
- **Reproduction:** fresh install the recorded QA APK on API 36 `emulator-5580` at 320 × 640, cold-launch and inspect the Welcome title before continuing to login. Evidence: `R/qa-install-start.json`, `qa-first-launch.png` and its captured UI hierarchy. The Continue to Login control is present; the title issue alone does not establish that the control is blocked.
- **Repair/verification:** use an intentional responsive title treatment, then verify the real narrow-screen render, wider screens and large text. Add a layout regression representing the actual first-launch composition.

### F13 — P2: Creator/account/lifecycle automation uses an obsolete title-field selector

- **Location:** `.maestro/flows/05-creator.yaml:28` (repeated selectors also at `:88`, `:142`); `lib/features/creator/widgets/dynamic_form.dart:419` supplies `Title, required` semantics, with visible hints around `:272` and `:425`; native field hierarchy/manual probe in `R/creator-selector-probe.json`, `.xml` and `.png`.
- **Expected:** the canonical Creator flow can focus the title field, enter content and continue through the saved-result assertions after accessibility changes.
- **Actual:** the 11-flow QA suite passed Smart Planner, then Creator failed at `tapOn: 'Title *'` after 17,057 ms. The current native hierarchy exposes the field hint as `Title, required\nTitle *`. A manual fresh-bounds tap and typing successfully entered `Audit title field` in the same current-source QA app. The observed failure is an automation-selector compatibility defect; an unusable text field was **not** demonstrated. Creator save and restart persistence remain UNVERIFIED after this limited manual entry.
- **Log interpretation:** Maestro's host `KeyValueStore.commit` / `SessionStore.heartbeat` file-lock warnings occurred 17 times in the passing Planner flow and 13 in Creator. There is no evidence those warnings caused the selector failure. They are not app fatal exceptions and are not counted as a separate proven application defect.
- **Reproduction:** run the committed `qa-journeys` suite against the recorded QA APK on API 36 `emulator-5580`. It fails at the quoted selector before the remaining nine original-suite flows execute. Those nine were then executed independently: `priority8-account-isolation` and `priority8-learned-lifecycle` hit the same `Title *` failure. `priority8-learned-lifecycle-readback` then failed to find `(?s).*Task Lifecycle.*completed.*Completed the task.*helped.*` because the prerequisite lifecycle task was not created. This is a dependent fixture failure, not proof the app lost an existing completed task. Exact terminal cases/manifests are in `R/maestro-combined-result.json`.
- **Repair/verification:** update the automation to a stable selector that works with the accessible control, then rerun Creator to persisted-result completion. Preserve the improved accessibility semantics and do not remove them merely to satisfy stale test text.

### F14 — P2: Android integration taps ignore the viewport and can pass after missing an interaction

- **Location:** `integration_test/auth_flow_integration_test.dart:147`, `:148`, `:278`, `:308`, `:409`; the actual onboarding page is scrollable at `lib/features/onboarding/ui/onboarding_screen.dart:659`.
- **Expected:** the integration driver brings off-screen controls into view, confirms intended interactions and asserts the resulting selected values before treating a journey as complete.
- **Actual, failing case:** on the 320 × 640 emulator, the test attempts the first-value choice button at center `(160, 715)`, outside the viewport. It then waits for `onboarding_complete` and times out after 15 seconds. `R/auth_flow_integration_test-manifest.json` records six terminal cases, five PASS/one ERROR/zero skips, exit 1, in 110.270 seconds. Since the app page provides scrolling, this is a viewport-unaware test-harness/release-evidence defect; it does not demonstrate that a user cannot save onboarding or that the app crashed.
- **Actual, passing case coverage gap:** the Creator test's priority-4 tap at `(209.6, 688)` also misses, but that case passes without a persisted priority assertion. Its review/confirm/title/Timeline-route assertions establish a bounded UI-to-in-memory-create/routing result against `_InMemoryTaskRepository` and mocked account/guards. They do not prove the requested priority interaction, durable storage or restart readback.
- **Controlled rerun:** the same canonical auth test code at 411 × 891 / 160 dpi passed all six cases, zero failures/errors/skips, terminal success, in 60.723 seconds. Its log contains no missed-tap warnings. The fixture's onboarding-completion preference succeeds at that viewport using test preferences and fake authentication; this is a scoped PASS, not production persistence proof. This confirms viewport dependence; it does not erase the original 320 × 640 completion interaction/harness error or add an assertion for persisted priority 4. Evidence: `R/auth-tall-viewport-manifest.json`, `.jsonl` and `auth-tall-viewport-run.json`. Display and font scale were restored to 320 × 640 and 1.0 afterward.
- **Repair/verification:** scroll to required targets, fail on missed required taps, assert the requested persisted values and run both narrow and larger viewports. Preserve the original error; do not silence tap warnings or report the timeout as a generic app crash.

## 5. Feature journey coverage and interaction findings

The preceding planning repairs connect goals, tasks, daily rhythms, notes and emotional state through domain entities/use cases and shared context consumers. Those paths exist in the audited source; the account and health-state defects above are still material. A feature is not called complete merely because its screen and provider exist.

| Journey | Reviewed expected path | Evidence and remaining gap |
| --- | --- | --- |
| Onboarding and account entry | Fresh install → onboarding → account choice/sign-in → accessible home; return visits skip completed entry appropriately | Current QA install and Welcome render passed; mock-auth normal-state flows ran, including logout; F12 title wrap observed; no genuine production-authentication claim |
| Tasks and goals | Create/edit/complete → durable account storage → timeline/log/progression → refreshed planning context | Source connected; F1/F4/F5 block trustworthy account/recovery completion |
| Daily rhythm | Save recurring pattern → occurrence/context → planning/execution interpretation | Source connections reviewed; recurrence/time-zone/permission/runtime journey still needs current device evidence |
| Notes/reflections | Capture/edit/persist → intended contextual contribution without silently mutating unrelated records | Source connections reviewed; keyboard/save failure and restart readback remain to execute |
| Emotional state | User input → saved state/evidence → planning context with appropriate freshness/health → explainable recommendation | Repaired context path present; unavailable-data treatment must be tested across consumers, especially F6 |
| Smart Planner and SI Console | Gather account-owned context → propose/inspect → user action → persistence and subsequent refresh | Local deterministic paths must remain usable at zero paid credits; current runtime and error/empty-state acceptance incomplete |
| Creator | Enter creator flow → create supported entity → observe saved result in the relevant destination | Source tracing does not establish every rendered action/voice/permission path |
| Timeline and progression | Actions reflected accurately → review source evidence → stable restart/account ownership | F1 and F6 demonstrate ownership and trust defects; level-20 historical state is not current-source acceptance |
| Subscriptions and AI credits | Store/test instrument → server verification → bound entitlement/wallet → quote/consent → debit/result/refund → restore/lifecycle | Contract tests useful; F3/F8 and absent exact-build Play/device proof prevent completion |

No universal claim that every button is functional or every promised feature is complete is supported by the available runtime evidence. Disabled cloud sync must be described as a release configuration choice, not demonstrated synchronization. Mock/tester full-access modes must remain disabled in the eventual production artifact.

A passing Progression device smoke flow establishes the navigation and expected-screen assertions it executes. It does **not** disprove F6: the separate fault-injection fixture demonstrates misleading output when evidence is unavailable. Likewise, normal-state Planner, SI or Timeline smoke passes cannot establish account-race safety, genuine provider execution, credit authority or interrupted-save recovery. These are different assertions and evidence lanes.

Final Maestro case outcomes are below. The aggregate comprises the initial fail-fast invocation plus nine separate invocations, not a clean uninterrupted canonical suite. All ten invocations recorded zero app fatal markers in their captured windows; this does not certify the app is globally crash-free.

| QA flow | Terminal result | Meaning |
| --- | --- | --- |
| `04-smart-planner` | PASS | Defined Planner normal-state assertions passed |
| `05-creator` | FAIL | `Title *` selector not found; manual title entry worked |
| `06-si-console` | PASS | Defined SI Console normal-state assertions passed |
| `07-timeline` | PASS | Defined Timeline normal-state assertions passed |
| `08-progression` | PASS | Defined Progression smoke assertions passed; F6 still fails under missing-evidence injection |
| `09-settings` | PASS | Defined Settings assertions passed |
| `10-subscription-containment` | PASS | QA containment assertions passed; no real Play purchase proof |
| `11-logout` | PASS | Defined QA logout assertions passed |
| `priority8-account-isolation` | FAIL | Shared title selector blocked the account fixture; does not establish device isolation success or a new device leakage failure |
| `priority8-learned-lifecycle` | FAIL | Shared title selector prevented lifecycle fixture creation |
| `priority8-learned-lifecycle-readback` | FAIL | Expected completed task absent after prerequisite creation failed; no demonstrated deletion of an existing task |

## 6. Executed checks and commands

The authoritative static ledger is `R/static-checks.json`, which records exact command arrays, durations, exit codes and log filenames. These commands ran in the Windows working checkout against the audited source; the build attempt ran in the clean snapshot. No `dart format` write mode, dependency upgrade or source mutation was used.

| Procedure/command | Result | Evidence |
| --- | --- | --- |
| `dart format --output=none --set-exit-if-changed lib test integration_test tool scripts` | PASS; 1,161 files, zero changed | `R/format.txt` |
| `flutter analyze --no-pub --fatal-infos` | PASS, exit 0 | `R/analyze.txt` |
| `dart run tool/validate_github_workflows.dart` | PASS | `R/workflow-controls.txt` |
| `py -3 -B -m unittest discover -s scripts -p test_android_candidate_build.py` | PASS; 20 tests | `R/candidate-build-contracts.txt` |
| `node --test scripts/verify_internal_billing_backend.test.mjs` | PASS; seven tests, zero skipped | `R/billing-backend-contracts.txt` |
| `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/powershell_parse_gate.ps1` | PASS | `R/powershell-parse.txt` |
| `... -File scripts/security_secret_guard.ps1` | FAIL, exit 1; ignored local signing inputs | `R/secret-filenames.txt` |
| `... -File scripts/secret_content_guard.ps1` and `scripts/secret_guard_contract.ps1` | PASS | `R/secret-content.txt`, `secret-contract.txt` |
| `... -File check_architecture.ps1` | PASS | `R/architecture.txt` |
| `dart run tool/validate_maestro_flows.dart` | PASS; 28 files | `R/maestro-contracts.txt` |
| `... -File scripts/golden_assertion_guard.ps1` | PASS | `R/golden-assertions.txt` |
| Read back current full-suite golden completion and visually inspect four matched Windows masters | PASS within host fixtures: 41 tests in four files; eight exact logical comparisons; no regeneration | `R/golden-readback.json`, canonical suite JSONL and existing masters |
| `... -File scripts/coverage_guard_contract.ps1` | PASS; guard contract, not app coverage result | `R/coverage-contract.txt` |
| `... -File scripts/version_consistency_guard_contract.ps1` and `scripts/version_consistency_guard.ps1` | PASS; source consistency only | `R/version-contract.txt`, `version-consistency.txt` |
| `... -File scripts/release_guard.ps1` | PASS; scoped guard checks only | `R/release-guard.txt` |
| `... -File scripts/dependency_audit.ps1 -OutputDirectory test-results/release-audit-c2d83bc0/dependencies` | PASS inventory; zero reported OSV matches; license approval open | `R/dependency-audit.txt`, `dependencies/` |
| `... -File scripts/edge_function_gate.ps1 -RunTests -TestReportPath test-results/release-audit-c2d83bc0/edge-functions.junit.xml` | PASS; 131 completed, zero failed/errors/skips | `R/edge-functions.txt`, JUnit |
| `... -File scripts/edge_function_gate_contract.ps1` | FAIL under PowerShell 5.1 before assertions; benign stderr handling | `R/edge-gate-contract.txt`, `supplement-static.json` |
| `... -File scripts/supabase_migration_policy_contract.ps1` | PASS | `R/migration-policy.txt`, `supplement-static.json` |
| Clean-snapshot `scripts/security_secret_guard.ps1` | PASS; local ignored files excluded from the committed snapshot | `R/clean-snapshot-secret-guard.txt`, `supplement-static.json` |
| `dart run tool/run_flutter_tests.dart --report test-results/release-audit-c2d83bc0/flutter-suite.jsonl --manifest test-results/release-audit-c2d83bc0/flutter-suite-manifest.json --timeout-seconds 3600 -- test --no-pub --coverage --concurrency=1` | PASS; 2,632 completed/passed, zero failures/errors/skips, exit 0; 1,917.871 seconds | `R/flutter-suite*` |
| Synthetic account-switch diagnostic through Flutter wrapper, initial isolation run | FAIL; one completed failing invariant | `S/goal-race-manifest.json`, fixture and JSONL |
| Wrapper with `test-results/audit-security-c2d83bc0/goal_account_race_test.dart --no-pub --concurrency=1`, timeout 240 | FAIL; two completed failed invariants, zero errors/skips | `R/security-diagnostics-*`, `supplement-tests.json`; fixture in S |
| Wrapper with `test-results/audit-feature-c2d83bc0/feature_diagnostics_test.dart --no-pub --concurrency=1`, timeout 240 | FAIL; three completed failed invariants, zero errors/skips | `R/feature-diagnostics-*`, `supplement-tests.json`; fixture in F |
| Wrapper with `test/config/env_mode_resolution_test.dart --no-pub --concurrency=1 --dart-define-from-file=tool/qa_defines.json`, timeout 240 | PASS; 15 completed/passed, zero failures/errors/skips | `R/qa-config-*`, `supplement-tests.json` |
| `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/coverage_guard.ps1 -Mode ratchet` | PASS; required floor mode | `R/coverage-ratchet-console.txt`, `supplement-tests.json` |
| Same coverage guard with `-Mode target` | FAIL; four higher targets unmet | `R/coverage-target-console.txt`, `supplement-tests.json` |
| Guarded production AAB with external signing properties/keystore arguments | FAIL before compilation; no artifact | `R/production-build-attempt.json`, `.txt` |
| Historical AAB Java signature verification, bundletool validate/dump config/dump manifest, native ELF inspection and mapping hash comparison | PASS for historical source only | `R/historical-aab/inspection.json` and logs |
| Supabase read-only management metadata, deployed source retrieval, catalog/grant queries, advisors and latest scheduler metadata | Completed; specific PASS/FAIL findings above | `S/LIVE_BACKEND_AUDIT.md` and referenced JSON |
| No-bearer POST `action=status` with synthetic invalid capability to deployed `account-delete` | HTTP 401 before capability handling; confirmed F7; no account mutation | `S/deletion-status-gateway-runtime.json` |
| Live public privacy/support/deletion HTTP/content readback | Three pages HTTP 200, identical to local; content mismatch remains F9 | Public URLs and local source references above |
| Existing Play Console tab read | Three timeouts; no fresh Console attestation | Reported browser access limitation |
| First QA local debug APK build / API 36 emulator | Auditor canceled build and owned emulator under severe host memory pressure; first attempt produced no APK; superseded by canonical x64 build | `R/qa-apk-build.json`, `.txt`, emulator evidence |
| `flutter build apk --debug --target-platform=android-x64 --no-pub --dart-define-from-file=tool/qa_defines.json` with 1,536 MiB Gradle heap, one worker, parallelism disabled | PASS, exit 0 in 450.49 seconds; canonical QA/mock-auth profile | `R/qa-x64-build.json` and build log |
| `aapt2` 36.0.0 badging/manifest XML-tree inspection of preserved QA APK | Package/version/min/target verified; expected debug flag; backup/cleartext disabled; no billing uses-permission | `R/qa-apk/badging.txt`, `manifest-xmltree.txt` |
| `adb -s emulator-5580 shell pm path com.ghostheart5.chronospark`; `adb ... install -r <recorded QA APK>`; `adb ... shell am start -W -n com.ghostheart5.chronospark/.MainActivity` | Initially absent (expected exit 1), install exit 0, cold start exit 0; Android-reported `TotalTime: 5514` ms | `R/qa-install-start.json`; screenshot/UI hierarchy |
| First guarded Maestro invocation with an absolute `-ArtifactsRoot` | Invocation FAIL before flows: Windows path combination rejected absolute artifact-root input; operator invocation issue, not an app-journey failure; corrected relative-path retry executed | `R/maestro-invocation.json` and retained initial log |
| Canonical 11-flow `qa-journeys` with corrected relative artifact root | FAIL-fast after two terminal cases: Smart Planner PASS, Creator selector FAIL; remaining nine not executed by this original run | Maestro suite manifests/logs in R; F13 |
| Manual native-hierarchy/fresh-bounds Creator title entry | PASS for focusing/typing only; complete save journey unverified | `R/creator-selector-probe.json`, `.xml`, `.png` |
| Nine remaining independent single-flow Maestro runs | Six PASS/three FAIL; combined with original cases seven PASS/four FAIL across 11 terminal cases | `R/remaining-journeys.json`, `maestro-remaining/`, `maestro-combined-result.json` |
| Isolated QA native `font_scale=2.0` first-launch probe, then restore to 1.0 | Captured branding wrap with Continue visible; limited observation, not full accessibility acceptance | `R/qa-font-200.png`, `.xml`, `qa-font-200-probe.json` |
| Four app-root integration files / nine cases, sequential wrapper with bounded resources and default integration profile/test fakes | Original 320 × 640 run: nine terminal cases, eight PASS/one ERROR/zero skips; startup, persistence and Planner identity files pass; auth file five PASS/one ERROR | `R/android-integration-summary.json`, `android-integration-runs.json` and per-file manifests |
| Unchanged six-case auth integration rerun at 411 × 891 / 160 dpi | PASS, six of six; zero failures/errors/skips; no missed-tap warnings; 60.723 seconds; original failure retained | `R/auth-tall-viewport-manifest.json`, `.jsonl`, `auth-tall-viewport-run.json` |

Initial static aggregate: **17 of 18 checks passed; one failed**. Supplementary static checks: **two passed, one failed** (the PowerShell 5.1 Edge wrapper contract). These counts include the Edge and dependency gates and are not a readiness percentage. Error text emitted during expected negative tests must be interpreted using final test manifests, not text color or the word “error” alone.

The prior repair suite and the fresh audit canonical suite each passed 2,632 tests independently. The five new diagnostic assertions nevertheless failed because the canonical suite did not cover the demonstrated post-await account, partial-save and partial-read invariants. These are completed application-behavior failures, not skipped tests, harness exceptions or expected green tests. Test strength includes real provider/use-case paths with synthetic ownership transitions, immutable source identity, strict completion manifests and explicit negative billing/retry outcomes. Gaps include trusted cohort policy, end-to-end Play authority, platform plugins, rendered accessibility and lifecycle/persistence under actual OS termination.

Fresh coverage remains 73.7% overall and 91.5% critical, with 664 LCOV-tracked production files, 29 absent files conservatively counted at zero and 64 reviewed declaration-only exclusions. The required ratchet passes. Higher targets fail for domain use cases (82.4% versus 85%), Google Play paywall (86.6% versus 88%), backup (94.5% versus 95%) and authentication (89% versus 90%). Inventory counts of nine app-root integration flows across four files and nine host integration tests establish discovered tests, not executed app-root outcomes.

Current Windows rendered evidence is positive and bounded: 41 passing tests in four golden files include eight exact logical baseline comparisons, without changing any baseline. After verifying current pixel matches, the auditor visually inspected the existing login at width 320, Nexus at width 320, context at width 320 with 200% text, and Settings learning ledger at width 1,200. These are host fixture masters matched by the current source, not fresh phone captures or full accessibility certification. Linux baseline comparison, screen-reader operation, OS keyboard overlap and current Android rendering remain separate requirements.

## 7. Artifact record

**Current audited source, production build:** guarded command in `R/production-build-attempt.json`; source `c2d83bc0dd0c7b512e2d2b152a7ca2a230c73b30`; exit 1; **no current production AAB path or hash exists because that build produced no AAB**. Required environment validation failed before build. No production-release signing or installation claim is made for this revision; its separately recorded QA APK did build and install.

The existing ignored local keystore was available. Read-only `keytool` inspection confirmed a `PrivateKeyEntry` and the upload signer fingerprint `D88ECFC61A95B58B533E3896378A2D70894D6EF274D8C56C9F90A77C544E8D79`, matching the historical pin. Missing cloud configuration, rather than unavailable signing material, stopped the guarded attempt. No password/private-key value was printed or staged.

**Current-source QA APK:** the canonical x64 debug build completed successfully in the detached snapshot after the full host suite ended. Command: `flutter build apk --debug --target-platform=android-x64 --no-pub --dart-define-from-file=tool/qa_defines.json`; process-only Gradle limits were `-Dorg.gradle.jvmargs=-Xmx1536m -Dorg.gradle.workers.max=1 -Dorg.gradle.parallel=false`. No app source was changed to lower resource use.

| QA artifact property | Evidence |
| --- | --- |
| Original build output path | `C:\src\chronospark-audit-c2d83bc0\build\app\outputs\flutter-apk\app-debug.apk` |
| Preserved evidence copy | `test-results/release-audit-c2d83bc0/qa-apk/app-debug.apk`; identity record at `qa-apk/identity.json` |
| Source | `c2d83bc0dd0c7b512e2d2b152a7ca2a230c73b30` |
| SHA-256 | `96fa17175958c55d087aff840e5659c8207ad466092d288b03fc9339afa24913` |
| Size / result | 96,882,969 bytes; exit 0; 450.49 seconds |
| Profile boundary | Canonical QA x64 debug with mock authentication; no cloud billing acceptance; not the production AAB |
| Current APK manifest readback | Package `com.ghostheart5.chronospark`, version code `2026083021`, min SDK 24, target SDK 36; `debuggable=true` as expected for QA; backup and cleartext disabled |
| Billing boundary from manifest | No `uses-permission` for `com.android.vending.BILLING`; billing library/query components do not establish enabled purchasing. Real Google Play billing is not tested by this QA APK. |
| Installation/runtime | Fresh install/cold launch and seven QA flows PASS on API 36 ATD `emulator-5580`, 320 × 640; four flows FAIL as recorded above; F12 title defect observed; manual Creator title entry works; separate integration results below |

The successful retry supersedes the first explicitly canceled local-backend diagnostic attempt. The auditor released its own idle Gradle daemon before restarting the emulator with 1,536 MiB RAM. Any later installation or journey evidence must name this APK/profile and cannot be used to certify production signing, genuine authentication, subscription payment or backend-cohort behavior.

The fresh-install probe found no existing package, installed successfully and reported a cold activity start with `TotalTime: 5514` ms / `WaitTime: 5516` ms. Observed process PSS was 418,250 KiB; the captured app log contained no fatal markers. `gfxinfo` returned zero frames, so it supplies no valid frame-latency measurement. These debug-build observations on a software-rendered, resource-constrained audit emulator are not a production startup percentile, a crash-free guarantee or a service-level acceptance result. No release-performance threshold is inferred from them.

The later Android app-root integration runner built its own test APKs using the default integration configuration with test fakes, without `--dart-define-from-file=tool/qa_defines.json`. Those runs use the same source commit and emulator but have separate per-file evidence and are not executions of the preserved QA APK. All four original files reached terminal completion, with no runner timeout: nine cases total, eight PASS/one ERROR/zero skips. F14 explains the off-screen auth test tap and limited scope of passing assertions. The unchanged six-case auth file then passed at a larger viewport; that is a controlled rerun, not six new distinct integration cases or an uninterrupted original-suite pass.

| Integration file / viewport | Terminal outcome | Duration and scope |
| --- | --- | --- |
| `app_startup_test`, 320 × 640 | One PASS; zero failures/errors/skips | 265.355 seconds, including 237.2 seconds building Android and approximately 4.3 seconds installing its test APK |
| `auth_flow_integration_test`, 320 × 640 | Five PASS/one ERROR; zero skipped | 110.270 seconds; onboarding driver misses off-screen choice, then times out; passing Creator uses in-memory repository and lacks priority assertion |
| `persistence_recovery_test`, 320 × 640 | One PASS; zero failures/errors/skips | 57.794 seconds; fixture-defined native storage persistence/recovery assertions |
| `planner_learning_identity_test`, 320 × 640 | One PASS; zero failures/errors/skips | 43.838 seconds; identity survives storage close/reopen inside the fixture; no cold-process-kill claim |
| Same `auth_flow_integration_test`, 411 × 891 / 160 dpi | Six PASS; zero failures/errors/skips | 60.723 seconds; no missed-tap warning; unchanged test code; small-screen error retained |

The test device's display was restored to 320 × 640 and font scale 1.0. The build snapshot, preserved QA APK and evidence were retained. Source preservation readback confirms the same commit and no app-source or lockfile changes from audit execution.

**Historical AAB freshly reinspected, not the candidate:**

| Property | Evidence |
| --- | --- |
| Path | `artifacts/releases/4.1.0-2026083021-internal-billing-verified/app-release.aab` |
| Recorded source | `c5564ef2c920047a3aa1a335b46eb58b4d8d17b6` |
| SHA-256 | `3dfd59e1560b22e5db70cc505dcf519efcf589e68cf962e273e3646ac7ccbbf4` |
| Size | 77,926,855 bytes |
| App/version | `com.ghostheart5.chronospark`, `4.1.0`, code `2026083021` |
| Signer SHA-256 | `D88ECFC61A95B58B533E3896378A2D70894D6EF274D8C56C9F90A77C544E8D79` |
| Signature/bundle validation | All 587 payload entries verified; bundletool validation passed |
| Android runtime properties | min SDK 24, target SDK 36, not debuggable, not test-only; backup and cleartext disabled |
| Billing/configuration | Billing 8.0.0; cloud metadata; analytics, messaging auto-init and Crashlytics collection disabled in manifest |
| Native alignment | Bundle requests 16 KiB ZIP alignment; inspected 64-bit LOAD segment alignment at least 16 KiB |
| Mapping | Bundled mapping matches preserved sidecar SHA-256 `4b96804a89cdd4bfc65a14cf8fefcf881f892e9d8a1731040625a75549393492` |
| Filename screening | No suspicious secret filenames or debug-payload filename indicators found |

Filename screening does not prove arbitrary compiled binaries contain no secrets. Manifest metadata alone cannot attest every compiled Dart feature/cohort flag. Recorded historical CI/build provenance is included in the inspection JSON; it is not a fresh run of the audited commit. Presence of `.sym` entries contradicts an older blanket “not generated” note, but symbol completeness has not been certified. Alignment inspection is not execution on a 16 KiB device. The artifact was not installed or launched in this audit lane.

## 8. Store and operational requirements

Current official requirements were checked for the intended Android/Play channel rather than inferred from old repository notes:

- The current target-API requirement calls for API 36 for new apps/updates from August 31, 2026. Source and the historical artifact meet that numeric floor; the new artifact remains unverified. [Google Play target API requirements](https://support.google.com/googleplay/android-developer/answer/11926878?hl=en)
- Billing Library 8 is supported for submissions until August 31, 2027 according to the current deprecation schedule. Historical Billing 8 does not prove a newly resolved artifact's library version. [Billing deprecation FAQ](https://developer.android.com/google/play/billing/deprecation-faq)
- The current Android 16 KiB guide states a February 1, 2027 Play requirement. This audit uses the current guide rather than the older November 2025 date in older announcements. Actual bundle/native verification and representative runtime remain separate. [Support 16 KB page sizes](https://developer.android.com/guide/practices/page-sizes)
- Every new uploaded update needs a new version code; inspect the built manifest and authoritative Console state. [Android app versioning](https://developer.android.com/studio/publish/versioning)
- Internal distribution does not prove reviewer access, billing license tester status, product availability, or configuration correctness. The Console must be read directly. [Set up an internal test](https://support.google.com/googleplay/android-developer/answer/9845334)
- Data safety, account deletion and access instructions must accurately describe the applicable app/track and enabled features. Whether a particular declaration is currently required or accepted for this Console state remains UNVERIFIED. [Data safety guidance](https://support.google.com/googleplay/android-developer/answer/10787469), [reviewer access guidance](https://support.google.com/googleplay/android-developer/answer/15748846), [account deletion requirements](https://support.google.com/googleplay/android-developer/answer/13327111)
- Final screenshots and preview assets must satisfy the requested device/asset requirements and represent real app behavior. A historical level-20 image cannot establish current-candidate function. [Preview asset requirements](https://support.google.com/googleplay/android-developer/answer/9866151)

Older `docs/internal_billing_testing.md` still describes $4.99/month and $39.99/year. Later credit-policy evidence records $7.99/month, $69.99/year, and 100/300-credit packs at $2.99/$7.99. These are historical/documented policy states, not a fresh Console catalog readback. No prices or products were changed during this audit. Reconcile stale instructions and confirm the authoritative current catalog before the next billing candidate.

Live backend metadata supports four active maintenance jobs with successful latest records: subscription expiry every 15 minutes, stale reservation refund every five minutes, expired AI response purge every five minutes and response-content scrub each minute. One old expiry job is inactive. This establishes observed scheduler execution, not a newly performed full refund/expiry/deletion fixture. No fresh GitHub deletion-reconciliation job was verified.

All 56 inspected public tables have RLS enabled. Fifteen policyless-table advisor notices were reconciled with absent inspected client grants, so those notices were not treated as automatic leaks. Eight authenticated SECURITY DEFINER warnings were assessed against definitions/privileges; seven inspected endpoints were expected account-scoped APIs with empty search paths, and the obsolete wallet endpoint is F8. This catalog review is not a substitute for account-level negative testing.

Nonblocking operational observations: one missing covering foreign-key index on `credit_topup_purchases.billing_principal_id`; 65 indexes reported unused; Auth uses a fixed maximum of ten database connections. These are workload/maintenance considerations, not grounds for unmeasured index deletion or production changes. [Supabase database linter](https://supabase.com/docs/guides/database/database-linter), [production readiness guidance](https://supabase.com/docs/guides/deployment/going-into-prod)

## 9. Required follow-up before a release decision can change

Release blockers, ordered by user impact:

1. Repair goal account isolation and malformed-data preservation (F1, F4); verify with deterministic regressions and account-switch/restart journeys.
2. Enforce trusted AI cohort authorization (F3) before any new provider testing.
3. Correct deletion-status gateway compatibility and partial-save/retry behavior (F7, F5), followed by unavailable-evidence review (F6).
4. Unify credit authority, reconcile enabled-feature disclosures, externalize local signing inputs, repair the failing local wrapper/Creator/integration automation and correct narrow-screen onboarding composition (F8, F9, F10, F11, F12, F13, F14).
5. Prepare a new unused version, complete the reviewed production inputs and produce/inspect the exact signed candidate (F2).
6. Complete all release-critical runtime, Console and operational evidence that remains UNVERIFIED. A source repair and green host suite alone do not satisfy these requirements.

Remaining verification must be concrete: repair and rerun the five failing audit invariants; repair viewport/selector automation and rerun the canonical Maestro and app-root suites, including the original narrow viewport and priority assertions; execute required Linux platform goldens; complete rendered accessibility checks; install and upgrade the exact Play-signed production candidate on the Moto while preserving data; exercise a second representative supported Android environment; use licensed test payment methods for pending/success/decline/restore/lifecycle/top-up/spend/refund cases; verify account/session/permission/offline/termination recovery with safe profiles; capture release startup/frame/memory/crash measurements; read live Console catalog/cohort/tester/reviewer/declarations/assets; confirm crash/alert/support ownership and containment procedures. Use disposable accounts for destructive deletion and ownership tests. Do not claim production data or wallet outcomes from mocked contracts.

Residual risks for review include higher coverage target debt, unapproved dependency licenses, lack of a complete schema-equivalence proof despite migration-ID parity, unverified symbol completeness, absent current 16 KiB runtime proof, host memory constraints and limited current crash/incident monitoring evidence. None has been silently converted into a PASS.

**Final recommendation: NO-GO for this specific internal-testing candidate.** The preceding repairs are committed locally; the audit identifies further repair work and critical evidence gaps. No push, additional commit, upload, publication or production mutation is implied by this report.
