# Phase 4E.1 - Controlled HLM-05 Progression Patch Boundary

## Decision

HLM-05 is **SAFE WITH CONDITIONS** to implement later. It may introduce a pure domain `ProgressionCalculator` and replace the committed inline XP-to-level calculation in `ProfileController.addXP`. It must not take ownership of auth/session, profile identity, settings, notification, or SI work.

The current Profile working file is a protected Phase 2 snapshot. Its 35 dirty hunks remain protected unless explicitly named below as an adaptable shared boundary. Git's interactive hunk staging is insufficient for Profile JSON/hydration/persistence because those hunks combine progress and non-progress semantics; implementation must construct and apply a reviewed cached patch that leaves all unrelated lines unstaged.

## Partition of all protected Profile hunks

| Hunk | Category | Reason |
| --- | --- | --- |
| PROFILE-H01 | PROTECTED-UNRELATED | Logger import is persistence diagnostics, not a calculation. |
| PROFILE-H02 | PROTECTED-UNRELATED | Auth/session import must remain user-owned. |
| PROFILE-H03 | PROTECTED-UNRELATED | Intelligence import supports existing SI refresh only. |
| PROFILE-H04 | PROTECTED-UNRELATED | `isHydrating` state is not progression truth. |
| PROFILE-H05 | PROTECTED-UNRELATED | Hydration default only. |
| PROFILE-H06 | PROTECTED-UNRELATED | Hydration `copyWith` parameter only. |
| PROFILE-H07 | PROTECTED-UNRELATED | Hydration state propagation only. |
| PROFILE-H08 | SHARED-BOUNDARY | `fromJson` jointly decodes XP/level/streak and profile identity/readiness. |
| PROFILE-H09 | SHARED-BOUNDARY | lifecycle/mutation/write queues protect persisted progression writes. |
| PROFILE-H10 | SHARED-BOUNDARY | session-aware build gates Profile hydration. |
| PROFILE-H11 | SHARED-BOUNDARY | scheduled hydration carries lifecycle/mutation context. |
| PROFILE-H12 | SHARED-BOUNDARY | storage key/channel replacement is required to preserve compatibility. |
| PROFILE-H13 | SHARED-BOUNDARY | user-scoped key and legacy-store migration surround Profile record compatibility. |
| PROFILE-H14 | SHARED-BOUNDARY | authorization gate surrounds all progression persistence. |
| PROFILE-H15 | SHARED-BOUNDARY | hydration invokes the decoder where floor migration must occur. |
| PROFILE-H16 | SHARED-BOUNDARY | serializes/persists the state where floor must survive restart. |
| PROFILE-H17 | PROTECTED-UNRELATED | write draining is session lifecycle behavior. |
| PROFILE-H18 | SHARED-BOUNDARY | mutation guard precedes the calculation in `addXP`. |
| PROFILE-H19 | SHARED-BOUNDARY | persistence call follows `addXP`; calculation can change but save timing cannot. |
| PROFILE-H20 | PROTECTED-UNRELATED | notification side effect. |
| PROFILE-H21 | PROTECTED-UNRELATED | SI refresh side effect. |
| PROFILE-H22 | PROTECTED-UNRELATED | `clearLeveledUp` authorization behavior. |
| PROFILE-H23 | PROTECTED-UNRELATED | profile identity authorization. |
| PROFILE-H24 | PROTECTED-UNRELATED | profile identity persistence. |
| PROFILE-H25 | PROTECTED-UNRELATED | onboarding/profile identity authorization. |
| PROFILE-H26 | PROTECTED-UNRELATED | onboarding/profile identity persistence. |
| PROFILE-H27 | PROTECTED-UNRELATED | sound preference authorization. |
| PROFILE-H28 | PROTECTED-UNRELATED | sound preference persistence. |
| PROFILE-H29 | HLM05-ADAPTABLE | streak guard is retained while Profile remains progression owner; no formula change is authorized. |
| PROFILE-H30 | HLM05-ADAPTABLE | streak persistence must remain compatible with new Profile progression serialization. |
| PROFILE-H31 | PROTECTED-UNRELATED | streak notification side effect. |
| PROFILE-H32 | PROTECTED-UNRELATED | streak SI refresh side effect. |
| PROFILE-H33 | HLM05-ADAPTABLE | reset must preserve existing streak semantics and shared Profile persistence. |
| PROFILE-H34 | HLM05-ADAPTABLE | reset's save/refresh composition must be retained. |
| PROFILE-H35 | HLM05-ADAPTABLE | profile-backed progression repository writes supplied XP/level/streak; it must adapt to effective-level calculation. |

