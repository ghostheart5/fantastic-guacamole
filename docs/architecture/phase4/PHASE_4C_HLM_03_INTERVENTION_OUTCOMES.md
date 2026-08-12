# Phase 4C — HLM-03 Canonical Intervention Outcomes

## Problem and decision

Phase 3 found no intervention-outcome aggregate or repository. The only nearby representation is `SuggestionEntity`, whose transient status mixes proposal and a small set of outcomes without persistence, intervention evidence, modification, snooze, disable, or explanation semantics.

HLM-03 establishes `Intervention` and `InterventionOutcome` in `lib/domain/interventions/`. An intervention records the proposed, explainable action: identity, trigger, reason, evidence, severity, confidence, suggested action, and optional entity context. An outcome is a separate user decision linked by `interventionId`. This prevents proposed, shown, and accepted from being treated as equivalent.

## Outcome semantics and ownership

`InterventionOutcomeStatus` has `accepted`, `modified`, `dismissed`, `snoozed`, `disabled`, and explicit `legacy`. Dismissal is neither failure nor diagnosis; snooze and modification are not rejection. Modified outcomes retain the user’s supplied action; snoozed outcomes retain `snoozedUntil`; disabled outcomes retain the supported scope.

Explanation is interaction metadata (`explanationRequestedAt`), rather than an outcome: a user can request an explanation and subsequently accept, modify, snooze, dismiss, or disable the same intervention. This preserves the control’s independent meaning.

`InterventionOutcomeRepository` is the canonical persistence authority. It stores versioned records under `intervention_outcomes_v1` through the existing `SharedPrefsStore` abstraction. The repository validates durable records, orders them by `occurredAt`, and safely preserves unknown legacy statuses as `legacy` plus `legacyStatus`.

## History relationship and compatibility

Intervention persistence owns the decision. `HistoryEvent` records a meaningful user outcome where consumers need historical facts; `InterventionOutcome.toHistoryEvent` creates typed, user-sourced outcome facts with intervention linkage and UTC occurrence time. Proposal/shown/explanation-only interactions do not automatically become history. HLM-03 does not wire a new Timeline/UI/SI producer because no existing intervention-control producer has safe, clean integration ownership.

`SuggestionEntity` is preserved as a legacy/ambiguous recommendation model. No feature-local suggestion, SI, Planner, notification, or feedback model was deleted or reinterpreted. A future adapter may construct canonical interventions only when that surface has a real user-control lifecycle.

## Evidence, isolation, and tests

Reviewed Phase 3’s `backup-before-flow-cleanup` and `rescue/chronospark-stabilization` candidates plus intervention/recommendation history; no richer outcome persistence or status model was found. No branch was merged.

Dirty `goals_provider.dart`, `task_provider.dart`, `timeline_provider.dart`, `creator_provider.dart`, and DI providers were not modified. The HLM-01 protected Creator auth/session hunks remain excluded. HLM-03 changes only new intervention files, the clean typed-history enum, the clean repository/interface, tests, and this record.

Focused tests cover intervention/outcome distinction, all five outcome states, explanation semantics, serialization, UTC timestamp behavior, unknown values, persistence ordering/round-trip, linkage, modification and snooze metadata, and typed history generation. Remaining debt: existing suggestion/feedback surfaces are not yet producer adapters, durable intervention proposals/shown state is not introduced, and no UI/settings controls are added in this phase.
