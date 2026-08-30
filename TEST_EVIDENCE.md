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

### Phase 8 - Billing Authority And Entitlement Truth

- Checkpoint: pending local Phase 8 commit on `fix/chronospark-2040-launch-readiness-20260829`.
- Evidence boundary: source, local Windows host tests, and repository validators only. No database migration, deployment, live secret, Play Console change, purchase, credit spend, RTDN delivery, signed artifact, device journey, or human UAT occurred.

| Gate | Status | Command/evidence | Result boundary |
|---|---|---|---|
| Formatting | PASS | Dart and Deno format checks on all app/test files and six changed billing Edge files | 1,007 Dart files and all changed Edge files formatted |
| Analyzer | PASS | `flutter analyze --fatal-infos` | No issues found |
| Focused billing/paywall/cleanup suite | PASS | 9 changed Phase 8 Flutter test files | 93 passed; purchase/restore account isolation, payload validation, acknowledgement, authority refresh, UI truth, containment, and cleanup covered |
| Full Flutter suite | PASS | `flutter test --no-pub` | 1,930 passed; one expected QA-define-only test skipped; zero failures |
| QA define-only contract | PASS | `flutter test --no-pub --dart-define-from-file=tool/qa_defines.json test/config/env_mode_resolution_test.dart` | 15 passed, 0 skipped |
| Edge Function gate | PASS | `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\edge_function_gate.ps1 -RunTests` | Seven functions type-checked; 68 Deno tests passed; active authority is ordered after acknowledgement; detached recovery and subscriptions-center re-subscription contexts fail closed |
| Architecture and migration policy | PASS | `check_architecture.ps1`; `supabase_migration_policy_contract.ps1` | No boundary violations; 21 migrations passed repository replay policy |
| Secret, release, and version guards | PASS | Repository PowerShell guards | Both secret guards plus release/version checks passed; no secret values inspected or changed |
| Workflow and Maestro validators | PASS | Repository Dart validators | 11 workflows and 16 Maestro files passed |
| Disposable PostgreSQL migration/pgTAP/lint | BLOCKED_EXTERNAL | `npx --yes supabase@2.116.0 db lint --local --schema public --fail-on error` | CLI ran, but PostgreSQL at `127.0.0.1:54322` refused the connection; no `docker`, `supabase`, or `psql` command is installed. The 140-assertion Phase 8 pgTAP file was not executed; its assertion plan is checked statically |
| Deployed Supabase and Google Play lifecycle | NOT_RUN | Requires separate authorization and external environments | Source evidence does not establish deployed migrations/functions/grants, Play sandbox lifecycle, acknowledgement, RTDN, provider rechecks, signed-device behavior, or production configuration |
| Launch containment | PASS | Config/provider/action/UI tests and direct source review | Subscriptions, paid credit plans, external AI, and credit spending remain disabled |

### Phase 2 - Account And Data Integrity Checkpoint

- Code commits: `061ea18`, `51b96be`, `bc44261`
- Environment: local Windows host with Flutter `3.44.6` and Dart `3.12.2`.
- Evidence boundary: local source, host unit/widget/integration tests, SQL policy definitions, and repository validators only. Cloud sync/restore remains disabled. No migration was applied to a deployed project.

| Gate | Status | Command/evidence | Result boundary |
|---|---|---|---|
| Formatting | PASS | `dart format --output=none --set-exit-if-changed lib test integration_test` | 961 files, 0 changed |
| Analyzer | PASS | `flutter analyze --fatal-infos` | No issues found |
| Focused data-integrity suite | PASS | Backup cipher, profile race, sync, task repository, backup service, cleanup, and Supabase gateway tests | 86 passed; covers concurrent legacy-key claims, in-flight task/profile edits, exact replacement recovery, rollback, account turnover, oversized payload rejection, and stale CAS conflicts |
| Full Flutter suite | PASS | `flutter test --no-pub --reporter compact` | 1,691 passed; one expected QA-define-only test skipped |
| Timeline date fixture | PASS | Isolated `TimelineScreen projects due-date tasks with actions` test | Removed a Sunday-only next-week test failure without changing production behavior |
| Architecture guard | PASS | `powershell -NoProfile -ExecutionPolicy Bypass -File .\check_architecture.ps1` | No service-layer boundary violations |
| Secret guards | PASS | `security_secret_guard.ps1`; `secret_content_guard.ps1` | Both passed; no secret values inspected or reproduced |
| Release/version guards | PASS | `release_guard.ps1`; `version_consistency_guard.ps1` | Both passed |
| Migration policy replay | PASS | `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\supabase_migration_policy_contract.ps1` | 18 migration files passed repository policy replay |
| Staged diff hygiene | PASS | `git diff --cached --check` and exact staged inventory | No whitespace errors; 25 intended files; `android/gradle.properties` untouched |
| Disposable Supabase database and pgTAP | BLOCKED_EXTERNAL | Docker command unavailable on this host | SQL definitions and 13 pgTAP checks were reviewed but not executed against PostgreSQL |
| Deployed database/RLS verification | NOT_RUN | No production mutation authorized | Local migration evidence does not establish deployed state |
| Android/device and human recovery journeys | NOT_RUN | Reserved for later phases | Host tests do not establish device storage, process-kill, accessibility, or human-UAT behavior |

### Phase 1 - Human Trust And First Proof Checkpoint

- Code commit: `c72d50b`
- Environment: local Windows host with Flutter `3.44.6` and Dart `3.12.2`.
- Evidence boundary: source, host widget/unit tests, and local validators only. No Android/device, deployed-backend, signed-artifact, Play, or human-UAT claim.

