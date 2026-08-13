# Phase 4E.0 - Protected Progression/Profile Authority Isolation

## Scope and blocker

This is evidence and preservation work only. HLM-05 is `Group C / P2: Establish a canonical progress calculation contract`, with cross-feature metric consistency tests. No production code was changed.

HLM-05 cannot safely change `lib/state/controllers/profile_controller.dart` yet. The file owns active profile progression state and its dirty regions directly cover the state shape, JSON decoding, hydration, persistence, XP/level update, and streak update paths that a canonical calculation contract must preserve.

## Phase 2 three-way evidence

| Version | SHA-256 | Size | Status |
| --- | --- | ---: | --- |
| Current baseline HEAD (`008aef90`) | `5d98e5d192c65da8ca501707eca67018a2ad4b814666aa83cb70d74d568119d8` | n/a | authoritative committed baseline |
| Current working file | `42586c7e723f7a7965540f8d5a236a554e8231204c712bbb465570829bfea0b7` | 14,314 bytes | protected dirty |
| Phase 2 snapshot | `42586c7e723f7a7965540f8d5a236a554e8231204c712bbb465570829bfea0b7` | 14,314 bytes | protected dirty snapshot |

Snapshot path: `C:\Users\keegan radetski\ChronoSparkRecovery\phase2-20260812-164222\snapshot-root\tree\lib\state\controllers\profile_controller.dart`.

The Phase 2 manifest records this path as `unstaged`, `present`, with snapshot path `tree\\lib\\state\\controllers\\profile_controller.dart` and no extra notes. Its before-state record identifies base Git blob `055769b2aad7cc222da4ed9e57ad590da4252f01`. Current working content is byte-identical to the Phase 2 snapshot. It has 35 focused dirty hunks versus current HEAD's committed file content.

## Dirty hunk inventory

Every hunk below is snapshot-preserved. `Required` identifies whether a future HLM-05 canonical calculation/persistence repair needs the region.

| ID | Current region | Classification and purpose | Known consumers / history | Required |
| --- | --- | --- | --- | --- |
| PROFILE-H01 | import line 4 | persistence diagnostics (`Logger`) | Profile save/hydration | PARTIAL |
| PROFILE-H02 | import line 11 | authentication/session boundary | `authUserProvider`, lifecycle coordinator | PARTIAL |
| PROFILE-H03 | import line 13 | profile/SI refresh dependency | coach refresh | NO |
| PROFILE-H04 | `ProfileState` line 28 | progression hydration state field | Profile consumers | PARTIAL |
| PROFILE-H05 | constructor line 40 | hydration default | Profile consumers | PARTIAL |
| PROFILE-H06 | `copyWith` line 55 | hydration state transport | Profile consumers | PARTIAL |
| PROFILE-H07 | `copyWith` line 70 | hydration state propagation | Profile consumers | PARTIAL |
| PROFILE-H08 | `fromJson` lines 85-102 | serialization, profile identity, hydration | persisted profile records | DIRECT |
| PROFILE-H09 | controller fields lines 110-114 | session/mutation/write sequencing | all profile mutation paths | DIRECT |
| PROFILE-H10 | `build` lines 118-127 | authentication/session hydration gate | app bootstrap | DIRECT |
| PROFILE-H11 | scheduled `_init` lines 129-136 | lifecycle-safe hydration | app bootstrap | DIRECT |
| PROFILE-H12 | storage fields line 140 | persistence channel replacement | profile storage | DIRECT |
| PROFILE-H13 | migration/key helpers lines 147-196 | user-scoped persistence and legacy migration | secure store/Hive | DIRECT |
| PROFILE-H14 | mutation-session gate line 198 | authentication/session write authority | all profile writes | DIRECT |
| PROFILE-H15 | `_init` lines 214-235 | hydration/error behavior | profile consumers | DIRECT |
| PROFILE-H16 | `_save` lines 237-266 | serialized persistence/write queue | profile storage | DIRECT |
| PROFILE-H17 | `cancelAndDrainWrites` lines 270-275 | session lifecycle persistence control | auth/session | NO |
| PROFILE-H18 | `addXP` guard lines 279-281 | mutation authorization | XP producer path | DIRECT |
| PROFILE-H19 | `addXP` save line 312 | persistence timing | XP producer path | DIRECT |
| PROFILE-H20 | `addXP` notification line 314 | streak notification side effect | notification layer | NO |
| PROFILE-H21 | `addXP` coach refresh line 316 | SI refresh side effect | coach/SI | NO |
| PROFILE-H22 | `clearLeveledUp` guard lines 320-322 | mutation authorization | Progression UI | PARTIAL |
| PROFILE-H23 | `updateName` guard lines 327-329 | profile identity | profile UI | NO |
| PROFILE-H24 | `updateName` save line 335 | profile identity persistence | profile UI | NO |
| PROFILE-H25 | `ensureProfile` guard lines 339-341 | profile identity | onboarding | NO |
| PROFILE-H26 | `ensureProfile` save line 350 | profile identity persistence | onboarding | NO |
| PROFILE-H27 | `toggleSound` guard lines 354-356 | preference/session | settings | NO |
| PROFILE-H28 | `toggleSound` save line 358 | preference persistence | settings | NO |
| PROFILE-H29 | `incrementStreak` guard lines 362-364 | streak mutation authorization | profile/Nexus/Progression | DIRECT |
| PROFILE-H30 | `incrementStreak` save line 387 | streak persistence | profile storage | DIRECT |
| PROFILE-H31 | `incrementStreak` notification line 389 | notification side effect | notification layer | NO |
| PROFILE-H32 | `incrementStreak` coach refresh line 391 | SI refresh side effect | coach/SI | NO |
| PROFILE-H33 | `resetStreak` guard lines 395-397 | streak mutation authorization | profile/Nexus/Progression | DIRECT |
| PROFILE-H34 | `resetStreak` save/refresh lines 399-400 | streak persistence and SI refresh | profile/SI | DIRECT |
| PROFILE-H35 | `setProgressionSnapshot` guard/side-effect queue lines 408-438 | profile-backed progression adapter persistence | domain progression use cases | DIRECT |

