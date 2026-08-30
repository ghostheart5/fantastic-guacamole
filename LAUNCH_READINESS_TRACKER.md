# ChronoSpark 2040 Launch Readiness Tracker

## Baseline

- Audit: `C:\Users\keegan radetski\Downloads\ChronoSpark_2040_Vision_Reaudit_2026-08-30.md`
- Audit SHA-256: `7B4E86423D8C5BB78CB59D97075648C8837551327A6A11504E83C7601794BA5D`
- Audited commit: `c9ad6084e115227770f48fb09d46c364b4cd1a53`
- Repair baseline: `46494890aa5a8ddbec7c6a3c303fc9aa845651b4`
- Delta from audit: one commit, 19 files, `+405/-66`, cold-start evidence gating only.
- Repair branch: `fix/chronospark-2040-launch-readiness-20260829`
- Repair worktree: `C:\Users\keegan radetski\ChronoSpark-2040-launch-readiness-20260829`
- Original checkout: preserved with its pre-existing unstaged `android/gradle.properties` change.
- Recovery snapshot: `C:\Users\keegan radetski\ChronoSpark-snapshots\20260829-2040-readiness-4649489`
- Current verdict: `NO-GO - NOT READY`

Statuses are `PASS`, `FAIL`, `BLOCKED_EXTERNAL`, and `NOT_RUN`. Containment is not a completed product repair.

## Phase 0 Checkpoint

- Commit: `68bc277b936a49e890a4c1d94bdc05d5a087353d`
- Scope: non-overridable launch switches, route/provider/service guards, truthful unavailable states, native permission/telemetry defaults, inferred-identity hiding, and regression tests.
- Migrations: none. User data was not transformed.
- Feature state: cloud sync/restore, subscriptions/paywall, external AI, credit spending, Analytics, Crashlytics, and inferred identity are disabled.
- Verification: formatting, analyzer, 1,605-test full suite, QA-define test, architecture/security/release/version guards, workflow/Maestro validators, and Edge Function gate passed.
- Remaining risk: containment is not product completion; deletion, consent, restore integrity, billing, AI safety, device evidence, and external production gates remain open.
- Rollback: revert only `68bc277b936a49e890a4c1d94bdc05d5a087353d`. Never re-enable an unsafe capability as a side effect of rollback.

## Phase 1 Plan - Human Trust And First Proof

- Status: `COMPLETE_LOCAL` at `c72d50b`; launch verdict remains `NO-GO - NOT READY`.
- Scope: authoritative emotional-state and governed-memory consent; truthful unknown human state; bounded startup recovery; accessible and recoverable guidance; truthful Timeline source states; evidence-gated tutorial completion; auth recovery, pre-account legal access, and protected `returnTo` preservation.
- Planned code areas: `lib/state/models/personalization_models.dart`, personalization/emotion/memory/SI providers and controllers, Smart Planner context construction, startup gate, adaptive guidance overlays, Timeline state/UI, auth UI, onboarding, and router policy.
- Planned tests: consent migration/revocation/restart; context omission across Planner/SI/Nexus/Trajectory/AI/memory; startup double-timeout/retry/degraded state; tutorial large-text/focus/skip/restart/resume; Timeline loading/error/empty/offline/evidence states; legal links and auth recovery; protected deep-link continuity.
- Risks: legacy consent values must fail closed without deleting reviewable memory receipts; internal numeric planning fallbacks must never be labeled observed; startup degradation must not open account-scoped storage before quiescence; tutorial milestones must not advance from navigation alone.
- Data migration: no destructive migration. Legacy consent payloads without versioned grant timestamps are interpreted as revoked. Existing governed-memory records remain reviewable/exportable/deletable but unavailable for recall while consent is off.
- Rollback: each Phase 1 subphase is a separate local commit. Revert only the affected subphase after confirming consent remains fail-closed, launch containment remains active, and no unsafe startup/account boundary is reopened.
- Evidence boundary: source, Windows host tests, and local validators only. Android/device accessibility, visual QA, deployed services, signed artifacts, and human UAT remain unverified.

## Phase 2 Checkpoint - Account And Data Integrity

