# ChronoSpark master A1–A15 repair roadmap

**Status:** planning only — no repair authorized by this document.  
**Authoritative audit baseline:** `backup-before-review-20260808` at
`8b3e84bbdbdaaa041deafa60b23000ad11852022`.

## Operating rules

This roadmap consolidates the completed A1–A15 audit reports, not the dirty
working tree. The historical audits were reported as phase findings rather than
stored as a repository-local finding database. The `A#-NN` references below are
therefore stable source-reference aliases preserving the originating audit and
finding subject; they do not claim that the implementation contains those IDs.

Every repair must use the authoritative branch and preserve the protected
repository constraints:

- no broad reset, clean, stage-all, forced checkout, or deletion of recovery
  artifacts;
- establish the exact index/candidate before modifying a protected file;
- preserve unrelated dirty work and staged/index state;
- do not treat an archive, recovery ref, or dirty tree as a source of truth
  without provenance;
- make narrow commits from an exact-index validation sandbox; and
- rerun the relevant lifecycle/scope overlay after any account-boundary change.

## Raw source inventory

There are **63 normalized source observations**: **0 P0, 17 P1, 33 P2, and 13
P3**. They are retained below by audit provenance. Multiple rows can resolve to
one repair; this is intentional and prevents symptom-by-symptom repairs.

| Audit | Source references | Normalized observations |
|---|---|---|
| A1 repository/recovery | A1-01–04 | authority branch ambiguity, duplicate/recovery histories, dirty/index risk, release-source confusion |
| A2 runtime source of truth | A2-01–03 | competing entry/provider wiring, dormant authority, implicit bootstrap dependencies |
| A3 persistence/ownership | A3-01–06 | global local scope, key/runtime mismatch, parallel repositories, persistence ownership ambiguity, backup/sync overlap |
| A4 auth/lifecycle | A4-01–07 | lifecycle not reliably activated, router ahead of readiness, stale A→B data, signed-out recovery scope, transition races, local retention |
| A5 backend/sync | A5-01–04 | remote RLS generally sound, local carried state can later write as B, queue/drain isolation, backup object ownership gaps |
| A6 UI readiness | A6-01–04 | screens read before account readiness, mixed provider authority, stale/empty/error-state ambiguity, unsupported surface gating |
| A7 mutation authority | A7-01–05 | parallel commands, stale-state mutation, non-atomic history fan-out, idempotency gaps, reminder ownership ambiguity |
| A8 domain semantics | A8-01–08 | profile/progression split, habit contradiction, note contract gap, skip/history ambiguity, plan orphaning, intervention incompleteness |
| A9 journeys/navigation | A9-01–04 | recommendation-only planner, missing note/intervention journeys, navigation/surface inconsistencies, feature discoverability debt |
| A10 AI/SI | A10-01–06 | stale context, memory provenance, unbound explanations, heuristic confidence, categorical drift labels, weak controls/rewards policy |
| A11 privacy/retention | A11-01–08 | sign-out retention, consent gaps, derived-data deletion, export gap, backup retention, conversation/emotion controls, analytics/crash uncertainty |
| A12 quality/release | A12-01–04 | source-only confidence, missing A→B/device/staging proof, coverage/release gate gaps, failure-injection gaps |
| A13 observability | A13-01–04 | unreconstructable transitions, invisible sync/AI/deletion failure, limited alerting, sensitive logging governance |
| A14 supply chain/build | A14-01–03 | mutable actions, long-lived secret/config risk, dependency/toolchain/release-authority gaps |
| A15 application security | A15-P1-01–04; A15-P2-01–05; A15-P3-01–04 | local cross-account exposure, plaintext fallback, backup tampering, AI exfiltration, logging/resource/auth/transport and test debt |

## Root-cause clusters and canonical repairs