The snapshot establishes preservation, not authorship intent. The work is therefore classified as **B: partially coherent mixed-purpose work**: it is internally coherent user-scoped session/persistence work, but it mixes auth/session, profile identity, settings, progression, streaks, migration, and SI side effects.

## Current progression authority trace

```
XP producers (task completion, goal/timeline/coach actions, domain task/session use cases)
  -> ProfileController.addXP / setProgressionSnapshot
  -> ProfileState xp, level, streak, longestStreak
  -> ProfileState.toJson
  -> user-scoped secure profile record
  -> ProfileController._init / ProfileState.fromJson
  -> profileProvider
  -> ProgressionService -> UserProgress -> Progression screen and Nexus
  -> SI/coach/trajectory read profile and derived learning/session metrics
```

Active truth is `ProfileState` from `profileProvider`; active persistence is its user-scoped secure profile record (`profile_state_v2.<scope>`). `ProgressionService` is an adapter to the UI-only `UserProgress` read model. `domainProgressionRepositoryProvider` is also profile-backed, so domain use cases write back through `setProgressionSnapshot`.

`ProgressionRepository` persists `ProgressionEntity` under Hive key `progression_entity_v1`, but it is not the active provider path. It is retained compatibility/legacy debt, not a second persistence authority to remove in this subphase.

Transient/derived values: `SessionScore`/`SessionScoreView`, `LearningMetrics` completion rate/momentum/adaptability, trajectory pressure/divergence, and Momentum Engine scores. They are not interchangeable with persisted XP/level/streak facts.

## Historical compatibility evidence

### `legacyLevelFloor` (`2d8f4ece`)

The prior shipping formula was inline: `(xp ~/ 50) + 1`. It gave much higher levels than `ProgressionPolicy`'s quadratic curve. The migration added `legacyLevelFloor` to `ProfileState` and used:

`max(ProgressionPolicy.levelFromXp(xp), legacyLevelFloor)`.

For a pre-migration JSON record with no `legacyLevelFloor`, hydration captured the stored level as the floor when it exceeded 1; new users used floor 1. The floor was serialized, retained by `copyWith`, and kept displayed level from regressing until the policy-derived level overtook it. `isGrandfathered` exposed whether the floor was still active.

The current protected dirty file **does not contain** `legacyLevelFloor`, `levelFor`, or `isGrandfathered`; its `fromJson` directly trusts `level`, and `addXP` directly calls `ProgressionPolicy.levelFromXp`. It neither proves preservation nor safely proves intentional removal of that migration behavior.

### Inline drift correction (`33d11653`)

This earlier repair identified conflict between ProfileController's inline linear formula and `ProgressionPolicy`'s quadratic curve used by read models. It made `ProgressionPolicy` the level formula and recomputed level on load without changing XP. The current dirty `addXP` retains the policy call, so it preserves the formula correction for newly awarded XP. It does not establish the historical level-floor compatibility introduced later by `2d8f4ece`.