- Status: `BLOCKED_EXTERNAL` at `55d245a`; launch verdict remains `NO-GO - NOT READY`.
- Commits: truthful deletion outcomes at `061ea18`; strict account-bound restore validation at `51b96be`; compare-and-swap sync and local mutation fencing at `bc44261`; task-occurrence containment at `c05dd56`; serialized Notes at `d50d399`; first-party report endpoint pinning at `46a4cd6`; least-privilege grants and exact Storage policies at `9c8e716`; legacy backup retirement at `e79f93b`; strict restore previews at `8915f5c`; canonical settings backup at `f0a04f9`; serialized Timeline lifecycle writes at `80290ae`; sensitive corruption preservation at `1a0297a`; canonical legal copies and repaired Terms route at `55d245a`.
- Feature state: cloud sync and restore remain disabled. The new database migration is committed locally but has not been applied to any deployed project.
- Local verification: fatal analyzer, focused adversarial tests, 1,724-test full Flutter suite with one expected QA-only skip, formatting, architecture, secret, release, version, workflow, Maestro, legal-generation, migration-policy, staged-diff, and whitespace gates passed.
- Blocked external evidence: this host currently exposes neither Docker nor a standalone Supabase CLI. Disposable fresh-project migration replay, pgTAP, database lint, deployed grants/RLS/Storage verification, real concurrent-device sync, provider reauthentication/AAL behavior, and public legal readback therefore remain unverified.
- Remaining Phase 2 scope: migrate the remaining global local stores to exact per-account namespaces under a fault-injected migration; prove scalable Storage deletion and lifecycle behavior against a real backend; validate exact-session/nonce/AAL reauthentication for password, Google, and GitHub; and obtain qualified legal review. These changes must not be inferred from host tests or enabled behind containment.
- Rollback: revert only the affected local Phase 2 commit. Do not apply or revert the database migration against a live project without a separate production change plan and approval.

## Phase 3 Checkpoint - Governed Person Context

- Status: `COMPLETE_LOCAL`; launch verdict remains `NO-GO - NOT READY`.
- Scope: one account-scoped Person Context spine for user-authored roles, values, priorities, life areas, present capacity, support style, boundaries, important relationships, commitments, and confirmed outcome history. Every signal carries source, consent and withdrawal timestamps, purpose, surface scope, freshness, expiry, correction history, export behavior, deletion behavior, and explicit known/unknown state.
- User control: Settings provides explicit opt-in with exact text and selected surfaces, separate About you and Right now summaries, review, correction with reason, timestamped consent withdrawal, export, single deletion, and delete-all. Signed-out, corrupt, and unavailable states are disclosed and never represented as valid empty context.
- Intelligence binding: Smart Planner uses eligible operational context to change bounded, grounded guidance. Nexus and Trajectory attach the same purpose-limited projection as explicit evidence only and state that it does not change ranking or projection calculations. Creator displays every exact item bound to confirmation, states that it did not alter the proposed task, rechecks the binding after asynchronous reads and immediately before mutation, and fails stale if it changes. SI V2 visibly distinguishes unavailable, valid-empty, and present Person Context; present context is revision and safety provenance only, not used to construct answers or exposed as answer evidence. Expired, stale, withdrawn, wrong-purpose, wrong-surface, and wrong-account signals are excluded.
- Storage boundary: repository operations are serialized with account cleanup, bound to the current account-session generation, corruption is preserved and surfaced, automatic-expiry records are physically purged, and competing repository instances cannot lose signals. Person Context is explicitly local-only and excluded from backup/sync until a merge-safe contract exists.
- Local verification: fatal analyzer, 101 focused Phase 3 tests, and the 1,776-test full Flutter suite with one expected QA-only skip passed. Formatting across 973 files, architecture, both secret guards, release, version, 11 workflow, 16 Maestro, and the 29-test Edge Function gate also passed. An independent read-only review found no remaining Critical or High Phase 3 blocker.
- Evidence boundary: host source and automated-test evidence only. Android/device accessibility and visual QA, real multi-device behavior, deployed backend behavior, backup-key recovery, signed artifact verification, public configuration, Spanish coverage, and human UAT remain unverified. Person Context does not make ChronoSpark a whole-person or synthetic-emotional-intelligence system.
- Rollback: revert the Phase 3 checkpoint only. Do not enable cloud sync/restore, external AI, subscriptions, production telemetry, or release as a rollback side effect.

## Phase 5 Checkpoint - One Intelligence Authority

