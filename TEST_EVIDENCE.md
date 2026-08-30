# ChronoSpark Test Evidence

All evidence is commit- and environment-specific. `BLOCKED_EXTERNAL` and `NOT_RUN` are not PASS.

## Baseline Environment

- Commit: `46494890aa5a8ddbec7c6a3c303fc9aa845651b4`
- Flutter: `3.44.6` stable
- Dart: `3.12.2`
- Node: `24.19.0`
- Deno: `2.9.4`
- GitHub CLI: `2.97.0`
- Git: `2.54.0.windows.1`
- Docker: unavailable in this host environment

## Baseline Results

| Gate | Status | Command/evidence | Result boundary |
|---|---|---|---|
| Locked dependencies | PASS | `flutter pub get` | Resolved the committed lockfile; 92 newer incompatible versions were informational |
| Formatting | FAIL | `dart format --output=none --set-exit-if-changed lib test integration_test` | Three existing test files require formatting; no output was applied |
| Local analyzer | PASS | `flutter analyze --fatal-infos` | No issues; completed in 21.0 seconds |
| Local full Flutter suite | PASS | `flutter test --no-pub` | 1,598 passed in 3:52; one QA-define-only test skipped |
| Architecture guard | PASS | `powershell -NoProfile -ExecutionPolicy Bypass -File .\check_architecture.ps1` | No service-layer boundary violations |
| Release guard | PASS | `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\release_guard.ps1` | Release and version checks passed |
| Version guard | PASS | `powershell -File .\scripts\version_consistency_guard.ps1` | Passed |
| Supabase Database Gate | PASS | GitHub Actions run `33284051711` | Passed on exact baseline SHA |
| Full app GitHub CI | NOT_RUN | Workflow does not trigger for current integration branch push | No exact-SHA remote full-app evidence |
| Android device matrix | NOT_RUN | No Phase 10 execution yet | Emulator presence is not journey evidence |
| Human UAT | BLOCKED_EXTERNAL | Requires named human participants | Codex simulation does not count |

Formatting candidates are `test/data/repositories/google_play_paywall_repository_test.dart`, `test/data/services/backup_cipher_test.dart`, and `test/data/services/sync_service_test.dart`. The skipped QA test must be run with its required define file before final candidate status. Baseline PASS entries do not carry forward after behavior changes unless rerun on the exact checkpoint.

## Phase Evidence

No launch-readiness phase has been verified yet.
