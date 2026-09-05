# ChronoSpark App-Only Readiness Contract

This file separates the immutable professor-report baseline from provisional
Gate 1 working-tree evidence. It is not an exact-commit release approval and
does not authorize a release, deployment, store action, external service, or
public product claim.

## Current closeout notice - 2026-09-04

Execution status: [nine-phase closeout repair plan](docs/engineering/CLOSEOUT_REPAIR_PHASES_20260904.md).
Phase 1's source/disposable-backend gate passed on `1f07020e` in
[database run 33944999190](https://github.com/ghostheart5/fantastic-guacamole/actions/runs/33944999190):
83 Edge tests and 326 SQL assertions passed. Schema lint passed its error gate
with four recorded existing billing-function warnings. These changes are not
deployed or included in the older signed candidate described below.

The baseline, Gate 1, and older priority evidence below are historical snapshots,
not the current candidate's missing-work list. The current evidence is recorded
in the [Phase 5/6 checkpoint](docs/engineering/SAFE_QUICK_PHASE_5_6_STATUS_20260904.md)
and [Phase 7 backend checkpoint](docs/engineering/SAFE_QUICK_PHASE_7_STATUS_20260904.md).

- Frozen app source `61c7331dda9e82201a0561dbcd79aa0b37118446` has passing
  exact-source CI `33939436515`: 2,352 Flutter tests and 15 configuration tests,
  static checks, goldens, integration, and the 71.7% coverage gate.
- Signed build `33940078212` passed. Its verified AAB and physical-phone smoke
  plus one save/restart/complete/restart task journey supersede earlier
  build-blocked and no-device-smoke statements. They do not complete the full
  physical UAT, accessibility, performance, or human-review gates.
- Live backend configuration/source readback and the guarded duplicate-cron
  pause are recorded in Phase 7. Firebase alert preferences persisted; actual
  delivery and other remaining service/runtime gates are not proved by that.
- The current source declares English and Spanish (`en`, `es`). Spanish
  usability, legal translation, and distress-language comprehension still need
  qualified human review. The approved bundled age policy is adults **18+**;
  current Play declarations still require owner verification against that policy.

The newer nine-phase closeout plan is separate from binder priorities and the
older 13-phase safe-quick plan. Domain work is excluded from that closeout work
at the user's request, not marked complete. Reuse the recorded passes for their
exact source/artifact/scenarios; do not rerun them because a historical checkbox
below remains open. Any changed release source needs its own final verification.

## Contract identity

| Field | Value |
| --- | --- |
| Evaluated repository | `ghostheart5/fantastic-guacamole` |
| Baseline source commit | `6118ba6df289ca89472ba804307a85be00a0c0f2` |
| Baseline source tree | `73056dc5f03c998714e77c0119bce006bed6e7e8` |
| Baseline commit time | `2026-09-02T11:31:27-05:00` |
| Baseline commit subject | `Merge pull request #89 from ghostheart5/fix/app-links-release-gate-20260902` |
| Tag at baseline commit | None |
| Professor-report source | `f70ab0e1b20117d8a87f77d5c88ff592a7083c30` |
| Professor result | `77/100 (C+)`; conditional supervised-pilot path; whole-person claim `NO-GO` |
| Gate 1 candidate branch | `fix/app-only-readiness-gate1-20260902` |
| Gate 1 source commit | `45a930d86916336fc4c8d2a0143dd1aba78d0361` |
| Gate 1 merge commit | `bc414f2dd851bba18570ec12e27d830b62fd10fb` (PR #90) |
| Gate 1 evidence state | Exact-source CI run `33680196098` passed; PR #90 required checks passed and the branch was merged into `origin/main`. |
| Priority 2/3 working-tree base | `bc414f2dd851bba18570ec12e27d830b62fd10fb`; local uncommitted host evidence only |

## Deferred follow-up note

Current safe-quick repair sequence: see
[Phase 5 and Phase 6 checkpoint](docs/engineering/SAFE_QUICK_PHASE_5_6_STATUS_20260904.md).
As of 2026-09-04, **Phase 5 is INCOMPLETE / DEFERRED** at the user's request;
the domain and DNS are configured, but HTTPS and the remaining public-service
exit checks are not complete. **Phase 6 signed candidate and focused physical
smoke are PASS; the full device and release gates remain incomplete.** These phase
numbers refer to the safe-quick repair plan, not the older binder priorities
or the launch-readiness checkpoint numbers.

These follow-up items are intentionally divided by who can complete them.
Remote-safe work is limited to repository source, documentation, and local or
CI verification. Human/live work requires physical access, production or
provider access, qualified review, human participation, or a product/legal
decision.

### Remote-safe source and test repairs

Checked items below were implemented and focused-verified in the local dirty
working tree based on `1f1b93838221e5a00a9315ce085f37f254af2920`. They are
not exact-commit CI, deployment, store, or production-service evidence.

- [x] Repair **Clear this device** so it requires the current authenticated
  account ID, distinguishes legacy-owner deletion, closes the storage gate,
  drains mutations, clears only the intended account, invalidates every
  account-owned provider, and reopens only the unchanged account generation.
- [x] Cancel the departing account's scheduled local notifications before
  sign-out completes, without deleting the account's intentionally preserved
  repository data.
- [x] Replace recursively growing recurring-task successor IDs with bounded,
  deterministic IDs; migrate existing nested IDs and prove long recurrence
  chains survive backup, sync, and restore validation.
- [x] Move goal, habit, daily-planning, reflection, and tracked reminder
  preferences to account-scoped storage with legacy-owner-only migration.
- [x] Register and delete account-scoped SI Console corruption backups during
  local clearing and account deletion.
- [x] Preserve or quarantine each malformed offline-queue member instead of
  silently dropping it when the remaining queue is rewritten.
- [x] Make Daily Rhythm occurrence and learning-outcome persistence recoverable
  through an outbox, pending-side-effect marker, or idempotent reconciliation.
- [x] Retain a privacy-safe pending account-deletion receipt and expose the
  existing capability-based status and recovery path in the app.
- [x] Restore green source gates: repair the two architecture violations and
  actionlint findings, correct the Supabase contract runner's false nonzero
  result, and update only the stale billing-copy and installation-scoped bridge
  tests to match their real contracts.
- [x] Investigate the small Login golden drift. The compact and regular layouts
  retain the same structure; the remaining 0.57% and 0.47% pixel differences
  are isolated to localized placeholder/divider rendering and remain queued for
  the explicit human visual decision below. No reviewed baseline was replaced.
- [x] Convert tap-only Smart Planner, SI Console, Settings, and Creator controls
  to keyboard-operable controls and add focused Enter, Space, focus-order, and
  disabled-state tests.
- [x] Route routine Smart Planner and SI Console responses, shortcuts, guides,
  fallbacks, and voice summaries through locale-aware typed copy. Keep final
  Spanish-language approval in the human list.
- [x] Establish one canonical structured source for privacy, terms, support,
  and deletion pages; generate and parity-test derivatives, remove contradictory
  source ownership, and make complete bundled legal text readable offline
  without changing unapproved policy meaning.
- [x] Make telemetry consent versioned, timestamped, in-memory gated, and
  rollback-safe before any collection capability can be enabled.
- [x] Separate network-interface availability from verified service reachability;
  debounce retry behavior and remove or complete the internally inconsistent
  app-recovery path.
- [x] Add privacy-safe typed diagnostic codes and truthful incident-response
  runbooks, correct unsupported public AI/platform claims, and replace broad
  asset-directory inclusion with the explicit assets actually used.
- [x] For every repair, run the smallest focused test first and do not
  repeatedly rerun the full suite.
- [ ] After the human Login-golden decision and a commit, run one complete CI
  pass and preserve exact-SHA evidence.

Earlier remote-safe validation recorded on 2026-09-04 (superseded for current
CI/build status by the current closeout notice above):

- One complete local source run executed 2,339 tests: 2,328 passed, nine
  remote-safe failures were repaired and then passed as focused reruns, zero
  tests were skipped, and the two Login golden comparisons remain the human
  visual hold described below. The complete suite was not rerun.
- The focused policy coverage repair raised domain-policy coverage from 98.6%
  to 99.1%; the ratchet passes at 71.7% overall. The original full-run LCOV was
  preserved before merging the single focused coverage result.
- All eight emulator integration tests passed with zero skips. Flutter static
  analysis, the 730-file architecture check, dependency audit, release guard,
  version consistency, workflow checks, Maestro contracts, Supabase migration
  replay, Edge Function checks, legal parity, and secret guards passed.
- Exact-commit CI remains open because this evidence belongs to an uncommitted,
  pre-existing dirty working tree and the two reviewed Login golden decisions
  are still human-owned.

### Human, physical-device, and live-service to-do

Carried-forward side notes: the unfinished Priority 6 exit gate, deferred
Priority 9, remaining Google Play app section, and website/domain work are
included below as later human or live-service work. None is complete.

- [ ] Reconcile the final release SHA with the live Supabase environment:
  deployed migrations and Functions, RLS and grants, Auth security and redirect
  settings, Storage restrictions, deletion and reconciliation queues,
  retention, backups, and a timed restore drill. Capture privacy-safe readback
  without exposing production data.
- [ ] Replace the temporary Priority 8 emulator substitution with exact-build
  physical Android evidence covering TalkBack, 200% text, keyboard order,
  native permissions and denial recovery, offline and captive-portal behavior,
  process death and restart, crisis call/text actions, final screenshots, and
  the accepted performance budget.
- [ ] **Side note - Priority 6:** Finish the exit gate with five moderated
  real-participant usability sessions and record the required comprehension,
  optional-context, timing, and zero-rescue results.
- [ ] **Side note - Priority 9:** Complete the deferred human and
  qualified-review gate, including Spanish translation and distress-language
  comprehension,
  accessibility-technology behavior, deletion and support journeys, visual
  polish, mental-health-safety review, and claim-to-observed-behavior approval.
- [ ] Review the Login compact and regular golden differences and explicitly
  approve corrected visuals or replacement baselines before they are committed.
- [ ] Validate live Firebase controls with authorized credentials: App Check
  and API restrictions, consent actually controlling Analytics and Crashlytics,
  event ingestion and grouping, Cloud Messaging and remote configuration, and
  alert delivery in a release-like build.
- [ ] **Side note - Google Play app section:** Complete the remaining Google
  Play Console and test-account evidence: target-age declarations, Data Safety,
  public policy and deletion
  URLs, signed-build provenance, purchase and restore behavior,
  acknowledgement, refunds, RTDN, and entitlement authority. Independently
  verify that every required field is saved and accepted before any separately
  authorized publication or rollout.
- [ ] Resolve the product and legal decisions that cannot be authored safely by
  engineering alone: target-age policy, assent and acceptance records, legal
  entity and jurisdiction, liability language, translated legal text, deletion
  timelines, and current crisis-resource claims. Obtain dated qualified
  privacy, legal, and safety review.
- [ ] **Side note - Website/domain / repair Phase 5: INCOMPLETE, DEFERRED.**
  `chronospark.app` is registered and its four GitHub Pages A records plus
  `www` CNAME were saved and read back on 2026-09-04. GitHub accepted the custom
  domain and confirmed valid DNS for both names. Last HTTPS check failed:
  certificate not yet issued; HTTPS enforcement is off. Still required:
  certificate issuance, HTTPS enforcement and secure-route verification,
  canonical legal-content parity, download information, exact-build App Links,
  and a real support-message delivery/readback. HTTP 200 responses do not close
  this gate. See the linked checkpoint for exact resume actions.
- [ ] Before external AI is ever enabled, verify the provider contract and DPA,
  retention or zero-data-retention settings, production secret handling, live
  transport, cost/refund containment, content scrubbing, and reconciliation.

Checked remote-safe items do not mark any human or live-service item complete
and do not authorize a domain purchase, DNS change, deployment, production-data
access or mutation, credential use, Firebase or Supabase change, signed build,
external-AI enablement, Play Console submission, publication, rollout, or
release.

Baseline conclusions apply only to `6118ba6`. Before commit, rows explicitly
labeled `Gate 1` apply to the reviewed working tree; after commit, they apply to
the commit carrying this file only when the committed diff matches that review.
Results from a parent commit, pull-request head, merge candidate, local dirty
tree, emulator, physical device, deployed service, or human session are
different evidence classes and must not be substituted for one another.

## Professor baseline verdict

| Claim | Result | Required promotion gate |
| --- | --- | --- |
| Developer/internal app-only use | `PASS` | Continue to label limitations and keep external capabilities contained. |
| Supervised app-only pilot | `BLOCKED` | Priorities 1-3 plus a minimum exact-build physical-device smoke proof. |
| Public advanced-planner claim | `BLOCKED` | Priorities 1-8, including device, accessibility, and performance evidence. |
| Public whole-person or equivalent understanding claim | `NO-GO` | All nine priorities, human UAT, safety review, and claim-to-evidence approval. |

## Shipped, blocked, excluded, and required evidence

| Area | Baseline or Gate 1 state | What is shipped | What remains blocked | Evidence required to promote |
| --- | --- | --- | --- | --- |
| Canonical product loop | `SHIPPED / HOST-PROVEN` | Creator, Timeline, Nexus, Smart Planner, decision outcomes, and bounded learning form a reachable local loop. | Human usefulness and exact-build device execution are not established. | Focused host tests, exact-build device recording, restart result, and human scenario evidence. |
| Governed Person Context storage | `SHIPPED / HOST-PROVEN` | One exhaustive behavior policy now governs kind, surface, purpose, relevance, freshness, permitted field, prohibited inference, override, conflict order, and privacy-safe deltas. Withdrawal, expiry, account transition, deletion, and response invalidation fail closed. | The current proof is an uncommitted Windows host working tree; exact-commit CI and physical-device evidence are not established. | Commit-bound review and CI plus exact-build device/runtime evidence. |
| Nexus ranking and Planner grounding | `SHIPPED / HOST-PROVEN` | The canonical Decision Engine consumes one governed context: explicit boundaries exclude, commitments outrank capacity, capacity caps execution, and current priority adds only a 0.25-point tie-break. Planner accepts positive text or typed-domain relevance, and Nexus explains and can ignore the context for the session. | Human usefulness, exact-build device behavior, and committed CI evidence are not established. | Commit-bound scenario fixtures and CI, exact-build device recording, and human usefulness review. |
| SI Console, Trajectory, and Creator context effects | `SHIPPED / HOST-PROVEN` | One governed policy now reaches all three surfaces. SI cites only query-relevant context in a dedicated user-reported evidence type and fences Nexus-only receipts; Trajectory applies surface-owned boundary, capacity, and commitment constraints while preserving a separately computed no-context comparison; Creator binds warnings and the shared trace to an unchanged proposal that requires explicit confirmation. One repository action path corrects or withdraws the shared signal across all three projections, and tracked Trajectory forecasts mark dependent assumptions corrected when the context revision changes. | The proof is an uncommitted Windows host working tree. Exact-commit CI, physical-device behavior, and human usefulness remain unverified. | Commit-bound review and CI, exact-build device recording, and Priority 9 human usefulness review. |
| Learning and adaptation | `SHIPPED / HOST-PROVEN` | Account-scoped structured outcomes feed a bounded 256-row ledger grouped by surface and situation with a 30-day half-life. Low-confidence patterns cannot affect guidance; after three sufficiently recent outcomes, the same reviewable Smart Planner pattern may select a preferred bounded option. Pause, correction, undo, export, delete-all, retention reconciliation, and serialized writes are reachable. | This remains an uncommitted Windows-host result. Exact-commit CI, physical-device restart behavior, localization, and human usefulness are not established. Preference learning is not identity or whole-person inference. | Commit-bound focused CI, exact-build device restart/correction/delete evidence, localization review, privacy/semantics review, and Priority 9 human usefulness evidence. |
| First-use context | `SOURCE + WINDOWS HOST-PROVEN / HUMAN GATE OPEN` | The two-page onboarding remains unchanged. After the first useful non-clarification Planner result, an account-scoped one-shot offer keeps use-once as the default and asks only for an exact current priority. Before consent it states decision-support purpose, Smart Planner-only scope, 30-day expiry, and tie-break-only effect. Decline writes no context; save requires exact text plus consent. Nexus exposes a visible `CONTEXT` entry and Settings opens review, correction, expiry, export, and deletion controls. | The timed moderated path has not been run. Linux masters for the new Home captures and refreshed Nexus layout, exact-commit CI, device behavior, and translation review are not established. | Five representative participant records proving first value, comprehension, save/decline, rediscovery, and deletion in under two minutes with zero rescue; reviewed Linux captures and exact-commit CI; exact-build device and translation evidence. |
| Local persistence and recovery | `SHIPPED / HOST-PROVEN` | Local repositories have account-session boundary guards and host restart/corruption coverage. Decision outcomes, learning state, and the learning-pause control are account-namespaced and fail closed while signed out or transitioning. | Exact release-build device recovery, populated-state performance, and data-loss UAT are not established. | Commit-bound account-boundary CI, Priority 8 physical-device restart/corruption evidence, and Priority 9 human recovery results. |
| Golden visual regression | `PLATFORM-PINNED / LIVE EXACT-COMMIT CHECK REQUIRED` | Gate 1 defines five logical, exact image comparisons: Login at 320/500 and Nexus at 320/375/500, backed by reviewed Windows and Linux masters. The harness loads Inter and Material Icons, disables supported animations, and selects only the active supported renderer instead of tolerating pixel drift. | Baseline source `6118ba6` contains zero image comparisons. Initial exact-commit run `33677111731` failed only the five Windows-versus-Linux pixel comparisons; a corrective commit remains blocked unless its own attached CI check passes. | Resolve the commit carrying this file, require its attached CI run to pass, and record the five-comparison/ten-master guard plus normal comparison result. |
| Maintainability and weak-layer coverage | `LOCAL HOST PASS / EXACT-COMMIT CI PENDING` | The four binder-named files are split below a 1,600-line executable limit. All 42 retained planned sources have owned reachability decisions and removal/promotion criteria; 24 compiled-provider-only files are not mislabeled as shipped. Stale classification comments and the package-prefix reachability utility are corrected. The final 2,099-test host suite, analyzer, architecture check, and target-mode coverage guard pass. Coverage is 85.7% use-cases, 82.7% storage, and 70.5% controllers/providers. | Exact-commit CI and device/runtime evidence are not established. Three touched files outside the binder-named split set remain recorded follow-up decomposition candidates. | Commit this candidate, require attached CI at that exact SHA, and preserve the follow-up decomposition list without reopening the Priority 7 binder scope. |
| Device, accessibility, and performance | `BLOCKED` | Host widget and integration checks exist. | No exact current release-tree physical-device run, TalkBack proof, complete viewport matrix, or accepted performance budget is attached. | Priority 8 SHA-bound build manifest, device/OS, recordings, accessibility checklist, traces, and executed-flow log. |
| Human UAT, safety, and claim | `BLOCKED` | Conservative product and distress boundaries exist in source. | Representative users, qualified safety review, and claim-to-observed-behavior evidence are absent. | Priority 9 anonymized UAT, defect log, safety sign-off, claim matrix, and final SHA-bound go/no-go review. |

## Explicitly excluded from this app-only contract

These categories receive no pass or fail here. They are **not verified**:

- Supabase and every deployed database, RLS, Storage, Edge Function, secret,
  backup, retention, or cloud-sync behavior;
- Firebase, Analytics, Crashlytics, Cloud Messaging, and remote configuration;
- Google identity, Google Play, billing, subscriptions, purchases, RTDN,
  signing, store listing, submission, rollout, or publication;
- external-AI transport, provider retention, remote prompts, and paid credits;
- website hosting, DNS, App Links public readback, and other public services.

## Evidence ledger

| Evidence | Result | Boundary |
| --- | --- | --- |
| Professor report CI run `33624661744` | `PASS` for its recorded host suite | Adjacent merge-candidate commit `78dd3778910bc4c01a16770cb3fb1a5f98f383e3`; not the evaluated current commit and not device evidence. |
| PR #89 CI/CD run `33653034494` | `PASS` | Pull-request head `45226d6d582e654c58facec648f05ecdef58b9f5`; adjacent to merge commit `6118ba6`, not an exact merge-commit run. The source still performed zero golden comparisons. |
| Gate 1 baseline golden comparison | `FAIL` | Local working tree: all five stale PNGs differed by `99.99%-100%`; one Nexus fixture also exposed missing mocked SharedPreferences. This is useful defect evidence, not a pass. |
| Gate 1 reviewed Windows golden comparison | `LOCAL PASS` | Two consecutive Windows runs of `flutter test --no-pub test/features/auth/login_screen_golden_test.dart test/features/nexus/nexus_screen_golden_test.dart` each passed 15 tests in normal comparison mode, including all five visually reviewed Windows images under the default exact comparator. This is host evidence, not CI or device evidence. |
| Gate 1 initial exact-commit CI | `FAIL` | CI run `33677111731` checked exact SHA `2ac97b0866e09adfdd162b78a00ee87d99c6e725`: 1,969 passed, five golden comparisons failed by 2.06%-4.11% from cross-platform rasterization, and one test was skipped. The golden assertion guard and all preceding gates passed. |
| Gate 1 Linux golden regeneration | `CANDIDATES REVIEWED` | Manually dispatched, evidence-only run `33678930761` at exact SHA `2ac97b0866e09adfdd162b78a00ee87d99c6e725` produced five Ubuntu candidates. All five were visually reviewed; regeneration is not a passing comparison. |
| Gate 1 golden assertion guard | `LOCAL PASS / CI CONFIGURED` | The guard requires five logical matcher declarations and ten platform masters across both golden test files; both CI and the update-goldens workflow invoke it before testing or regeneration. |
| Priority 5 bounded learning proof | `LOCAL PASS` | 90 focused Windows-host tests passed serially, covering typed outcomes, account scoping, decay/threshold behavior, exact Planner consumption, pause/resume, concurrent writes, correction targeting, retention, eviction cleanup, delete-all, account transition, task ingress, 320x568 at 200% text, and readable ledger visual regression. Targeted analysis reported no issues, `git diff --check` was clean, and the skilled corrective review returned GO. This is uncommitted host evidence, not CI, device, deployed-service, or human-usefulness proof. |
| Priority 6 first-use context proof | `LOCAL PASS / HUMAN EXIT GATE OPEN` | 65 focused Windows-host tests passed serially, covering unchanged first-value accessibility, account-scoped one-shot behavior, signed-out failure, consent-before-save, policy eligibility, decline-without-write, context invalidation, visible Nexus discovery, one-shot Settings opening, governance controls, exact Windows Nexus comparisons, semantics, and true 320x568/375x667 viewport captures at 200% text with scroll reachability. Targeted analysis and `git diff --check` passed. A bounded API 36 human-robot proxy reached useful guidance and the visible five-fact offer, then stopped after a repeated automation-selector boundary: 1/5 attempted, 0/5 completed, no app defect proven. Robot evidence is not human UAT; five moderated participant sessions remain required. |
| Priority 7 maintainability proof | `LOCAL PASS` | Final Windows-host evidence: 2,099 tests passed with one intentional skip and zero failures; analyzer and architecture checks passed; target-mode coverage passed at 73.4% overall, 92.4% critical-only, 85.7% use-cases, 82.7% storage, 70.5% controllers/providers, and 76.6% SI engine. See `docs/engineering/PRIORITY_7_FILE_RESPONSIBILITY_MAP.md`, `docs/engineering/PRIORITY_7_PLANNED_REACHABILITY.md`, `docs/engineering/PRIORITY_7_STATIC_LOG.md`, and `docs/testing/PRIORITY_7_COVERAGE_SUMMARY.md`. This is candidate-tree host evidence, not exact-commit CI or device evidence. |
| Priority 8 emulator substitute proof | `LOCAL QA EMULATOR PASS` | The exact repaired profile APK built and installed on Android 16/API 36. Startup/memory, viewport, 200% text, keyboard, reduced-motion, TalkBack interaction, offline/reconnect, lifecycle, learned-change restart/readback, and Account A -> B -> A preservation/isolation passed with zero app-fatal markers in the recorded gates. The verified APK SHA-256 is `9770E55645D698A0E09DF1A6E44FEF3C3824C0FFD2B2CCBC401CF666D43A09CC`. This is the user-approved emulator substitute, not physical-device, production-cloud, signed-release, or human-UAT proof. See `artifacts/priority8/20260903-0545-ae6823bd-emulator-matrix/results.md`. |
| Gate 1 corrective exact-commit CI | `PASS / MERGED` | CI run `33680196098` passed at exact SHA `45a930d86916336fc4c8d2a0143dd1aba78d0361`; PR #90 required checks passed and merge commit `bc414f2dd851bba18570ec12e27d830b62fd10fb` is the Priority 2/3 base. |
| Priority 2/3 focused working-tree verification | `LOCAL PASS` | A focused 11-file policy, account-boundary, Planner, Nexus, SI Console, Creator, Trajectory, and Decision Engine slice passed 124 tests on the uncommitted tree based on `bc414f2d`; the exact Nexus explain/ignore interaction also passed independently (1/1), all 27 changed Dart files passed targeted analysis, and `git diff --check` passed. This is not exact-commit CI or device evidence. |
| Priority 4 focused working-tree verification | `LOCAL PASS / SKILLED REVIEW GO` | A focused 13-file SI, Trajectory, Creator, shared-policy, operating-decision, propagation, UI-integration, and forecast-ledger slice passed 117 tests on the uncommitted tree based on `bc414f2d`; targeted analysis passed with no issues and `git diff --check` passed. A read-only skilled reviewer returned GO after the final whole-word SI relevance regression. This is not exact-commit CI, device, deployed-service, or human evidence. |
| Current physical-device evidence | `NOT_RUN` | Host tests and PNG comparisons do not establish device behavior. |
| Current human UAT | `NOT_RUN` | Automated or agent-driven checks do not count as human UAT. |

## Mandatory release-report evidence format

Every new readiness or release report must contain separate sections for:

1. **Source/static evidence**: exact SHA/tree, diff scope, classifications, and
   configuration inspection.
2. **Host evidence**: formatting, analyzer, unit/widget tests, golden
   comparisons, and host integration tests with command and count.
3. **Device/runtime evidence**: exact artifact hash, device model/OS, executed
   flows, accessibility, restart, offline, and performance results.
4. **Human evidence**: participants, protocol, facilitator-rescue rate,
   findings, safety review, and claim decision.
5. **Excluded external evidence**: each external system marked `NOT GRADED`,
   `NOT_RUN`, or independently verified under a separately authorized gate.

`PASS` in one section must never be copied into another section.

## Priority 1 exit checklist

- [x] One app-only matrix identifies shipped, blocked, excluded, and required evidence at exact source `6118ba6`.
- [x] Current learning classifications/comments describe the reachable runtime path instead of calling it wholly planned.
- [x] All five Windows masters pass two consecutive exact normal comparison runs, and all five Linux candidates are accepted after visual review.
- [x] CI is configured to require a non-zero golden assertion count and fail if either golden file loses its matcher declaration.
- [x] Authorized exact-commit CI run `33680196098` passed at `45a930d86916336fc4c8d2a0143dd1aba78d0361`; PR #90 then merged as `bc414f2dd851bba18570ec12e27d830b62fd10fb`.

Priority 1's source and review gate is complete. Device and human evidence
remain separate later-priority gates.

## Priority 2 exit checklist

- [x] One exhaustive policy matrix covers every `PersonContextKind` and its lawful surface, purpose, relevance, freshness, effect, prohibited inference, and override.
- [x] Conflict authority is centralized as boundary, safety, scheduled commitment, fresh capacity, current priority, then preference or wording.
- [x] Privacy-safe traces record used and rejected signals, reasons, no-context baseline, permitted field, effect size, and actual before/after delta digests.
- [x] Irrelevant, stale, withdrawn, expired, wrong-purpose, wrong-surface, unknown, and overreaching context cannot change behavior; normalized Decision Engine output is identical to the no-context baseline for irrelevant, ignored, stale, and withdrawn cases.
- [x] Withdrawal, expiry, account transition, deletion, and displayed-response invalidation have focused host proof.

Priority 2 is complete at the local host-evidence level. It is not a device,
deployed-service, release, or human-usefulness result.

## Priority 3 exit checklist

- [x] One governed context enters the canonical Decision Engine before Nexus ranking.
- [x] Current priority is limited to a 0.25-point tie-break; explicit boundaries, capacity caps, and scheduled-commitment conflict order have scenario fixtures, including truthful rejection of a lower-authority commitment that targets a boundary-excluded task.
- [x] Smart Planner grounds generic requests only with a matching task, goal, receipt, or fresh consented Person Context with positive text or typed-domain relevance; wording-only preferences cannot become planning subject matter or suppress a relevance clarification.
- [x] Nexus exposes `Why this changed` and a session-only `Ignore this context for now` control that resets across the account fence.
- [x] Before/after ranking, no-context invariants, policy-delta trace, UI override, and unrelated-first-task regression have focused host proof.

Priority 3 is complete at the local host-evidence level. Exact-commit CI,
physical-device behavior, accessibility capture, performance, and human UAT
remain unverified.
