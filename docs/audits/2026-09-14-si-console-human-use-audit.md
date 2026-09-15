# SI Console, intelligence and engine human-use audit

Saved at the user's request on 2026-09-14. This records the completed audit; saving it does not resolve its findings.

## Scope and verdict

- Checkout: `C:/Users/keegan radetski/Documents/Codex/2026-09-01/t/ChronoSpark-app-only-priority2`.
- Reviewed HEAD: `7fb06e7619f37a498e9a85324f2f83ae25aa759d`.
- Branch: `fix/aab-prebuild-cleanup-20260905`.
- Mode: audit and bounded validation; no application repairs, commits, rebuilds or publication.
- Coverage: all 61 files in `lib/engine`, plus SI Console UI/query handling, read gateway, contracts, providers, memory connections, use-case documentation and relevant tests.
- Existing unrelated work was preserved. This audit did not make the checkout clean or certify a release.

**Verdict: SI reads real saved app evidence, but input and output are not consistently aligned. Its human understanding and recommendation reliability need repairs before sign-off.**

## Executed evidence

- Seven selected existing SI suites: **58 passed, zero failed, zero skipped**.
- **24 actual SI V2 engine responses** generated with synthetic records and everyday questions.
- **Five connected-engine probes** covering projected/actual XP, retained schedules and dependencies.
- All 24 responses passed structural contract validation, including semantically wrong answers. This is a selected adversarial set, not a representative failure-rate estimate.
- Fresh Moto inspection reached SI Console on build `2026083048`, Android user 11 (`ChronoSpark-Review`). Instrumentation stopped before a fresh query was submitted, and the app screen changed independently of the recorded audit actions. This attempt is not a device-response pass. The owned Appium session/helper was closed/stopped.
- The initial Flutter launcher stalled without test events and was stopped. The SDK-runtime retry completed successfully; only that completed retry supports the 58-test result.
- No external model calls or real purchases were performed.

Evidence directory: `test-results/si-response-audit-20260914/`.

| Artifact | Meaning |
|---|---|
| `probe.dart` | Synthetic fixture runner importing the current SI V2 engine and contract |
| `outputs.jsonl` | First 21 complete input/output records |
| `outputs-extra.jsonl` | Two exact Spanish welcome suggestions and an exact-name follow-up control |
| `connected_engine_probes.dart` | Real planning/scoring/Trajectory engine probes with synthetic data |
| `connected-engine-outputs.jsonl` | Five connected-engine results |
| `existing-tests-retry.jsonl` | Completed Flutter test events: 58 passes across seven suites |
| `device/` | Partial Moto navigation, guarded observations and transport evidence; no completed fresh SI query |

## Current architecture

The shipping route is:

`SIConsoleScreen -> local input/safety/shortcut handling -> SIV2Query -> SIV2QueryService -> SIV2ReadGateway -> SIV2Engine -> optional shared OperatingDecisionReceipt -> safety checks -> response card`.

The dispatch is at `lib/features/si_console/ui/si_console_screen.dart:598`; composition is at `lib/state/providers/si_v2_provider.dart:181`.

The Console reads tasks, goals, milestones, Timeline and permitted Person Context. It runs a deterministic on-device response path. The old `AIController`, `SIAIService`, `SIEngineService`, `SyntheticIntelligenceEngine`, core reasoning/memory pipeline, and most cognitive layers are not the current Console execution route. Their presence does not prove that the Console uses them.

The current gateway is read-only, distinguishes missing/unavailable sources, bounds reads, and strips private content. The typed response separates observed/calculated/inferred/user-reported material and checks citation identities. These are useful foundations; they do not establish semantic correctness.

## Current SI findings

All findings below have high confidence in the stated source or synthetic-runtime evidence. Device reproduction remains unverified unless expressly stated.

### SI-01 — Excluded entities become positive recommendations

- Severity: High. Classification: confirmed engine behavior.
- Input: `What should I do next, not Submit tax return?`
- Output: recommends `Submit tax return` first.
- Impact: a user's explicit boundary is reversed.
- Evidence: probe `explicit-exclusion`; `lib/engine/si/si_v2_engine.dart:1271`, `:1296`, `:928`.
- Safe next action: represent exclusions and corrections explicitly and enforce them before ranking and response generation.

