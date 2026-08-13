# LIFE-ROOT-05G6A — Insights Baseline Compile Blockers

## Evidence boundary

- Audited authoritative HEAD: `6fab2dfd8620befadaec685583a74e6da4c0bec7`
- EXEC-6 candidates, HLM-06, and the protected lifecycle provider were not
  modified by this audit.
- The focused Insights invalidation test reproduces eleven baseline diagnostics.
  The identity synchronization test remains independently runnable and passes.

## Diagnostic closure

| ID | Path | Symbol / mismatch | Relationship to Insights test |
| --- | --- | --- | --- |
| EXEC6-BASE-DEP-01 | `lib/engine/decision/decision_engine.dart:2` | missing `decision_observation_entity.dart` | transitive through `insights_provider` → `domain_usecase_providers` → decision/SI graph |
| EXEC6-LEARN-DEP-01 | `lib/state/providers/si_pipeline_provider.dart:130` | `learningProvider` is `LearningState`; `DecisionEngine` requires `LearningEntity` | transitive provider/read-model mismatch |
| EXEC6-DECISION-DEP-01 | `lib/engine/decision/decision_engine.dart:109` | `LearningEntity` cannot satisfy `LearningState` expected by `TaskRanker` | transitive compatibility mismatch |
| EXEC6-DECISION-DEP-02 | `decision_engine.dart:116,117,166,167` | missing `LearningEntity.taskAffinity` | transitive learning aggregate drift |
| EXEC6-DECISION-DEP-03 | `decision_engine.dart:177,188,190` | missing `LearningEntity.observations` and `DecisionObservationType` | transitive learning/entity drift |
| EXEC6-BASE-DEP-02 | `lib/engine/planning/feasible_planner.dart:87` | missing `TimeBlock.validate()` | transitive planner compatibility mismatch |

The compiler reports eleven locations: one missing-source diagnostic, one SI
provider type diagnostic, seven DecisionEngine member/type diagnostics, and one
TimeBlock diagnostic. None originates in either EXEC-6 candidate.

## Decision observation entity

`lib/domain/entities/decision_observation_entity.dart` is untracked at HEAD.
Its current SHA-256 is
`23fda877ec5719e44bc5836bafe8f401e9b6844f08c11e054749d81b617db48f`.
The Phase 2 snapshot at
`ChronoSparkRecovery/phase2-20260812-164222/snapshot-root/tree/...` has the
same SHA-256. It defines `DecisionObservationType` and the immutable
`DecisionObservationEntity` model with JSON conversion.

There is no committed equivalent at this path or another path. The committed
`DecisionEngine` already imports it, so its absence is a partial subsystem
commit, not a stale caller. Classification: **A — required authoritative
missing source**. It is independently preservable as source presence, but not
sufficient alone to close the test graph.

Current source direct consumers are five: `DecisionEngine`, `LearningEntity`,
`LearningController`, `SkipTask`, and `task_provider`. At audited HEAD the
committed direct import is `DecisionEngine`; the other current consumers are
protected work and must not be absorbed automatically.

## Learning / decision drift

The committed planner/decision baseline (`DecisionEngine` and
`FeasiblePlanner`) expects the richer Phase 2 `LearningEntity` aggregate and a
validated `TimeBlock`. HEAD instead has the older four-field `LearningEntity`,
a separate four-field `LearningState`, and a `TimeBlock` without `validate()`.
The current protected versions are Phase-2-snapshot-identical:

| Path | HEAD blob | Current SHA-256 | Required semantic |
| --- | --- | --- | --- |
| `lib/domain/entities/learning_entity.dart` | `65e0c5ed…` | `b10bb70e…` | observations, affinity, serialization, validation |
| `lib/engine/learning/learning_state.dart` | `8f0395c3…` | `148d7318…` | compatibility typedef to `LearningEntity` |
| `lib/domain/entities/time_block.dart` | `1ce36752…` | `c8f42704…` | `validate()` required by `FeasiblePlanner` |

The existing `si_pipeline_provider.dart` DecisionEngine call is already
committed. Its protected current hunk is unrelated SI-console integration and
is **required-but-no-change** for this repair. Therefore Insights must not be
changed to accommodate the stale aggregate.

## Minimum pre-repair manifest

| Classification | Paths | Count |
| --- | --- | ---: |
| ADD-MISSING-SOURCE | `decision_observation_entity.dart` | 1 |
| MODIFY-IN-PRE-REPAIR | `learning_entity.dart`, `learning_state.dart`, `time_block.dart` | 3 |
| REQUIRED-BUT-NO-CHANGE | `insights_provider.dart`, `domain_usecase_providers.dart`, `decision_engine.dart`, `feasible_planner.dart`, `si_pipeline_provider.dart` | 5 |
| VALIDATION-ONLY | focused Insights test, protected lifecycle overlay | 2 |

Selected groups are known with no unknown semantics:

1. `INSIGHTS-BASE-ENTITY-H01` — establish snapshot-proven decision observation
   source presence.
2. `INSIGHTS-BASE-LEARNING-H01` — restore the richer learning aggregate and its
   `LearningState` compatibility alias.
3. `INSIGHTS-BASE-DECISION-H01` — restore `TimeBlock.validate()` required by
   the already-committed feasible planner.

## Preservation and next step

- HLM-04: retain the committed PlannerInput / DecisionEngine boundary; do not
  modify `si_pipeline_provider.dart`.
- Root-03: rerun scoped migration regression after the learning alias is
  restored.
- Root-05: rerun the Learning write-tail drain regression unchanged after the
  aggregate compatibility repair.

The recommended shape is **B — source-presence plus small API reconciliation**.
It is independent of EXEC-6. G0 defines R05-022 and R05-023 as one EXEC-6
group, so they remain atomic for the later EXEC-6 commit.

The pre-repair test matrix must cover DecisionObservation JSON construction and
fallback parsing; the restored LearningEntity/alias signatures; TimeBlock
validation; HLM-04 planner input compatibility; Root-03 migration; Root-05
Learning drain; and successful focused Insights invalidation compilation without
uncommitted sources.
