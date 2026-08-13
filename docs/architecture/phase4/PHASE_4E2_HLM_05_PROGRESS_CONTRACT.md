# Phase 4E.2 — HLM-05 Canonical Progress Calculation Contract

## Decision

`ProgressionCalculator` is the single pure calculation boundary for XP normalization, policy level, effective level, remaining XP, and policy-band progress. `ProgressionPolicy` remains the source of threshold and award rules.

The active `ProfileState` persists `xp`, effective `level`, `streak`, `longestStreak`, and `legacyLevelFloor`. The effective level is always `max(policyLevel(xp), legacyLevelFloor)`.

## Compatibility

On reading an older profile without `legacyLevelFloor`, a stored level above one becomes its floor; otherwise the floor is one. The floor is serialized on the next save and is never silently retired. This protects historical profiles while allowing the policy level to advance normally.

## Boundaries

HLM-05 does not redesign XP awards, streaks, session quality, learning, trajectory, momentum, intervention scoring, or UI presentation. Producers and read models delegate level arithmetic to the calculator; they retain their existing award and orchestration responsibilities.

## Verification

Focused tests cover threshold delegation, negative-XP normalization, compatibility floors, and policy-band metrics. Profile migration and read-model validation are included in the implementation review; the repository-wide test compiler is currently blocked by unrelated dirty-tree errors in `adaptive_guidance.dart`, `planner_agent.dart`, and `recommendation_agent.dart`.

## Isolation appendix

`profile_controller.dart` and `complete_task.dart` contained protected pre-existing working-tree changes. Their committed HLM-05 versions were constructed externally from the audited HEAD blobs, with only the reviewed progression changes reapplied, then written directly to the Git index by blob hash. The Profile candidate includes only calculator integration, legacy-floor state/serialization/hydration, `addXP`, and snapshot normalization. The task candidate includes only canonical XP-to-level delegation. Auth/session, identity, notification, SI, and recurring-task behavior remain excluded and unstaged. Cached diffs were reviewed before commit; the active protected working copies were never staged or replaced.

## Exact-index validation appendix

Normal isolated worktree checkout was blocked by unrelated Windows long-path archive entries. Validation instead used a short-path sparse sandbox populated from the Git index only: `lib/`, the focused progression test, package files, and tracked declared assets were exported from the staged tree. Key sandbox files were verified against their index blob hashes. An empty sandbox-only `.env` placeholder satisfied asset discovery; no real environment values were read, copied, or committed. `flutter pub get`, the five focused progression tests, and targeted analysis all passed in that exact-index sandbox.