- Status: `COMPLETE_LOCAL`; launch verdict remains `NO-GO - NOT READY`.
- Authority: one versioned `OperatingSnapshot -> OperatingDecisionPlan -> OperatingDecisionReceipt` chain supplies the surfaced next action for Smart Planner, Nexus, Timeline, Trajectory, SI V2, and notifications. Cross-surface parity tests prove identical snapshot, plan, and decision identities for the same evidence. Legacy engines remain available for compatibility but are not the surfaced next-action authority.
- Lifecycle: one canonical actionability predicate excludes completed, canceled, and skipped tasks from planning, Timeline projections, SI evidence, and recurrence mutation. Typed schedule and deadline edits preserve their distinct meanings and reject temporal mutation after a task reaches a terminal state.
- Planner and SI: Smart Planner uses relevant task and goal evidence, asks one clarification when evidence is insufficient, preserves crisis routing, records receipt outcomes, and stages accepted guidance through Creator preview without saving. SI V2 keeps a calm question-first default while Advanced retains the complete read-only, inspectable evidence contract and uses the shared receipt for its recommendation.
- Outcomes and forecasts: shown, accepted, rejected, deferred, skipped, completed, and corrected receipt outcomes feed bounded, deduplicated local learning. Nexus discloses what changed and allows correction. Trajectory keeps assumptions beside forecasts, records assumption corrections, and labels unchanged models provisional or monitored rather than calibrated.
- Local verification: formatting across 993 files, fatal analyzer, 1,834-test full Flutter suite with one expected QA-only skip, 15 QA-defined tests, architecture, both secret guards, release, version, 11 workflow, 16 Maestro, and the 28-test Edge Function gate passed.
- Evidence boundary: host source and automated-test evidence only. Android/device accessibility and visual QA, human usefulness testing, real notification delivery, deployed database/backend behavior, signed artifacts, cloud behavior, and public configuration remain unverified. External AI, subscriptions, cloud sync/restore, production telemetry, and release remain contained.
- Rollback: revert only the Phase 5 checkpoint. Do not restore a legacy engine as a surfaced authority or enable any contained capability as a rollback side effect.

## Phase 6 Checkpoint - Human-First First Value

- Status: `COMPLETE_LOCAL`; launch verdict remains `NO-GO - NOT READY`.
- First value: first setup no longer requires a name, task, schedule, or Timeline visit before showing value. It asks one optional current-help question and an optional capacity check-in, then hands the account-scoped, short-lived input to Smart Planner for one deterministic grounded choice, reason, evidence, assumptions, and reversible Creator preview. Skipping routes to Nexus without creating anything.
- Consent and control: setup and Planner state that the words and check-in remain ephemeral, while a local decision receipt may record which guidance was shown or used. Nothing is created until the user confirms in Creator. Advanced profile setup remains deferred.
- Recovery and routing: progress is consistently numbered across welcome, login, and onboarding; protected deep-link intent remains authoritative; setup can be skipped, resumed, or restarted from Settings without deleting tasks or product milestones. Automatic first-task, first-schedule, and Timeline interventions are suppressed, while explicit tutorial replay remains available.
- Local verification: 54 focused onboarding, Planner, routing, tutorial, auth, and Settings tests passed. The 1,853-test full Flutter suite passed with one expected QA-only skip. Formatting across 997 files, fatal analyzer, architecture, both secret guards, release, version, 11 workflow, 16 Maestro, and the 28-test Edge Function gate passed.
- Evidence boundary: host source and automated-test evidence only. The 60-90 second usefulness target, Android visuals, real keyboard and offline/auth-failure behavior, TalkBack, Switch Access, reduced-motion device behavior, tablet behavior, and human UAT remain unverified. External AI, subscriptions, cloud sync/restore, production telemetry, and release remain contained.
- Rollback: revert only the Phase 6 checkpoint. Do not restore forced creation or automatic tutorial interventions, and do not enable any contained capability as a rollback side effect.

## Phase 7 Checkpoint - Emotional Safety And Optional External AI