| Cluster | Root cause | Source references | Canonical repairs |
|---|---|---|---|
| A — account lifecycle/local scope | Account transition is not the single owner of readiness, local scope teardown, and post-transition invalidation. | A2-01, A3-01–03, A4-01–07, A5-02–03, A6-01–03, A7-01–02, A10-01, A11-01, A15-P1-01/A15-P1-04 | FIX-001–004 |
| B — profile/progression authority | Two authority paths persist/present profile and progression. | A3-03, A6-02, A7-01, A8-01, A9-04 | FIX-005 |
| C — habit contradiction | Habit, recurring task, creator, and onboarding use incompatible domain meanings. | A8-02, A9-04 | FIX-006 |
| D — note contract | Notes have no decided authority or complete user journey. | A8-03, A9-02 | FIX-007 |
| E — task occurrence/history | Skip, completion ledger, Timeline, and fan-out do not share an atomic occurrence contract. | A7-03–04, A8-04 | FIX-008 |
| F — planner acceptance | Planner output lacks an accepted, modified, saved target. | A8-05, A9-01 | FIX-009 |
| G — interventions | Models/outcomes exist without an owned command/UI lifecycle. | A8-06, A9-02 | FIX-010 |
| H — AI/SI provenance | Context, memory, explanation, confidence, and user controls lack one evidence-bound contract. | A10-01–06, A11-03–04, A15-P1-04 | FIX-011 |
| I — privacy/retention | Controls, consent, deletion, export, and retention rules are incomplete or not demonstrably implemented. | A11-01–08, A13-04, A15-P2-01 | FIX-012 |
| J — backup/storage security | Storage recovery can silently weaken confidentiality; restore has insufficient provenance and safety controls. | A3-05–06, A5-04, A11-06, A15-P1-02/A15-P1-03 | FIX-013 |
| K — confidence/reliability | Source-level checks substitute for runtime, fault, device, and release evidence. | A12-01–04, A15-P3-04 | FIX-014 |
| L — supply-chain/release trust | Release inputs, credentials, actions, dependency governance, and branch authority are not fully immutable/auditable. | A1-01–04, A14-01–03 | FIX-015 |
| M — observability | Security and lifecycle incidents lack structured, reconstructable evidence and alerts. | A13-01–04, A15-P2-01/A15-P3-02 | FIX-016 |
| N — surface/naming cleanup | Legacy routes, dead presentation paths, and terminology make authority difficult to discover. | A1-04, A6-04, A9-03–04 | FIX-017 |

## Dependency DAG

| Repair | Depends on | Blocks | Can run in parallel with |
|---|---|---|---|
| FIX-001 lifecycle activation | none | FIX-002–004, 011–014 | FIX-015–017 |
| FIX-002 router/readiness gate | FIX-001 | FIX-003, 004, 011 | FIX-005–010 after scoped contract is fixed |
| FIX-003 account-scoped persistence/key alignment | FIX-001, FIX-002 | FIX-004, 011–013 | FIX-015–017 |
| FIX-004 transition drains/recovery/invalidation | FIX-001–003 | safe A→B certification, FIX-011 | FIX-015–017 |
| FIX-005 profile/progression authority | FIX-003 | profile surface correctness | FIX-006–010 |
| FIX-006 habit decision/consolidation | product decision | related journeys | FIX-005, 007–010 |
| FIX-007 note decision/journey | product decision | note UX | FIX-005, 006, 008–010 |
| FIX-008 occurrence/history authority | FIX-003 | reliable planning/history/intelligence | FIX-005–007, 009–010 |
| FIX-009 planner acceptance | product decision, FIX-008 | planner journey | FIX-005–007, 010 |
| FIX-010 intervention lifecycle | product decision, FIX-008 | intervention UX | FIX-005–007, 009 |
| FIX-011 SI provenance/controls | FIX-003, FIX-004, FIX-008 | trustworthy intelligence claims | FIX-012–017 |
| FIX-012 privacy/retention | FIX-003, FIX-004, product policy | privacy certification | FIX-013, 015–017 |
| FIX-013 backup/storage security | FIX-003, product recovery policy | backup safety | FIX-012, 014–017 |
| FIX-014 runtime confidence suite | FIX-001–004, then each repaired authority | release certification | FIX-015–017 |
| FIX-015 supply-chain/release trust | none | release certification | all implementation repairs |
| FIX-016 observability | FIX-001 for lifecycle events | incident response evidence | FIX-012–015, 017 |
| FIX-017 source/surface cleanup | authority repairs that it would remove | maintainability | FIX-015–016 |

## Repair waves

### Wave 1 — Account safety foundation