There are no dirty hunks that are wholly **HLM05-REPLACEABLE**. The actual inline formula at current `addXP` lines 291-310 is committed baseline code between protected guards/save calls. HLM-05 is authorized to replace that narrow formula region only. There are no unknown hunks: the Phase 2 snapshot proves preservation identity, but not authorship intent.

## Historical invariants

1. XP is an accumulated persisted fact and must never be silently lost.
2. Policy level is deterministic from XP through `ProgressionPolicy` or its direct canonical replacement.
3. For historically migrated users, `effectiveLevel = max(policyLevel, legacyLevelFloor)`.
4. The floor must round-trip through state, JSON, persistence, hydration, and restart.
5. New users use floor `1`; they do not acquire an artificial elevated floor.
6. Existing `StreakService` semantics remain unchanged; HLM-05 centralizes neither streak award cadence nor notifications.
7. XP/level is a transparent product metric, never a measure of emotional worth, diagnosis, or authority.
8. All calculation outputs are deterministic and explainable from XP and an optional compatibility floor.

Evidence: `2d8f4ece` introduced the floor after the prior inline `(xp ~/ 50) + 1` curve could regress users; `33d11653` made the quadratic `ProgressionPolicy` curve authoritative for calculation. Current protected code still calls the policy but lacks the later floor compatibility behavior.

## Target responsibility split

`ProfileState` owns persisted `xp`, effective `level`, `streak`, `longestStreak`, and `legacyLevelFloor`. `ProgressionCalculator` owns pure policy level, effective level, XP-to-next, and level-band progress. `ProfileController` orchestrates load, calculator invocation, persistence, state exposure, and existing side effects. It is not formula authority.

`ProgressionEntity` and `UserProgress` are adapters/read models. `ProgressionRepository` remains legacy compatibility storage until a separate migration proves zero required consumers.

## Legacy-floor migration contract

For a JSON Profile record lacking `legacyLevelFloor`, historic `2d8f4ece` behavior is:

- Read stored XP and stored level.
- Initialize floor to stored level when stored level is greater than 1; otherwise initialize to 1.
- Compute effective level as `max(policyLevel(xp), floor)`.
- Persist that floor on the next Profile save and retain it through subsequent loads.
- The runtime has no automatic mechanism to increase or decrease a captured floor. It is a migration artifact, not an earned-level counter.
- If policy level exceeds floor, use policy level; if lower, use floor.
- New state starts at floor 1.
- Missing, non-numeric, or malformed optional floor follows the historic decoder's legacy fallback; malformed required fields retain the current Profile decoder's defaults. Whether a corrupted persisted JSON document should be repaired, rejected, or logged remains governed by the current Profile hydration error path and is not redefined here.

The floor's global retirement condition in history is only "when no installs predate the migration". No repository evidence defines a per-record deletion condition, migration version marker, or product decision for retirement; those are unresolved and must not be invented in HLM-05.

## Formula classification