- Status: `BLOCKED_EXTERNAL`; launch verdict remains `NO-GO - NOT READY`.
- Deterministic authority: Smart Planner and SI V2 route immediate-safety and non-crisis distress before reading task or goal evidence. Severe distress cannot continue into productivity guidance, and the deterministic Planner response remains the sole decision authority.
- Optional AI boundary: one read-only Smart Planner explanation surface is implemented behind independent compile-time containment, personalization consent, authentication, first-party endpoint, release-control, provider-retention, qualified-safety-review, model-allowlist, and model-evaluation gates. Every release gate defaults closed, so no external request or credit spend is reachable in the current build.
- Safety and billing: server-owned request and response schemas reject client prompt/model/action authority, poisoned clauses, distress input, unsupported provenance, invented precision, diagnosis, therapy, pressure, and mutation claims. A quote precedes consent and execution; cancellation charges zero, and timeout, refusal, malformed output, unsafe output, model mismatch, or transport failure refunds the reservation. Idempotent retries cannot double charge.
- Privacy: the external packet contains only the visible deterministic clause identifiers, clause text, and bound response digest. First-party response content expires after four minutes and is scheduled for metadata-only scrubbing within the disclosed five-minute target under normal scheduler operation. The canonical privacy copies disclose Anthropic, minimized rather than sanitized data, the replay window, and the current unverified provider-retention gate.
- Local verification: 124 focused Flutter safety, Planner, SI, client-contract, static database-contract, release-control, and UI tests passed; 19 Planner explanation Edge Function tests and the 47-test full Edge Function gate passed; the 1,909-test full Flutter suite passed with one expected QA-only skip; fatal-info analysis and the architecture, domain-classification, product-canon, formatting, secret, release, version, workflow, Maestro, legal-copy, and focused server checks passed. No live model request, deployment, migration, secret access, or credit spend occurred.
- Blocked external evidence: qualified mental-health-safety review; signed provider DPA and actual retention/ZDR evidence; fresh database migration replay and lint; deployed function, secret, allowlist, rate-limit, wallet, replay, cron-scrub, and refund verification; real Android crisis-resource, localization, accessibility, offline, and adversarial UAT.
- Rollback: revert only the Phase 7 checkpoint. Keep deterministic SI and emotional-safety routing; do not enable external AI or credit spending as a rollback side effect.

## Findings