`FIX-001`, `FIX-002`, `FIX-003`, and `FIX-004` are the smallest release-blocking
set. They must pass before any claim that account switching or shared-device use
is safe. `FIX-013` cannot be released as a security assurance until this wave
defines the account-scoped storage contract.

### Wave 2 — Domain authority / command correctness

`FIX-005` through `FIX-010`: profile/progression authority, habit decision,
note decision, occurrence/history semantics, planner acceptance, and
intervention lifecycle.

### Wave 3 — Intelligence / privacy / explainability

`FIX-011`, `FIX-012`, and `FIX-013`: evidence-bound intelligence, privacy and
retention controls, and safe backup/storage recovery.

### Wave 4 — Reliability / observability / testing

`FIX-014` and `FIX-016`: failure injection, A→B runtime proof, release evidence,
structured diagnostics, and alerting.

### Wave 5 — Supply chain / release certification / cleanup

`FIX-015` and `FIX-017`: immutable release inputs, credential minimization,
dependency governance, release authority, and residual source/surface cleanup.

## Canonical backlog

| ID | Title / severity | Root cause and source audits | Dependencies / affected subsystems | Decision / migration / shape | Required proof | Wave |
|---|---|---|---|---|---|---|
| FIX-001 | Activate one account lifecycle authority — **P1** | Dormant/implicit lifecycle ownership; A2-01, A4-01–02, A6-01, A15-P1-01 | auth session boundary, lifecycle coordinator, app bootstrap | No product decision; no migration; multi-file baseline | provider/integration transition tests, A→B, exact-index, analyzer | 1 |
| FIX-002 | Gate routing on authenticated data readiness — **P1** | Router can outrun scope readiness; A4-02, A6-01–03 | router, app root, auth/profile readiness providers | No decision; no migration; UI gate | route integration, A→B, Maestro, exact-index, analyzer | 1 |
| FIX-003 | Establish account-scoped local persistence and runtime keys — **P1** | Global keys and migration/runtime mismatch; A3-01–04, A4-03–06, A5-02, A15-P1-01 | Hive/secure store/preferences, profile, learning, settings, extended domain | Product decision: sign-out retention; **both/unknown** migration; data migration | migration fixtures, old→new and A→B tests, failure injection, exact-index, analyzer | 1 |
| FIX-004 | Own transition drain, recovery, reminder, sync, and invalidation — **P1** | Transition work can race/recover under stale scope; A4-04–07, A5-03, A7-02, A15-P1-04 | sync queue, reminders, bridge, recovery, provider invalidation | No decision; local migration only if queues change; multi-file baseline | drain/replay tests, A→B, failure injection, integration, exact-index | 1 |
| FIX-005 | Consolidate profile and progression authority — **P2** | Parallel repositories/controllers own similar state; A3-03, A6-02, A8-01 | profile/progression repositories, controllers, surfaces | Product decision: presentation ownership; local/remote migration **unknown**; feature rewire | unit/provider/integration migrations, human UX, analyzer | 2 |
| FIX-006 | Decide and consolidate the habit domain — **P2** | HabitRecord vs recurring task contradiction; A8-02, A9-04 | habit/task entities, creator, onboarding, schedules | **Product decision required**; both migration likely; product decision first | migration fixtures, recurrence/skip tests, journey test, human test | 2 |
| FIX-007 | Decide notes authority and complete notes journey — **P2** | First-class vs task-backed notes unresolved; A8-03, A9-02 | note/task models, repository, UI | **Product decision required**; local/remote migration unknown; product decision first | CRUD/filter/delete/provider/integration tests, human test | 2 |
| FIX-008 | Establish task-occurrence, skip, and history authority — **P2** | Fan-out and idempotency lack canonical occurrence record; A7-03–04, A8-04 | tasks, completion ledger, Timeline, sync | **Product decision: skip**; both migration likely; multi-file baseline | atomicity/idempotency/retry/sync tests, failure injection, A→B where scoped | 2 |
| FIX-009 | Give Smart Planner recommendations an accepted destination — **P2** | Plan repository is orphaned/recommendation-only; A8-05, A9-01 | planner, plan repo, task/goal UI | **Product decision required**; migration unknown; feature rewire | accept/modify/save/retry integration and human journey tests | 2 |
| FIX-010 | Implement intervention command and outcome lifecycle — **P2** | Model/outcome exists without producers or controls; A8-06, A9-02 | interventions, SI, UI, outcome repo | **Product decision required**; local migration possible; feature rewire | trigger/evidence/control/disable/snooze tests, integration, human test | 2 |
| FIX-011 | Bind SI/AI to scoped evidence, provenance, explanation, and uncertainty — **P1** | Context and claims are not fully evidence-bound or user-controlled; A10-01–06, A15-P1-04 | SI memory, DecisionEngine, AI proxy, trajectory, controls | Decisions: confidence, labels, AI XP; local/remote migration unknown; feature rewire/backend | provenance/trace tests, prompt/context isolation A→B, backend tests, human review | 3 |
| FIX-012 | Establish privacy, consent, deletion, export, and retention contracts — **P2** | Controls/retention not matched to sensitive data; A11-01–08 | settings, deletion, analytics, AI, backup, memory | **Product decision required**; both migration likely; feature rewire/backend | consent matrices, delete/export tests, A→B, backend retention proof, human legal review | 3 |
| FIX-013 | Secure backup and encrypted local-storage recovery — **P1** | Silent plaintext fallback and destructive unverifiable restore; A3-05–06, A11-06, A15-P1-02–03 | HiveService, backup/restore, cloud objects | **Product decision: recovery UX**; both migration likely; data migration/backend | tamper/signature/rollback/quota tests, encryption-failure test, backend tests, human recovery test | 3 |
| FIX-014 | Build runtime reliability and release evidence suite — **P2** | Existing checks do not prove real transitions/failure behavior; A12-01–04, A15-P3-04 | tests, CI, staging/device harness | No decision; no migration; test-only/CI | A→B, fault injection, Maestro/Patrol, device and staging evidence, release gate | 4 |
| FIX-015 | Establish supply-chain and release authority — **P2** | Mutable release inputs and unclear authority reduce trust; A1-01–04, A14-01–03 | branches, Actions, secrets, dependencies, build tooling | No product decision; no migration; CI/release | SHA-pinned workflows, secret inventory, SBOM/scan, reproducible build, rollback drill | 5 |
| FIX-016 | Establish reconstructable security/lifecycle observability — **P2** | Incidents cannot be reliably reconstructed; A13-01–04, A15-P2-01/P3-02 | logging, analytics, crash reporting, alerts | Privacy policy decision may be required; no migration; multi-file/CI | structured-event schema tests, redaction tests, alert drill, deletion/sync trace proof | 4 |
| FIX-017 | Retire obsolete source/surface artifacts after authority is settled — **P3** | Legacy naming/routes obscure authority; A1-04, A6-04, A9-03–04 | routes, unused adapters, docs, terminology | No decision; no migration; small API repair/documentation | reference scan, navigation regression, analyzer, exact-index | 5 |

