# Repairs following build 3036 testing — 2026-09-13

Implemented on `fix/aab-prebuild-cleanup-20260905`, based on `d09431b783593c504d9f9c7d15b47c6a5eea17d5`. Host checks passed before the repair commit. A new release build, installation and device rechecks remain pending. The findings in `HUGE_3036_INTERNAL_TEST_20260913.md` remain valid historical observations of build 3036.

## Application repairs

**N02 — goal target-day handling.** Timeline compares the goal's local calendar date with today's local date. A goal remains active and due today until that day ends; it becomes overdue the next day. Goal upcoming filters also use calendar days, including today and the seven-day boundary without DST duration rounding. Task deadlines retain their precise timestamp behavior. Regression coverage includes early/late target-day observations, UTC serialization of a local target, midnight rollover, yesterday/tomorrow, seven/eight-day horizons, terminal goals/tasks and actual task deadlines.

Files: `lib/features/timeline/logic/timeline_projection.dart`, `lib/domain/entities/timeline_event_entity.dart`, `test/features/timeline/timeline_projection_test.dart`.

**N01 — singular-minute wording.** Planner duration text uses one formatter for “1 minute” and plural durations, including recovery setup, total budgets and capacity-limit explanations. One-minute and five-minute plans with and without saved tasks are covered; existing arithmetic and no-write checks remain in place. User-entered text is preserved rather than rewritten.

Files: `lib/state/controllers/smart_planner_query_controller.dart`, its `.support.dart` part, `test/state/controllers/smart_planner_query_controller_test.dart`.

## Runner repairs

**Delayed SystemUI dialog during relaunch.** The relaunch focus loop can cancel at most two exact `SystemUIDialog` windows on the explicitly selected disposable emulator. Before sending BACK, it records the window dump, verifies that the focused window's own block belongs to `com.android.systemui`, and rechecks that focus has not changed. App screens, ANR dialogs, lookalike owners and physical phones are rejected. Recovery stays inside the original readiness deadline. A successful command is insufficient: two stable app-focus samples are still required, with existing new-process and event-count checks preserved. Failed or persistent dialog recovery remains a failing result.

Post-relaunch logs are now retained, hashed and scanned as well as the original stress logs. Missing post-relaunch logs or late fatal diagnostics fail the variant, so canceling an Android overlay cannot conceal an app error.

Files: `scripts/run_android_monkey_matrix.ps1`, `test/release/android_monkey_dialog_recovery_test.dart`.

**Obsolete Monkey-only seed preparation.** The new source-bound helper accepts the current already-correct Creator entry and preserves every blob. It also supports the specific legacy entry by applying the one known replacement. Unknown or ambiguous shapes fail before output is written; existing evidence is never overwritten. Verification reconstructs expected content from the immutable Git source and rejects forged provenance, altered files and extra files.

Files: `scripts/prepare_monkey_seed_flows.py`, `scripts/test_prepare_monkey_seed_flows.py`.

**Workflow wiring.** The current branch now carries the previously used reviewed precompilation/journey/Monkey workflow, with these repairs connected. Source and tooling revisions remain separately identified; tooling is checked out from the workflow revision. The seed fixtures run before emulator work. Both current and legacy seed forms receive independent verification, and the gate still requires all five variants plus post-relaunch log evidence. Guest ANR checks and fatal-error checks are retained. Use this repaired branch/revision for the next dispatch rather than the old tooling branch at `4b21abe`.

Files: `.github/workflows/maestro-runtime.yml`, `test/release/ci_release_contract_test.dart`.

## Validation

Evidence root: `test-results/repairs-3036-20260913/`.

| Check | Result |
| --- | --- |
| Focused Flutter/PowerShell fixture and workflow suite, seven files | PASS: 127 tests; `focused-tests-rerun.log` |
| Related Timeline lifecycle and fatal-scanner checks | PASS: 3 tests; `related-regressions.log` |
| Final dialog/workflow rerun after stronger delayed-dialog fixture and explicit type annotations | PASS: 30 tests, overlapping the 127 above; `final-runner-checks.log` |
| Python seed-preparation regression suite | PASS: 6 tests, covering current/legacy shapes, ambiguous input, write boundaries, wrong source and evidence tampering |
| Actual committed-source seed preparation and independent verification | PASS: transformation `none`; all source/executed hashes match; `current-source-seeds/provenance.json` |
| Replay of recorded failed-run SystemUI window | PASS with simulated ADB only; `recorded-dialog-replay.json` |
| Scoped static analysis | PASS: no issues; `analyze-rerun.log`, final changed-fixture check `final-fixture-analysis.log` |
| Dart formatting, PowerShell AST parse and scoped Git whitespace check | PASS |

There are **130 distinct passing Flutter tests and 6 Python tests** in these focused checks; repeated runs are not added to that count. The original first run retained two test failures: an input fixture supplied its own “1 minutes” typo, and the old workflow contract expected an inline runtime command. Both fixtures/contracts were corrected, preserving the behavior assertions. Static analysis initially flagged 13 dynamic-access lints in new test code; explicit types resolved all of them. Original logs are retained.

## Remaining validation boundary

This proves local implementation and host-level regression behavior. A new committed build still needs the actual Moto rechecks and complete hosted five-variant stress matrix. The recorded-dialog replay does not prove successful live emulator recovery. No changes were made to the installed Moto app, its profile/progress, subscriptions, backend or unrelated listing work. The prior microphone-stop timing uncertainty requires controlled device measurement; it was not classified as a confirmed code defect or silently marked passed.