| ID | Severity | Finding | Phase | Status | Feature state | Repair commit | Evidence |
|---|---|---|---:|---|---|---|---|
| P0-01 | P0 | Emotional and governed-memory consent controls are not authoritative | 1 | PASS | versioned consent is enforced at context boundaries; saved Planner preferences are disclosed as not used in this build | `4146de5`, `6cdd536`, `c72d50b` | Consent migration/revocation/context tests and full host suite |
| P0-02 | P0 | Fresh users receive invented personal state and identity | 0/1 | PASS | fresh metrics remain unmeasured; inferred identity hidden | `4649489`, `68bc277` | Nexus/Profile tests and containment test |
| P0-03 | P0 | Cloud restore can replace valid local data with partial/corrupt data | 0/2 | PASS | restore remains disabled; strict validation, account binding, rollback, mutation fencing, and durable task replacement are repaired locally | `51b96be`, `bc44261` | Focused restore/race/fault tests and full host suite; database/device evidence remains open |
| P0-04 | P0 | Client reports account deletion complete for pending `202` | 2 | PASS | accepted, pending, completed, failed, and local-cleanup outcomes remain distinct | `061ea18` | Account deletion service/provider/UI outcome tests |
| P0-05 | P0 | Premium offer does not visibly unlock advertised benefits | 0/8 | PASS | billing permission, route, UI, provider, and actions disabled | `68bc277` | Paywall, route, settings, and native tests |
| P0-06 | P0 | External generative AI is dormant and unsafe to expose | 0/7 | PASS | one read-only explanation path is implemented behind independent default-closed gates; external model calls and credit spending remain disabled | `68bc277`, Phase 7 checkpoint | Client and server schema, injection, provenance, billing, retry, containment, and UI tests; live provider evidence remains blocked |
| P0-07 | P0 | Crisis and distress routing is too brittle for emotional claims | 7 | BLOCKED_EXTERNAL | local immediate-safety and supportive-distress routing is repaired before evidence access; external AI remains disabled | Phase 7 checkpoint | Local direct, indirect, adversarial, grief, abuse, panic, overdose, coercion, hallucination, localization, UI, and server tests pass; qualified review and device UAT remain blocked |
| P0-08 | P0 | Exact candidate lacks complete app CI and device evidence | 10 | NOT_RUN | release blocked | | Audit P0-8 |
| HUMAN-00 | P0 | Intelligence surfaces lack one consented, freshness-aware person-context source | 3 | PASS | local-only governed context is available to Planner, SI V2, Nexus, Trajectory, Creator, and Settings; cloud use remains disabled | Phase 3 checkpoint | 101 focused tests, 1,776-test full host suite, analyzer and guards; device and production evidence remain open |
| BILL-01 | P1 | Purchase lineage and lifecycle ordering have authority edge cases | 8 | NOT_RUN | paywall disabled | | Audit P1 |
| DOMAIN-01 | P1 | Whole-person concepts collapse into tasks | 4 | PASS | Goal, Task, Daily Rhythm, Note, Reflection, occurrences, and outcomes remain typed, linked, account-owned, navigable, searchable, and portable locally; cloud sync remains contained | Phase 4 checkpoint | 1,804-test full host suite plus QA-defined contract, analyzer, architecture, security, workflow, Maestro, release, version, and Edge gates; device, deployed backend, cloud, and release evidence remain open |
| PLAN-01 | P1 | Planner cannot apply guidance and can choose unrelated evidence | 5 | PASS | deterministic guidance uses relevant evidence, clarifies insufficient context, records outcomes, and stages accepted plans through Creator preview | Phase 5 checkpoint | Planner controller, safety, screen, Creator-draft, receipt-parity, and full host tests |
| SI-01 | P1 | SI Console is an expert workstation instead of a calm assistant | 5 | PASS | calm question-first default; complete read-only controls and evidence remain under Advanced; recommendation uses the shared receipt | Phase 5 checkpoint | SI V2 engine, contract, screen, accessibility, receipt-parity, and full host tests |
| TRAJ-01 | P1 | Trajectory presents fixed-coefficient simulation as calibration | 5 | PASS | assumptions are visible and correctable; unchanged models remain provisional or monitored rather than calibrated | Phase 5 checkpoint | Trajectory receipt, ledger, integration, accessibility, and full host tests |
| HUMAN-01 | P1 | Progression/Profile measure productivity, not whole-person growth | 3/5 | NOT_RUN | identity claims contained | | Major findings |
| ARCH-01 | P1 | Four competing next-action engines can disagree | 5 | PASS | legacy paths are retained for compatibility but six surfaced consumers share one versioned snapshot, plan, and receipt authority | Phase 5 checkpoint | Cross-surface receipt identity and provider invalidation tests plus full host suite |
| ARCH-02 | P1 | Skipped tasks can reappear as actionable | 5 | PASS | completed, canceled, and skipped tasks are terminal across planning, filtering, SI, Timeline, and occurrence handling | Phase 5 checkpoint | Lifecycle, policy, engine, Timeline, occurrence, and full host tests |
| ARCH-03 | P1 | Schedule/deadline separation and nullable clearing are incomplete | 4/5 | PASS | typed schedule/deadline edits preserve separate semantics, support explicit clearing, and reject terminal mutation | Phase 5 checkpoint | Entity, provider, recurrence, decision-engine, and full host tests |
| DATA-01 | P1 | Full backup omits advertised whole-person domains | 2/4 | NOT_RUN | restore disabled | | Data audit |
| DATA-02 | P0 | Sync maps errors to empty and can overwrite newer cloud state | 0/2 | PASS | sync remains disabled; typed reads, CAS revisions, local mutation generations, tombstones, and conflict outcomes are repaired locally | `bc44261` | Concurrent-writer, in-flight-edit, REST gateway, offline replay, and full host tests; pgTAP/deployed evidence remains open |
| DATA-03 | P1 | Corrupt local stores can be treated as empty and overwritten | 2 | PASS | malformed Task, Timeline, Notes, occurrence, queue, forecast, and sensitive-store payloads are preserved or quarantined before replacement | `c05dd56`, `d50d399`, `1a0297a` | Focused corruption/fault tests and full host suite; remaining domain migration is tracked under DATA-04 |
| DATA-04 | P1 | Persistence is global, fragmented, and serializer versions differ | 2/4 | BLOCKED_EXTERNAL | key repositories are serialized/versioned, but legacy global stores still require a fault-injected per-account migration | `c05dd56`, `d50d399`, `80290ae` | Exact multi-account migration and device proof remain open |
| SEC-01 | P1 | `ai_content_reports` lacks explicit fresh-project service grants | 2 | BLOCKED_EXTERNAL | forward migration grants only service-role INSERT and sequence usage | `9c8e716` | Static and SQL contract tests pass; fresh replay is blocked |
| PRIV-01 | P0 | Analytics/Crashlytics default on without real user control | 0/9 | PASS | native and Dart collection paths default off | `68bc277` | Static native tests, Env tests, Firebase tests |
| PRIV-02 | P1 | AI response retention and disclosure exceed stated minimization | 7/9 | BLOCKED_EXTERNAL | AI remains disabled; minimized packet, four-minute content expiry, metadata scrub, and canonical disclosure are implemented locally | Phase 7 checkpoint | Local schema, replay, legal-copy, and Edge tests pass; provider retention, deployed cron behavior, and qualified review remain blocked |
| SEC-02 | P1 | Storage permits arbitrary own-prefix uploads | 2 | BLOCKED_EXTERNAL | forward policy permits only two exact JSON paths with a 5 MiB limit | `9c8e716` | Static/SQL tests pass; deployed policy and lifecycle proof remain open |
| SEC-03 | P1 | Deletion reauthentication is not exact-session bound | 2 | NOT_RUN | server change pending approval | | Security audit |
| SEC-04 | P0 | Sensitive endpoints are not constrained to first-party origin/path | 0/2 | PASS | authenticated report endpoint must match the configured Supabase origin and exact function path | `46a4cd6` | Host configuration and hostile-URL tests |
| AUTH-01 | P1 | OAuth deletion is support-based rather than self-service | 2 | NOT_RUN | incomplete | | Security audit |
| LEGAL-01 | P1 | Public, root, and bundled legal text have drifted | 2/9 | BLOCKED_EXTERNAL | parser-generated copies match designated canonical documents and the broken Terms route is repaired | `55d245a` | Host content/route tests pass; qualified review and public readback remain open |
| VOICE-01 | P1 | Voice can bypass rationale and premium claims are unproven | 0/9 | NOT_RUN | no premium claim allowed | | Platform audit |
| NOTIF-01 | P1 | Reminders are not clearly opt-in and streak copy is coercive | 5/9 | NOT_RUN | local only | | Platform audit |
| ONBOARD-01 | P0 | First setup forces creation before demonstrating value | 6 | PASS | optional question and capacity check-in lead to ephemeral Planner guidance; skip creates nothing; accepted action remains a Creator preview until confirmation | Phase 6 checkpoint | Focused onboarding/Planner/restart tests and full host suite; device usefulness proof remains open |
| LINK-01 | P1 | Protected deep-link intent can be lost through onboarding | 1/6 | PASS | validated protected URI remains authoritative through login, onboarding, legal routes, Back, and the Phase 6 first-value branch | `c72d50b`, Phase 6 checkpoint | Real `appRouterProvider` and onboarding return-to tests |
| START-01 | P0 | Startup can wait forever after its timeout | 1 | PASS | timed-out results discarded; bounded locked recovery; retry waits for prior initializer settlement | `aca2b6b`, `bd70c01` | 16 focused startup tests and fatal analyzer gate |
| A11Y-01 | P0 | Required tutorial can trap large-text/small-viewport users | 1/6 | PASS | first setup is non-modal and skippable; bounded scrolling, 200% text, keyboard insets, semantics, focus restoration, reduced motion, and accessible navigation are covered locally | `c72d50b`, Phase 6 checkpoint | Host widget tests pass; device TalkBack and Switch Access proof remains Phase 10 |
| TIME-01 | P0 | Timeline maps loading/error to false empty and tutorial can lie | 1 | PASS | loading/error/corruption are distinct; unknown schema is quarantined; original bytes are preserved before repair; tutorial proof requires saved evidence | `c72d50b` | Repository, source-state, simultaneous-failure, and tutorial evidence tests |
| AUTH-02 | P1 | Auth recovery and pre-account legal access are incomplete | 1 | PASS | recovery paths retained; localized pre-account legal actions use production router wiring | `c72d50b` | Auth recovery, legal semantics, and real-router tests |
| L10N-01 | P1 | English/Spanish product coverage is incomplete | 9 | NOT_RUN | Spanish claim blocked | | Localization audit |
| PERF-01 | P2 | Bundle/dependency weight is unmeasured and likely wasteful | 9/10 | NOT_RUN | no removal without proof | | Performance audit |
| MAINT-01 | P2 | Oversized files and dormant rival paths increase risk | 5/9 | NOT_RUN | preserve until parity | | Maintainability audit |
| TEST-01 | P0 | Critical semantic, golden, device, and exact-head evidence is missing | 10 | NOT_RUN | release blocked | | Test audit |

## Protected Foundations

Do not remove Nexus/Decision evidence and reversible actions, Creator confirmation and undo, SI V2 evidence boundaries, Trajectory receipts, governed-memory contracts, account/RLS boundaries, recoverable deletion state machines, bounded deterministic learning, or correct notification/deep-link/voice/analytics sanitization work.
