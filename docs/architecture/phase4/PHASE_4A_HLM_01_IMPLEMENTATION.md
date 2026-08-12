# Phase 4A.1 — HLM-01 Canonical Intake Aggregates

## Decision

`IntakeRequest` and `IntakeKind` in `lib/domain/intake/` are the canonical, feature-neutral intake policy. Creator collects `CreatorFormData`, adapts it to `IntakeRequest`, and invokes the existing task/goal actions. The aggregate owns aliases, mode resolution, default recurrence, normalized priority, and validation; it does not own persistence.

## Architecture and compatibility

Before this change, Creator owned normalization helpers and routed overlapping task/routine/habit/note/plan semantics itself. Afterwards, persistence remains deliberately unchanged: goals use `GoalRepository`; task-backed task, routine/habit, note, plan, and milestone records use the existing task action and `TaskRepository`. Existing serialized task and goal records therefore remain directly readable; no migration is required.

`NoteEntity.toTaskEntity` and task-backed routine/habit behavior are preserved as compatibility adapters. No duplicate representation was deleted. Phase 3’s deeper `TaskEntity`/`Task`, history, and intervention debt remains out of scope.

## Protected-hunk isolation

`creator_provider.dart` had two user-owned auth/session hunks before this work: import replacement and `_markFirstItemCreated`. They were not edited or staged. Only the non-overlapping intake-routing hunk is staged by an explicit cached patch. The cached diff was checked to exclude `auth_session_lifecycle_provider`, `AuthSessionBoundary`, `AuthSessionLifecycleCoordinator`, and `_markFirstItemCreated` changes; those remain unstaged working-tree changes.

## Evidence, files, and validation

- Phase 3 HLM-01 requires a canonical task/note/habit/routine/plan intake policy.
- Phase 4A.0 established protected-hunk boundaries.
- Branch-history review used the preserved routine/note routing commits in `backup-before-form-and-ux-phase` and `heads/backup-before-bak-cleanup-2026-08-01`; no branch was merged.
- Production files: `lib/domain/intake/intake_request.dart`, `lib/state/providers/creator_provider.dart`.
- Test: `test/domain/intake/intake_request_test.dart` covers aliases, mode routing, defaults, and invalid input.
- Bounded Flutter test/static validation timed out without a failure result; no build was run.