| Gate | Status | Command/evidence | Result boundary |
|---|---|---|---|
| Formatting | PASS | `dart format --output=none --set-exit-if-changed lib test integration_test` | 960 files, 0 changed |
| Analyzer | PASS | `flutter analyze --fatal-infos` | No issues found |
| Full Flutter suite | PASS | `flutter test --no-pub --reporter json` | 1,653 visible tests passed; 265 hidden loader completions; zero failures/errors; one expected QA-define test skipped |
| QA define-only contract | PASS | `flutter test --no-pub --dart-define-from-file=tool/qa_defines.json test/config/env_mode_resolution_test.dart` | 15 passed, 0 skipped |
| Timeline integrity and source truth | PASS | Timeline repository and projected-management suites | Unknown enum values and malformed records are quarantined; original payload is preserved before explicit repair; simultaneous task/persistence failures remain visible |
| Tutorial accessibility | PASS | `test/tutorial/interactive_tutorial_overlay_test.dart` plus login/onboarding tests | 11 overlay tests cover compact/large text, semantics, disabled focus, closed-loop traversal, restoration, and accessible-navigation motion; host evidence only |
| Auth/legal/return-to | PASS | Login legal tests and real `appRouterProvider` integration | English/Spanish labels and semantics pass; Privacy/Terms pushes preserve the protected login URI on Back |
| Architecture guard | PASS | `powershell -NoProfile -ExecutionPolicy Bypass -File .\check_architecture.ps1` | No service-layer boundary violations |
| Secret guards | PASS | `security_secret_guard.ps1`; `secret_content_guard.ps1` | Both passed; no secret values inspected or reproduced |
| Release/version guards | PASS | `release_guard.ps1`; `version_consistency_guard.ps1` | Both passed |
| Workflow/Maestro validators | PASS | Repository validators | 11 workflows and 16 Maestro files validated |
| Edge Function gate | PASS | `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\edge_function_gate.ps1 -RunTests` | Six functions type-checked; 28 Deno tests passed; no deployed-backend claim |
| Android device and screen reader | NOT_RUN | Reserved for Phase 10 | Host widget evidence does not establish Android/TalkBack behavior |
| Exact-checkpoint remote CI/database gate | NOT_RUN | No remote run requested | Local PASS does not establish GitHub/deployed database evidence |

### Phase 1 - Startup Recovery Checkpoint

- Code commit: `aca2b6b`
- Evidence boundary: local host widget/unit tests and analyzer only. No device, signed artifact, production, or human UAT claim.

| Gate | Status | Command/evidence | Result boundary |
|---|---|---|---|
| Startup timeout/cancellation suite | PASS | `flutter test --no-pub test/app/startup_timeout_cancellation_test.dart` | 16 tests passed; includes discarded late results, second bounded timeout, locked recovery, zero account-boundary calls, retry readiness, and duplicate-initializer prevention |
| Analyzer | PASS | `flutter analyze --fatal-infos` | No issues found after startup repair |
| Device first-run journey | NOT_RUN | Reserved for Phase 10 | Widget evidence does not establish Android lifecycle behavior |

### Phase 0 - Unsafe Capability Containment

- Code commit: `68bc277b936a49e890a4c1d94bdc05d5a087353d`
- Environment: same local Windows toolchain documented above.
- Evidence boundary: source, host tests, and local validators only. No production deployment, signed artifact, Play, device journey, or human UAT claim.

| Gate | Status | Command/evidence | Result boundary |
|---|---|---|---|
| Formatting | PASS | `dart format --output=none --set-exit-if-changed lib test integration_test` | 955 files, 0 changed; the three baseline formatting failures were repaired mechanically |
| Analyzer | PASS | `flutter analyze --fatal-infos` | No issues found |
| Full Flutter suite | PASS | `flutter test --no-pub` | 1,605 passed in 3:57; one QA-define-only test skipped |
| QA define-only test | PASS | `flutter test --no-pub --dart-define-from-file=tool/qa_defines.json test/config/env_mode_resolution_test.dart` | 15 passed, 0 skipped |
| Containment matrix | PASS | Targeted config, sync, AI, wallet, paywall, route, settings, Profile, entitlement, and Firebase tests | Direct calls and alternate app routes fail closed; inferred identity remains hidden |
| Architecture guard | PASS | `powershell -NoProfile -ExecutionPolicy Bypass -File .\check_architecture.ps1` | No service-layer boundary violations |
| Secret guards | PASS | `security_secret_guard.ps1`; `secret_content_guard.ps1` | Both passed |
| Release/version guards | PASS | `release_guard.ps1`; `version_consistency_guard.ps1` | Both passed |
| GitHub workflow validator | PASS | `dart run tool/validate_github_workflows.dart` | 11 workflows passed |
| Maestro validator | PASS | `dart run tool/validate_maestro_flows.dart` | 16 files passed |
| Edge Function gate | PASS | `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\edge_function_gate.ps1 -RunTests` | Six functions type-checked; 30 tests passed |
| Diff hygiene | PASS | `git diff --check` and staged diff check | No whitespace errors |
| Exact-checkpoint Supabase database gate | NOT_RUN | Requires a new exact-commit CI/local database run | Baseline GitHub run does not transfer to `68bc277` |
| Exact-checkpoint full GitHub CI | NOT_RUN | No remote run requested or triggered | Local PASS is not remote CI evidence |
| Android/device/human evidence | NOT_RUN | Reserved for Phase 10 | Containment is not launch readiness |
