# Lib audit repairs — 9 September 2026

## Subsequent validation and release preparation

The final huge validation passed 2,826 Flutter cases, fatal-info analysis,
coverage gates (74.5% overall; 93.1% critical), 142 Edge tests and 349 hosted
database assertions. The separate Moto QA package passed all eleven maintained
Maestro journeys and eight canonical native cases. A ninth native scenario
passed through a package-guarded physical-phone equivalent; its original
emulator-only entry correctly refused the phone and remains unverified on its
required target. Original API 36 emulator failures remain retained.

Evidence: `test-results/final-huge-20260909/FINAL_REPORT.md` and associated
manifests. These results predate one pre-commit text-only correction restoring
the ellipsis in Creator's saving message. Fresh exact-commit CI is required for
the signed candidate. Existing Play installation and user data were preserved.
The following repair-phase statements are historical. A signed build, actual
Play upgrade, real billing/credits, 16 KB runtime and store publication are
separate evidence; no overall 100-percent correctness claim is made.

All five findings from the lib re-audit are repaired in the working tree and verified by local regression tests. This is readiness to proceed to broader validation, not a device, billing or release certification.

Base commit: `fff898f3c59299996b3b8a4275af58796bc0d20e` on `fix/aab-prebuild-cleanup-20260905`. These repairs have not been committed or built.

## Finding closure

| Finding | Repair | Verified behavior |
| --- | --- | --- |
| AUD-LIB-04 — Creator account crossing | Capture account namespace and authentication generation; check asynchronous boundaries throughout stage, confirm, undo and supporting updates. Serialize confirmed mutations with account storage operations. Bind queued actions to the review/receipt visible when clicked. | Stage, confirm and undo stop across A-to-B and A-to-B-to-A transitions. A waiting confirmation cannot apply a replaced preview; a waiting undo cannot target a different review. |
| AUD-LIB-05 — Profile decode failure overwrites progress | Track loading, ready and unavailable states; block persisted mutations after failed reads; validate legacy payloads before migration. Preserve original data in place. Add a profile error screen and retry control. | Malformed profile bytes survive name, XP, sound and streak mutation attempts. A temporary read failure preserves stored XP, level and streak, then a successful retry restores them. |
| AUD-LIB-01 — Lost concurrent rhythm edits | Read fresh stored rhythms inside the shared mutation lock before applying a change. Include Creator, repository writes, loading and reminder synchronization in the ordering used with restore operations. | Both overlapping pauses survive. Concurrent delete/rename/create operations preserve each change. Creator creation and a screen rename preserve both results. |
| AUD-LIB-02 — Reminder failure rolls back a saved rhythm later | Publish saved data before reminder work. Distinguish reminder errors from data-save errors. Provide a reminder-only retry action; do not replace readable records with an error state on reminder setup failure. | A saved pause remains saved when reminders fail and when another rhythm is subsequently renamed. The screen reports that the save succeeded and offers a reminder retry. |
| AUD-LIB-03 — Latent Notes create account crossing | Capture the owner and Timeline adapter before the save; suppress stale completion updates. Make the adapter follow its repository dependency across account changes. | Delayed creates cannot populate the next account's Notes state or Timeline projection, including A-to-B-to-A. Actual Timeline adapters write separate account histories. The repaired create method remains a latent/unwired entry point in the current app call graph. |

## Implementation locations

- [Account operation guard](../../lib/state/providers/account_operation.dart), [Creator confirmation](../../lib/state/providers/creator_handshake_provider.dart), and [supporting guidance updates](../../lib/tutorial/adaptive_guidance.dart).
- [Profile controller](../../lib/state/controllers/profile_controller.dart) and [profile recovery screen](../../lib/features/profile/ui/profile_screen.dart).
- [Rhythm notifier](../../lib/state/providers/habits_provider.dart), [habit repository](../../lib/data/repositories/habit_repository.dart), and [rhythm screen](../../lib/features/creator/ui/daily_rhythms_screen.dart).
- [Notes notifier and adapter provider](../../lib/state/providers/notes_provider.dart).
- New maintained regressions: [mutation and Notes cases](../../test/state/providers/lib_audit_mutation_regression_test.dart) and [Creator and profile cases](../../test/state/providers/creator_profile_recovery_regression_test.dart). Existing UI tests cover the recovery/retry controls.

## Final validation

| Check | Result | Evidence |
| --- | --- | --- |
| Analysis of all `lib` and the six changed/new test files | PASS — no issues, exit 0 | `test-results/lib-repairs-20260909/analyze-verified.log` |
| Formatting of all 15 changed/new Dart files | PASS — zero changes, exit 0 | `test-results/lib-repairs-20260909/format-verified.log` |
| Relevant host/widget regression suite, 20 files | PASS — **169 passed, zero failed, zero errors, zero skipped**, exit 0; terminal completion and no timeout | [Verified manifest](../../test-results/lib-repairs-20260909/verified-manifest.json), [event log](../../test-results/lib-repairs-20260909/verified.jsonl) |
| Patch whitespace check | PASS — `git diff --check -- lib test`, exit 0 | Git's CRLF normalization notices are informational. |

The final test selection covers Creator domain/provider/UI behavior, Daily Rhythm mutations and planning, occurrence recording, Notes connections and isolation, profile progression/migration/persistence/UI, goal supporting-account boundaries, backup/rollback and adaptive guidance. The manifest records the exact executable, arguments, input files, times, counts and terminal status. It was run with `dart run tool/run_flutter_tests.dart`, `--no-pub --concurrency=1`, and a 420-second timeout.

The original audit probes/logs remain unchanged as historical evidence. The maintained profile regression explicitly expects an unavailable-profile exception and then verifies the original bytes remain; it does not permit a default overwrite. Expected fault-injection error messages appear in passing tests. The verified manifest distinguishes those expected errors from failed tests.

Earlier repair iterations and diagnostic runs remain in the evidence folder. Their failures were resolved before the verified run: stale profile work now exits quietly; Creator widget fixtures now supply deterministic sensitive storage instead of waiting on an unmocked platform channel; a missing required test-fixture argument was corrected. Existing assertions were retained. The new write queue's preview-replacement case was also fixed and tested.

## Preservation and remaining work

The pre-existing changes to `LEVEL20_REPAIRS_20260908.md`, `GRAPHICS_REQUIREMENTS_20260908.md` and `supabase/.temp/cli-latest` retain their audit-start hashes. Existing artifacts were not removed or changed by this repair work. The evidence receipt records hashes for the repaired files and test evidence.

No real account or phone data was used by these synthetic tests. No commit, push, build, upload, rollout, publication, monkey run or level-20 session was performed. The final huge suite, candidate build and physical-device validation remain separate next steps; this report does not claim those have passed.