### SI-02 — Lookup questions are misclassified and requested ranking is lost

- Severity: Medium. Classification: confirmed engine behavior.
- `Which goal is overdue?` with one overdue goal becomes a comparison requiring two goals.
- A highest-priority question selects priority 1 over priority 5 because its earlier date controls ordering.
- Evidence: `single-overdue-goal`, `highest-priority`; query contract `lib/domain/entities/si_v2_contract.dart:139`; engine `:935`, `:1400`, `:1472`.
- Safe next action: distinguish lookup/comparison and distinguish requested priority from urgency.

### SI-03 — One response can concern different subjects

- Severity: High. Classification: confirmed engine/composition behavior.
- A named milestone with 75% completion produces a direct answer about missing progress for unrelated Personal fitness, while the recommendation mentions the requested milestone's 75%.
- A synthetic valid shared receipt makes the answer/scenarios select grocery receipts while the recommendation selects laundry.
- Evidence: `milestone-progress`, `shared-disagreement`; engine `:181`, `:725`, `:875`; `lib/domain/entities/si_v2_contract.dart:677`; `lib/state/providers/si_v2_provider.dart:181`.
- Limitation: shared-receipt injection proves composition behavior; it does not prove the exact mismatch occurred on the Moto.
- Safe next action: use one resolved subject/decision throughout the answer, reasoning, scenarios and recommendation; rebuild or reject an incompatible shared override.

### SI-04 — Time ranges and calendar meanings are not preserved

- Severity: High. Classification: confirmed engine behavior.
- A task scheduled today disappears when its due date is later.
- In the local-evening fixture, Today includes tomorrow's task and displays tonight using the next UTC calendar date.
- Evidence: `today-scheduled`, `local-today`; engine `:1184`, `:1230`.
- Safe next action: retain separate due/scheduled fields and use the user's local calendar consistently for filters and display.

### SI-05 — Scenario duration differs from the requested change

- Severity: Medium. Classification: confirmed engine behavior.
- A seven-day delay question generates one-day scenarios.
- Evidence: `seven-day-delay`; engine `:582`, `:806`; contract scenario enum `:34`.
- Limitation: the fixture proves duration substitution, not a missed linked-goal deadline. Scenarios are explicitly conditional, not guaranteed predictions.
- Safe next action: calculate the requested duration or explain the supported bound rather than substituting silently.

### SI-06 — Supported Spanish questions, including welcome suggestions, fail

- Severity: High. Classification: confirmed engine behavior and UI wiring.
- Five Spanish questions are refused in English, including `¿Qué necesita atención?` and `¿Qué debería hacer después?` from the localized welcome UI.
- English goal listing succeeds as a control.
- Evidence: both output files; `lib/l10n/chronospark_localizations.dart:928`; contract `:107`; engine `:1391`; response widget `lib/features/si_console/ui/si_console_screen.widgets.dart:445`.
- Safe next action: give English/Spanish equivalent intent, entity, negation, date and follow-up support, and localize the entire dynamic response.

### SI-07 — Known capacity is ignored and unknown overlap sounds reassuring

- Severity: Medium. Classification: confirmed response limitations.
- `I only have five minutes` selects a task titled `Complete a 90-minute bookkeeping class` without adapting the action or explaining the constraint.
- Two appointments with identical scheduled starts produce no-explicit-conflict wording; task evidence has no durations/end times to establish interval overlap.
- Evidence: `five-minute-budget`, `appointments-overlap`; task evidence contract `:191`; engine `:464`, `:824`.
- Limitation: the engine does not explicitly promise completing 90 minutes of work in five. Identical starts prove a possible collision, not interval overlap.
- Safe next action: honor known constraints and disclose missing duration/capacity instead of giving broad reassurance.

### SI-08 — Evidence strength conflates successful reads with support for an answer