## Duplicate calculation inventory

| Calculation | Owner/path | Persisted? | HLM-05 scope |
| --- | --- | --- | --- |
| XP-to-level, thresholds, next-level, fraction | `domain/policies/progression_policy.dart` | no | canonical calculation candidate |
| Profile XP/level/streak update | `state/controllers/profile_controller.dart` | yes | canonical owner integration; protected direct overlap |
| Entity XP update | `domain/entities/progression_entity.dart` | via caller | adapt to canonical calculation |
| Profile UI progress metrics | `state/models/user_progress.dart` | no | adapt read model |
| Profile-to-UI projection | `state/services/progression_service.dart` | no | adapt projection |
| Profile-backed domain repository | `state/providers/domain_usecase_providers.dart` | through Profile | compatibility adapter; protected dirty file |
| Hive progression record | `data/repositories/progression_repository.dart` | yes | retain as legacy compatibility until migration proof |
| Task and session awards | `domain/usecases/complete_task.dart`, `end_session.dart` | through repository | use canonical calculation, not new authority |
| Session score | `engine/scoring/session_scoring_engine.dart` | transient | award input, not progress truth |
| Dynamic task XP | `domain/usecases/calculate_xp.dart` | no | award-policy debt; separate from level calculation unless specifically reconciled |
| Completion/momentum/adaptability | `engine/learning/learning_metrics.dart` | learning state/history | outside persisted XP contract |
| trajectory/momentum/milestone percentages | state providers | mostly derived | outside HLM-05 unless cross-feature test proves a shared XP/level inconsistency |

## Required HLM-05 regions and overlap matrix

| File / region | Role | Overlap |
| --- | --- | --- |
| `lib/domain/progression/progression_calculator.dart` (new candidate) | pure canonical calculator/value result | NONE |
| `lib/domain/policies/progression_policy.dart` | curve/award policy delegation | NONE |
| `lib/domain/entities/progression_entity.dart` | compatibility entity adapter | NONE |
| `lib/state/controllers/profile_controller.dart`: state fields, JSON, hydration, `addXP`, streak and `setProgressionSnapshot` | active truth/persistence and legacy-floor compatibility | DIRECT |
| `lib/state/services/progression_service.dart` | Profile to `UserProgress` projection | NONE |
| `lib/state/models/user_progress.dart` | derived UI metrics | NONE |
| `lib/state/providers/progression_provider.dart` | UI read provider | NONE |
| `lib/state/providers/domain_usecase_providers.dart`: profile-backed repository | compatibility write adapter | DIRECT/UNKNOWN (already dirty) |
| `lib/domain/usecases/complete_task.dart`: XP award lines 39-49 | producer | PARTIAL (unrelated recurrence dirty hunk) |
| `lib/domain/usecases/end_session.dart`: XP award lines 15-25 | producer | NONE |
| `lib/state/providers/task_provider.dart`: completion scoring/profile award | producer and transient score | PARTIAL/UNKNOWN (already dirty) |
| `lib/engine/scoring/session_scoring_engine.dart` | transient score production | NONE |
| `lib/state/providers/trajectory_provider.dart` and learning metrics | derived SI/Trajectory consumers | PARTIAL/UNKNOWN (already dirty); normally outside primary calculation contract |
| Nexus, Progression screen, SI/coach consumers | read-only consumers of Profile/Progression projection | NONE for UI files observed; do not redesign |
| `data/repositories/progression_repository.dart` | compatibility persistence | NONE; do not remove |

## Safe baseline decision

Hunk isolation is not safe for HLM-05 because Profile's required fields, decoder, hydration, persistence, `addXP`, streak, and profile-backed repository behavior directly overlap protected snapshot hunks. A preservation baseline commit is **NOT JUSTIFIED**: the file is snapshot-preserved but mixed-purpose, and the current code omits the historically required `legacyLevelFloor` migration. Committing it as intentional progression baseline would misrepresent unresolved compatibility semantics.

Controlled extraction is premature; a future scoped repair needs a user-approved decision on whether/how the legacy floor is restored or intentionally retired, followed by tests for old profile JSON, floor persistence, policy overtake, Profile/Progression/Nexus equality, and producer routing. Until then HLM-05 cannot modify protected progression work.

## Relationship to established HLM boundaries

HLM-01 intake remains upstream and is unaffected. HLM-02 typed history remains separate from current progress state. HLM-03 intervention outcomes remain user-controlled and are not progress facts. HLM-04 PlannerInput remains non-persistent and must not become a progression authority.