## Findings intentionally not repaired

- Remote RLS and Edge bearer authorization are not a repair item: no remote
  cross-user authorization bypass was confirmed by A5/A15.
- Static deep-link host/path/route allowlists and destination-only notification
  routing are accepted architecture, subject to regression coverage.
- AI has no direct domain-action/tool authority and no committed remote-web
  context ingestion; these are constraints to preserve, not defects to rewire.
- Platform secure storage is not expected to resist a rooted/jailbroken device;
  the product must document that boundary rather than promise impossible local
  confidentiality.
- Client-side tester/premium presentation checks are not treated as a server
  entitlement bypass where server purchase/credit enforcement remains decisive.
- P3 naming and cleanup work must not be pulled into a scope-safety repair.

## First repair

**FIRST REPAIR ID: FIX-001 — Activate one account lifecycle authority.**

It is first because all account-safety evidence depends on a reliable transition
owner. It unblocks readiness gating, scoped persistence migration, drains and
invalidation, A→B proof, and prevents later domain repairs from binding to a
stale session. It must not change storage-key formats, profile/progression
behavior, AI logic, reminder configuration, domain semantics, or any unrelated
dirty work. Those are later, separately attributable repairs.

## Readiness

**READY-TO-START-REPAIRS**, with the protected-repository rules above mandatory.
The first implementation remains blocked only if the exact authoritative
candidate/index boundary for its protected files cannot be reconstructed.