- Severity: Medium. Classification: confirmed labeling/calculation issue.
- An empty snapshot says progress cannot be determined but labels evidence strong and reports 4/4 coverage.
- Evidence: `empty-confidence`; engine `:324`, `:381`.
- Limitation: it does not fabricate progress or say the person is on track.
- Safe next action: distinguish source availability, relevant records, freshness and support for the actual answer.

### SI-09 — Correct refusals can contain unrelated actionable sections

- Severity: Medium. Classification: confirmed full-response inconsistency.
- A weather refusal still includes grocery-receipt scenarios and deadline inference despite promising not to substitute an unrelated planning report.
- Evidence: weather output in `outputs.jsonl`.
- Safe next action: gate every response section on the resolved question, not just the direct-answer sentence.

### SI-10 — Structural validation does not catch semantic contradictions

- Severity: High. Classification: confirmed assurance gap.
- All 24 generated responses pass `validate()`, including the above failures.
- Evidence: `lib/domain/entities/si_v2_contract.dart:719`; every probe's `typedValidationPassed` field.
- The older `SIOutputValidator` likewise checks text/confidence, a small banned-phrase list and caller flags; it does not independently establish factual grounding.
- Safe next action: add semantic acceptance checks covering constraints, subject identity, time horizon and consistency across all response sections and the composed service.

## Memory, outcomes and capability boundaries

- Current messages are widget-local (`si_console_screen.dart:104`). Only the last four user turns are forwarded (`:498`). The separate `siConsoleThreadStoreProvider` has account-scoped persistence but no discovered current Console load/save connection. Older SI memory should not be counted as current durable conversational memory.
- Exact named-task follow-up succeeds. A generic laundry reference is brittle and can resolve to a goal. This is not proof that all follow-ups fail.
- Tasks have real completion events; milestones have recorded percentages. General progress questions can focus on an arbitrary goal's milestones rather than summarize relevant recorded events. One completion and one skip do not establish an overall success rate or on-track status.
- Habits and notes are not direct sources in the current SI evidence contract. Refusal is an appropriate scope boundary; it is not proof of lost memory.
- Scenarios are bounded conditional calculations, not calibrated predictions of real future outcomes.
- Documentation at `docs/developer_guides/si_console_communication_flow.md` and `docs/SI_CONSOLE_AUDIT.md` still describes old routing or broader capability. Reconcile it with current execution before using it as product evidence.

## Other connected engine findings

### ENG-01 — Projected XP differs from the actual completion award

- Severity: Medium. Classification: confirmed runtime calculation mismatch.
- Priority-five task completion projects 18 XP; `CompletionScoringEngine` awards 25 XP.
- Evidence: `trajectory-xp`; `lib/engine/trajectory/future_consequence_engine.dart:449`; `lib/domain/policies/progression_policy.dart:23`; task award at `lib/state/providers/task_provider.dart:303`; display at `lib/features/trajectory_engine/ui/trajectory_engine_screen.widgets.dart:561`.
- Safe next action: derive projected XP from the canonical reward policy and verify each displayed scenario against the actual action.

### ENG-02 — Retained overlapping commitments are considered feasible

- Severity: High. Classification: confirmed runtime planner behavior.
- Two 10–11 a.m. task blocks produce `feasible=true`, no issues and no unscheduled IDs, including through DecisionEngine's current schedule adapter.
- Evidence: `existing-overlap`, `decision-scheduled-overlap`; `lib/engine/planning/feasible_planner.dart:98`; `lib/engine/decision/decision_engine.dart:571`.
- Existing task IDs also bypass prerequisite checks. The dependency control demonstrates inconsistent enforcement; its particular scheduled fixture does not prove impossible prerequisite ordering.
- Safe next action: preserve commitments while separately evaluating conflicts and recommendation eligibility.

### ENG-03 — Trajectory explanations remain partly English-only

- Severity: Medium. Classification: source-confirmed direct-string path; device locale rendering unverified.
- Dynamic consequence summaries/assumptions have no locale input and are displayed directly.
- Evidence: `future_consequence_engine.dart:137`, `:250`, `:435`, `:465`; Trajectory widgets `:556`, `:581`, `:606`.
- Safe next action: localize structured consequence messages and verify Spanish expansion visually.

