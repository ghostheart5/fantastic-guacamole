# ChronoSpark decision intelligence implementation

Status date: 2026-08-18

This record covers the fifteen approved implementation areas. It describes
production source and non-device verification only. Device runtime validation
remains intentionally deferred until separately authorized.

| # | Area | Implemented contract | Status |
|---|---|---|---|
| 1 | Canon | One typed registry owns the seven active features and their canonical routes. | Complete |
| 2 | Decision state | A typed snapshot answers where the user is with revisioned evidence and confidence. | Complete |
| 3 | Change continuity | Account-scoped bounded history computes material deltas and supports acknowledgement. | Complete |
| 4 | Decision integrity | A typed receipt binds the recommended action, subject, reason, consequence, evidence, confidence, and model version. | Complete |
| 5 | Nexus | One immutable decision context aggregates the six connected features, renders shared evidence, change, risk, and freshness context, models loading/partial/offline/empty/recovery, and routes every typed action exhaustively. | Source complete; device checks deferred |
| 6 | Smart Planner | Smart Planner consumes the same decision receipt, exposes evidence, and disables submission while busy. | Complete |
| 7 | Creator | Creator shows decision context and returns a typed creation receipt whose downstream impact remains visible on the first Timeline handoff. | Complete |
| 8 | SI Console | SI Console leads with inspectable decisions, protects diagnostics, prevents overlapping requests, and exposes rationale, evidence, uncertainty, processing mode, and optional query shortcuts. | Complete |
| 9 | Timeline | Timeline renders durable history separately from live intelligence, uses a cached flat lazy projection, and explains why each event matters and what unresolved work can affect. | Complete |
| 10 | Trajectory Engine | One revisioned baseline drives typed system and user-composed completion, delay, recovery, and scope interventions with accumulated risk, Timeline/goal/Progression consequences, uncertainty ranges, and an account-scoped calibration ledger. | Source complete; device checks deferred |
| 11 | Progression | Progression leads with observed capability change and leverage, while XP, levels, and streaks remain explicitly secondary activity signals. | Complete |
| 12 | Navigation | The navigation map exposes primary canon features plus support surfaces; legacy paths redirect without becoming canonical route generators. | Complete |
| 13 | Removed features | Product Focus and Session actions, UI, goal links, assets, and SI action outputs are removed. Authentication-session terminology and isolated legacy storage decoding remain technical compatibility only. | Complete |
| 14 | Accessibility and performance | Shared decision-context semantics, modal loading semantics, disabled/busy submit state, readable SI text, lazy Timeline projection, and bounded persistence are source implemented. | Complete; device checks deferred |
| 15 | Verification and governance | Canon, decision contracts, continuity recovery, decision UI, projection performance, Smart Planner, SI Console, routes, and Trajectory have automated non-device checks. | Complete; full-suite duration noted below |

## Four-question contract

Every intelligent primary surface consumes the same decision context:

1. Where are you right now?
2. What changed since the previous persisted revision?
3. What matters most next?
4. What should you do next, and why?

The answer is not stored as a fake Timeline event. Timeline remains durable
history; the current decision is visually identified as live evidence-backed state.

## Evidence and uncertainty rules

- Observed, derived, estimated, predicted, heuristic, user-provided, and
  unavailable evidence are distinct classifications.
- Actions are invalid when their subject does not match the decision subject.
- A first observation creates a baseline and never fabricates a change.
- Trajectory scenarios show assumptions, ranges, confidence, generation time,
  model version, baseline revision, accumulated risk contributors, Timeline
  displacement, goal-date intervals, and non-mutating Progression effects.
- Tracked paths are stored without task titles or free text in a bounded,
  account-scoped ledger. Calibration remains provisional until due forecasts
  are reconciled with observed outcomes.
- Corrupt local continuity and SI-thread payloads are quarantined and rebuilt
  without exposing another account's data.

## Historical verification record

The counts below are retained as evidence from the 2026-08-18 implementation
run. They are not the current branch status and must not be reused as a release
gate. Current status comes only from a commit-bound gate manifest and logs.

- `flutter analyze`: passed with no issues.
- Focused onboarding, adaptive guidance, decision intelligence, Nexus, SI
  Console, settings, and terminology contracts: 19 tests passed.
- Historical full `flutter test --no-pub`: 1,195 passed, 0 failed, 0 skipped.
- Emulator, simulator, APK/AAB build, device connection, and runtime UI
  automation: not run, as directed.

## Runtime gate reserved for later authorization

Screen-reader reading order, focus restoration, theme contrast, large-text and
small-screen behavior, device notification delivery, and sustained frame/memory
measurements require the separately authorized device phase.
