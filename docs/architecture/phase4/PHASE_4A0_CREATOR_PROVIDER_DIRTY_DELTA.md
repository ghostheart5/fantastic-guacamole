# Phase 4A.0 — Protected Creator Provider Dirty Delta

## Three-way evidence

| Version | Identifier / SHA-256 |
| --- | --- |
| Authoritative committed file at `HEAD` | Git blob `a64858cf6bf705ebecf25e86b718f7c0a7564bd3`; SHA-256 `74b0fd99e7b4dec17a3693dd79cbf2bb04299a633a3a6444d0cd9c206525ca37` |
| Current working-tree file | SHA-256 `158991b48b933e5664137525f08dc43482a95a03f5a13bdaa6a16f9cf97aa464` |
| Phase 2 protected snapshot file | SHA-256 `158991b48b933e5664137525f08dc43482a95a03f5a13bdaa6a16f9cf97aa464` |

The current file and the protected Phase 2 snapshot are byte-identical.

## Protected delta: committed HEAD → current/snapshot

Two hunks, 18 additions and 3 deletions:

1. **Imports (lines 1–13): auth/session.** Replaces direct Supabase access with `auth_session_lifecycle_provider` imports.
2. **`_markFirstItemCreated` (lines 166–194): auth/session.** Captures the session boundary, validates it before and after asynchronous preferences access, and avoids state writes for stale sessions.

No creator intake-routing hunk, formatting-only hunk, or unrelated hunk was found. These hunks are protected user-owned work and must not be staged with HLM-01.

## HLM-01 boundary

HLM-01 needs only the intake interpretation region: `createEntry`, `_createRoutineEntry`, `_createNoteEntry`, `_createTaskEntry`, `_createGoal`, and the helper methods `_kindFor`, `_normalizeRequestedKind`, `_normalizeKind`, `_recurrenceFor`, `_difficultyFor`, `_energyRequiredFor`, and `_priorityFor` (currently lines 32–275).

The protected auth/session hunk is inside this broad line span only because `_markFirstItemCreated` separates the goal method from the helper methods. HLM-01 need not alter `_markFirstItemCreated`, its imports, or its direct dependencies. The actual edit regions therefore have **no direct hunk overlap**.

## Safe isolation strategy

Use patch-based, explicit hunk accounting:

1. Preserve the current working-tree delta untouched.
2. Make HLM-01 edits only in the named intake methods and helpers.
3. Stage the new domain/test/documentation files normally, but stage `creator_provider.dart` with an explicit index patch containing only HLM-01 hunks.
4. Verify `git diff --cached` excludes the import and `_markFirstItemCreated` hunks before commit.

A preservation commit is **not justified**: the delta is user-owned and should remain uncommitted until its owner chooses otherwise. HLM-01 can proceed with conditions using hunk-level staging; it does not require touching protected hunks.
