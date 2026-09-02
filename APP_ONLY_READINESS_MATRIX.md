# ChronoSpark App-Only Readiness Contract

This file separates the immutable professor-report baseline from provisional
Gate 1 working-tree evidence. It is not an exact-commit release approval and
does not authorize a release, deployment, store action, external service, or
public product claim.

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
| Gate 1 candidate identity | Resolve the commit carrying this file with `git rev-parse HEAD`; its SHA must match the CI `exact-commit.json` artifact |
| Gate 1 evidence state | Local host evidence was recorded before commit; post-push CI status is authoritative only when attached to that exact commit |

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
| Governed Person Context storage | `SHIPPED / HOST-PROVEN` | Authorship, consent, freshness, purpose, surface scope, correction, export, deletion, and account boundaries exist. | A single behavior policy does not yet govern every surface. | Priority 2 policy matrix, exhaustive positive/negative tests, account-boundary tests, and decision traces. |
| Nexus ranking and Planner grounding | `BLOCKED` | Deterministic ranking, positive task/goal relevance, explanation, and bounded context evidence exist. | Relevant Person Context is not yet a controlled ranking authority and does not count as positive grounding in all required cases. | Priority 3 before/after traces, relevance/invariant tests, override test, and unrelated-task regression. |
| SI Console, Trajectory, and Creator context effects | `BLOCKED` | Context can be projected, displayed, bound, and freshness-checked. | The surfaces remain provenance-only, display-only, or review-only rather than applying one bounded behavior policy. | Priority 4 positive/negative surface tests and correction/withdrawal propagation proof. |
| Learning and adaptation | `SHIPPED / NARROW` | Task completion, task skip, decision outcomes, corrections, persisted affinity, and later decision-engine reads are reachable. | Cross-surface support strategy, decay, and a complete user-visible change ledger remain incomplete. | Priority 5 multi-session, decay, rollback/delete, privacy, and visible-ledger evidence. |
| First-use context | `BLOCKED` | Fast optional first value and Settings review/export/delete controls exist. | Durable context is not yet offered through the required lightweight, purpose-specific moment and remains hard to discover. | Priority 6 moderated script, widget/semantics proof, 320x568 and 200% text captures. |
| Local persistence and recovery | `SHIPPED / HOST-PROVEN` | Local repositories have account-session boundary guards, and restart/corruption recovery paths have automated host evidence. Some records are account-namespaced; learning currently uses a protected shared key rather than per-account namespacing. | Exact release-build device recovery, populated-state performance, per-account learning isolation, and data-loss UAT are not established. | Priority 2 account-boundary proof, Priority 8 physical-device restart/corruption evidence, and Priority 9 human recovery results. |
| Golden visual regression | `PLATFORM-PINNED / LIVE EXACT-COMMIT CHECK REQUIRED` | Gate 1 defines five logical, exact image comparisons: Login at 320/500 and Nexus at 320/375/500, backed by reviewed Windows and Linux masters. The harness loads Inter and Material Icons, disables supported animations, and selects only the active supported renderer instead of tolerating pixel drift. | Baseline source `6118ba6` contains zero image comparisons. Initial exact-commit run `33677111731` failed only the five Windows-versus-Linux pixel comparisons; a corrective commit remains blocked unless its own attached CI check passes. | Resolve the commit carrying this file, require its attached CI run to pass, and record the five-comparison/ten-master guard plus normal comparison result. |
| Maintainability and weak-layer coverage | `BLOCKED` | Analyzer and architecture guards pass on adjacent CI evidence. | Large change-sensitive files, stale classifications, 80 baseline `PLANNED` markers, and weak layer coverage remain. | Priority 7 responsibility map, reachability decisions, deletion list, coverage thresholds, analyzer, and architecture logs. |
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
| Gate 1 corrective exact-commit CI | `LIVE CHECK REQUIRED` | Resolve the commit carrying this file and read its attached CI check. Priority 1 remains blocked unless that run records the same SHA and passes normal comparison mode. |
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
- [ ] An authorized exact-commit CI run passes and is linked here.

Do not advance to Priority 2 until every unchecked item is satisfied or is
explicitly marked blocked with an owner and evidence requirement.
