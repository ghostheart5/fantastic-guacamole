# HLM-06 baseline compile unblock map

## Frozen HLM-06 candidate

- Audited HEAD: `28d7a3b72e6264b1c16fc0f95fb1aada72e3e538`
- The staged candidate is separate from all protected working-tree changes.
- The SettingsRepository index blob remains `9ce97a019926bc7f33daa887416242ca5699b46b`.

## Required compile chain

`settings_preference_provider_test` imports
`settings_preference_provider.dart`, which uses the existing
`settingsRepositoryProvider`. That provider participates in authenticated
session lifecycle management. The controller also reads `authUserProvider` to
read the correctly scoped legacy Profile record. This reaches auth/session
providers and, through existing provider/service imports, SI, decision, and
planning compilation.

## Blockers and classification

| ID | Defect | Classification | Provenance | Required before HLM-06 validation |
| --- | --- | --- | --- | --- |
| BASE-01 | `auth_service.dart` calls `FirebaseSupabaseBridgeRepository.suspendSessionWrites` / `resumeSessionWrites`, absent from the indexed bridge repository | P0-HLM06-CLOSURE | Dirty bridge repository contains the APIs | Yes |
| BASE-02 | `auth_service.dart` calls `LocalUserDataCleanupService.prepareForSignOut`, absent from indexed cleanup service | P0-HLM06-CLOSURE | Dirty cleanup service contains the API | Yes |
| BASE-03 | `decision_observation_entity.dart` is untracked while indexed learning/decision sources import it | P1-SHARED-BASELINE | Present as untracked current source | Yes for the current broad closure |
| BASE-04 | `si_pipeline_provider.dart` supplies `LearningState` where its consumer expects `LearningEntity` | P1-SHARED-BASELINE | Dirty SI provider; `LearningState` is currently a typedef of `LearningEntity`, so this is API/provider drift | Yes for broad compilation |
| BASE-05 | `feasible_planner.dart` calls `TimeBlock.validate`, absent from indexed `TimeBlock` | P2-INCIDENTAL-IMPORT | Dirty `time_block.dart`; planner is not settings ownership | No if auth/session imports are decoupled correctly; otherwise yes |
| BASE-06 | `ai_controller.response.dart` calls `refreshMonetizationRemoteState` without the required visible import/exposure | P2-INCIDENTAL-IMPORT | Dirty AI response source; helper exists in monetization providers | No if AI is removed from the auth/settings compile closure |

## Auth/session findings

The session-write and cleanup APIs are not hypothetical: current dirty files
contain their implementations, and both `auth_service.dart` and
`auth_session_lifecycle_provider.dart` call them. Their absence from the index
is an incomplete baseline contract, not an HLM-06 design problem. These files
are protected dirty integration points; any repair needs HEAD/current/snapshot
comparison and deterministic candidate construction.

## Decision, SI, planning, and AI findings

`decision_observation_entity.dart` is current untracked source, not generated
output. It is imported by `LearningEntity`, decision engine, learning
controller, task provider, and skip-task use case. The SI mismatch is shared
provider API drift. Planner and AI failures are currently incidental to the
settings/auth closure and should be decoupled rather than repaired merely to
validate HLM-06, if a later baseline repair proves the imports unnecessary.

## Dirty overlap

Protected dirty candidates: bridge repository, local cleanup service,
`time_block.dart`, `si_pipeline_provider.dart`, and AI response controller.
The decision-observation entity is untracked. None may be absorbed into the
HLM-06 commit.

## Historical evidence

Relevant history includes `008aef90` (shared PlannerInput boundary),
`e5bb4567` (production AI/backend recovery), and `491cd5a5` (production
readiness). These refs must be inspected per repair; no merge or cherry-pick is
authorized.

## Minimal repair DAG

```text
BASE-01 bridge session-write API reconciliation ─┐
                                                 ├─ BASE-03 auth/session closure compiles
BASE-02 cleanup prepare-for-sign-out reconciliation ┘
                                                        ├─ HLM-06 exact-index validation
BASE-04 decision-observation source establishment ──────┤
BASE-05 SI learning provider type reconciliation ───────┘

BASE-06 planner TimeBlock API drift     (decouple if possible)
BASE-07 AI monetization exposure drift  (decouple if possible)
```

## First repair recommendation

**FIRST-REPAIR-ID: BASE-01.** Reconcile the indexed
`FirebaseSupabaseBridgeRepository` session-write API with existing auth callers,
using a deterministic sound-only candidate and preserving all protected dirty
repository work. This is the first root blocker because auth/session lifecycle
is an unavoidable dependency of the canonical scoped Settings repository.