### ENG-04 — Estimated duration is stored without measured/estimated provenance

- Severity: Medium. Classification: source-confirmed data-quality concern.
- Completion derives `difficulty * 300` seconds, then stores a NeuralEntry described as an observed completed outcome, with confidence/quality 1 and that duration.
- Evidence: `lib/state/providers/task_provider.dart:298`, `:594`; `lib/engine/learning/neural_dump.dart:12`.
- Limitation: completion itself is observed. No current displayed prediction error from the estimated duration was established; current prediction handling uses explicit completion outcomes.
- Safe next action: distinguish measured duration, estimated duration and observed completion.

## Dormant/compatibility defects

These were source-reviewed, not reproduced as current Console UI behavior.

| ID | Finding | Evidence | Safe action |
|---|---|---|---|
| LEG-01 | Final stored response can receive a hash from a different regenerated message | `ai_controller.response.dart:653`, `:713`, `:726`; `si_engine_service.dart:82` | Hash the actual emitted message before reconnecting the path |
| LEG-02 | Novelty uses least-similar history, allowing an exact repeated response to score fully novel | `si_response_policy.dart:267` | Compare against the closest historical response |
| LEG-03 | AI-service energy/mood/learning inputs do not reach the core correctly; first-task selection ignores a higher-priority later task | `si_ai_service.dart:101`; `si_engine.dart:92`; `core/si_input_module.dart:9`; `core/si_core.dart:109` | Define one authoritative evidence-to-core mapping |
| LEG-04 | Legacy keyword intent order reads `Why did I skip this task?` as task retrieval; responses are English-only | `core/si_intent_module.dart:37`; `core/si_response_module.dart:174` | Retire or align with one tested bilingual intent contract |
| LEG-05 | Existing calendar block boolean validation result is ignored | `feasible_planner.dart:99`; `calendar_entry_entity.dart:27` | Check returned validity before retaining blocks |
| LEG-06 | Observed availability path invents at least 30 free minutes and reuses it daily | `future_consequence_engine.dart:384` | Repair before real observed availability is connected; current pipeline leaves it unwired |
| LEG-07 | Growth-title provider repeatedly initializes a zero state, keeping titles at Beginner | `feature_derived_providers.dart:23`; `offline/user_growth_engine.dart:47` | Repair state continuity before enabling the currently contained title |

The unused cognitive/soul layers are not evidence of live personalized cognition. Legacy prediction confidence/sample-size handling is not a calibrated prediction model. Context keys listed as evidence are not proof that those values causally influenced the decision.

## Recommended repair and acceptance order

1. Correct intent, exclusions, entity resolution and cross-section response consistency.
2. Correct local dates, due-versus-scheduled semantics and requested scenario duration.
3. Complete equivalent English/Spanish interpretation and response rendering.
4. Address feasibility, unknown information, evidence sufficiency and confidence wording.
5. Align current memory/outcome behavior with its documented capability.
6. Repair connected planner/XP/provenance defects.
7. Repair or explicitly retire dormant paths and reconcile documentation.

Acceptance must exercise the composed service and real UI with everyday English and Spanish questions, not only response structure. It must preserve read-only guidance and explicit action boundaries. No claim of production readiness, complete human UAT, or flawless behavior is made by this audit.

## Subsequent Moto evidence from the whole-app audit

After the user confirmed the Moto was free, a separate Appium walkthrough completed on the same installed version `2026083048`, Android user 11. Tapping SI's own Spanish welcome suggestion **“¿Qué debería hacer después?”** produced an English unsupported-question response despite saved task and goal evidence. This freshly confirms the Spanish entry-point failure; it does not retroactively turn the earlier interrupted attempt into a completed test.

Evidence: `test-results/app-human-use-audit-20260914/device/si-spanish-suggestion-result.json` and `si-spanish-suggestion-visual.png`. The new [whole-app human-use audit](2026-09-14-app-human-use-audit.md) contains the device journeys, 194 selected host-test passes, additional findings, preservation details, and cleanup receipt. SI findings above remain unresolved; no app repair was performed.
