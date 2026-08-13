# INSIGHTS-BASELINE-01 — Decision/Learning Compile Baseline

## Scope

Starting HEAD: `7f960d4a279a0ba10a0cbc7e72f6b5b75209b85b`.

This repair closes the eleven diagnostics recorded in
`LIFE_ROOT_05G6A_INSIGHTS_BASELINE_BLOCKERS.md` without changing either
EXEC-6 candidate, the SI pipeline, the protected lifecycle provider, or HLM-06.

## Selected compatibility groups

- `ENTITY-H01`: add snapshot-proven
  `lib/domain/entities/decision_observation_entity.dart`.
- `LEARNING-H01`: restore the richer `LearningEntity` surface and make
  `LearningState` its backward-compatible typedef.
- `DECISION-H01`: restore `TimeBlock.validate()` for the committed feasible
  planner.

The entity exactly matches the Phase 2 source-presence SHA-256
`23fda877ec5719e44bc5836bafe8f401e9b6844f08c11e054749d81b617db48f`.
The LearningEntity deserialization adds explicit map generic types only to meet
the targeted analyzer gate; this does not alter the snapshot behavior.

## Compatibility decisions

`LearningEntity` is the canonical aggregate that owns `taskAffinity` and
`List<DecisionObservationEntity> observations`. `LearningState` is an alias,
not a competing state model. Decision observations retain their immutable
fields and JSON conversion. `TimeBlock.validate()` throws `StateError` for
blank identifiers/titles or an end time that is not after start.

## Preservation

- HLM-04: the existing PlannerInput → DecisionEngine → FeasiblePlanner path is
  unchanged; `si_pipeline_provider.dart` is required-but-no-change.
- Root-03: scoped Learning migration regression passed.
- Root-05: the committed Learning write-tail and `cancelAndDrainWrites()`
  regression passed unchanged.

## Validation

The exact baseline candidate passed 17 focused tests: three compatibility tests,
one Insights graph compile/load test, five HLM-04 planner regressions, five
Root-03 regressions, and three Root-05 Learning drain/migration tests.
Targeted analysis reported zero diagnostics. The Insights provider graph loads
from committed-only baseline dependencies; no EXEC-6 production source was
used.

## EXEC-6

R05-022 and R05-023 remain atomic under G0. Their prior candidate blobs are
stale because this commit changes their dependency baseline; rebuild the
candidate from this commit before proceeding.