| Formula / representation | HLM-05 classification | Boundary |
| --- | --- | --- |
| `ProgressionPolicy` XP-to-level, thresholds, fraction | CANONICAL-IN-HLM05 | delegate or move behind calculator without changing curve |
| Profile XP/effective-level update | CANONICAL-IN-HLM05 | calculator result persisted by Profile |
| `ProgressionEntity` XP/level methods | ADAPTER-TO-CANONICAL | preserve entity compatibility |
| `UserProgress` XP-to-next/fraction | ADAPTER-TO-CANONICAL | preserve UI projection |
| task/session use-case level assignments | ADAPTER-TO-CANONICAL | preserve award values and repository contract |
| Session scoring | SEPARATE-METRIC | transient quality/award input, not level truth |
| learning completion/momentum/adaptability | SEPARATE-METRIC | learning/history-derived metric |
| trajectory pressure/divergence and Momentum Engine | SEPARATE-METRIC | SI/trajectory-derived metrics |
| `ProgressionRepository` Hive record | LEGACY-DEFERRED | do not remove or migrate without proof |
| goal/milestone/sentiment scores | OUT-OF-SCOPE | not one shared progression fact |

## Exact future edit regions

| File / region | Profile hunk relationship | Future treatment |
| --- | --- | --- |
| new `lib/domain/progression/progression_calculator.dart` | none | SAFE REPLACEMENT/new pure domain type |
| `domain/policies/progression_policy.dart` level helpers | none | SAFE SURGICAL EDIT or delegate-only |
| `profile_controller.dart` `ProfileState` fields/copyWith/toJson | H04-H08 adjacent; H08 direct | SAFE SURGICAL EDIT using a manual cached patch |
| `profile_controller.dart` `fromJson` | H08 | SAFE SURGICAL EDIT; retain name/profile-ready/isHydrating behavior |
| `profile_controller.dart` `_init` / `_save` | H09-H16 | SAFE SURGICAL EDIT only if needed for floor round-trip; preserve lifecycle/key/queue behavior byte-for-byte outside target lines |
| `profile_controller.dart` `addXP` calculation lines 291-310 | between H18 and H19 | SAFE REPLACEMENT of formula only; guards, streak update, save, notification, and SI refresh unchanged |
| `profile_controller.dart` streak methods | H29-H34 | NO CHANGE except compatibility tests prove a serialization call needs the new field |
| `profile_controller.dart` `setProgressionSnapshot` | H35 | SAFE SURGICAL EDIT; normalize supplied level to calculator effective level without changing its session behavior |
| `ProgressionEntity`, `UserProgress`, ProgressionService/provider | none | SAFE ADAPTER migration |
| `CompleteTask`, `EndSession` | task use case is partial dirty; session is clean | manual isolation for task; normal staging for session |
| profile-backed repository provider | current dirty file | UNSAFE until its dirty provenance is separately isolated; avoid unless a test proves it must change |
| task/trajectory/learning/SI/Nexus UI consumers | mixed or separate metrics | NO algorithm/UI changes; use continuity tests only |

## Staging strategy

Use a manual cached patch for `profile_controller.dart`, built from the current protected snapshot. It must add only the floor state/JSON/calculator call changes while keeping every unrelated protected line in the worktree and out of the index. Verify both directions:

1. `git diff --cached` contains only HLM-05 additions/replacements.
2. `git diff` still contains H01-H07, H09-H18, H20-H28, H31-H32, and all untouched portions of shared hunks.

Use ordinary staging only for clean/new files. Use separate manual cached patches for any partial dirty producer. Do not create a baseline preservation commit.

## Required test matrix

- Calculator: policy boundary XP, large XP, deterministic repeatability, next-level and fraction.
- Legacy floor: policy below/equal/above floor; old JSON without floor; explicit floor persistence; hydration/restart round trip; new-user floor; malformed optional floor.
- Profile: `addXP` invokes calculator; Profile has no duplicate level formula; Profile persistence round trip; streak behavior unchanged.
- Cross-feature: equivalent Profile state produces the same effective level/progress through `progressionProvider`/`UserProgress`, Progression UI input, Nexus projection, Profile-backed domain progression adapter, and SI/coach read payloads where they report level.
- Compatibility: `ProgressionEntity` and `UserProgress` adapters agree; legacy `ProgressionRepository` remains readable and unchanged.

## Remaining conditions

Implementation must first preserve historical floor compatibility and manually isolate shared Profile hunks. It must not reinterpret session, learning, trajectory, momentum, or intervention metrics as XP progression. No HLM-05 production code is part of this document-only phase.

