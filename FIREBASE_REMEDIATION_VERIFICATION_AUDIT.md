# Firebase Remediation Verification Audit

## Executive Verdict

**PARTIAL_PASS_FIREBASE_RISKS_REMAIN**

The Firebase remediation mechanisms are present and `flutter analyze` plus the
focused Firebase suite pass. However, the focused tests bypass Firebase SDK
streams and Crashlytics, so they do not prove the advertised lifecycle wiring.
The full suite fails, including an `AppRoot` pump failure that cannot be proven
unrelated because `AppRoot` changed for notification and route tracking.

One out-of-scope Supabase auth regression was found during this audit:
`sendEmailVerification()` had been removed after successful sign-up. It was
restored as a minimal correction in the already-touched auth/analytics slice;
the Supabase auth-service test file passes 13/13 afterwards.

## Commands Run

| Command | Result |
| --- | --- |
| `git status --short` | Dirty mixed worktree; Firebase work is only a subset. |
| `git diff --stat` | 88 tracked files changed, plus untracked files. |
| `git diff -- pubspec.yaml pubspec.lock` | Only Firebase Auth dependency and its transitive lock entries removed. |
| `flutter pub get` | Passed. |
| `flutter analyze` | Passed with no issues. |
| `flutter test test/system/firebase/firebase_remediation_test.dart` | Passed, 4/4. |
| `flutter test test/features/auth/supabase_auth_service_test.dart` | Passed, 13/13, after restoring email verification. |
| `flutter test` | Failed; application failures and a Flutter/test-runner crash remain. |

## Claim-by-Claim Verification

| Claim | Status | Evidence and limitation |
| --- | --- | --- |
| `getInitialMessage` cold-start handling exists | VERIFIED | `FirebaseMessagingBootstrap.initialize()` awaits `messaging.getInitialMessage()` and sends it to `FirebaseNotificationOpenAdapter`. No direct SDK-path test. |
| `onMessageOpenedApp` warm/background handling exists | VERIFIED | The same initializer listens to `FirebaseMessaging.onMessageOpenedApp` and uses the same adapter. No direct SDK-path test. |
| Notification-open dedupe exists | VERIFIED | Adapter dedupes by non-empty `messageId`, otherwise by sanitized destination payload. The fallback is stable but coarse: separate ID-less notifications to the same destination are treated as duplicates for that bootstrap instance. |
| Token refresh persistence/sync exists | PARTIALLY_VERIFIED | `onTokenRefresh` invokes a handler configured by `firebaseSupabaseBridgeProvider`; authenticated users use the existing Supabase metadata bridge and unauthenticated users cache locally. The test proves only callback invocation, not secure-store or Supabase bridge effects. |
| Supabase Analytics attribution exists | VERIFIED | `authUserProvider` changes invoke `AppAnalytics.identifySupabaseUser`; only the project’s `User.id` is passed to Firebase Analytics and signed-out state passes `null`. No direct auth-stream lifecycle test. |
| Supabase Crashlytics attribution exists | VERIFIED | The same auth listener calls `FirebaseCrashlytics.setUserIdentifier(userId ?? '')` under platform/Firebase guards. No direct SDK or lifecycle test. |
| Route screen tracking exists | VERIFIED | `AppRoot` listens to `GoRouter.routerDelegate`, dedupes `matchedLocation`, and calls `trackScreen`. Routes are stable paths, not user content. No router integration test. |
| Remote Config fallback exists | VERIFIED | Firebase refresh exceptions are caught, prior/default values remain, and degraded mode is recorded. The direct test exercises an injected throw, not `fetchAndActivate()` itself. |
| `firebase_auth` removal is safe | PARTIALLY_VERIFIED | It is absent from `pubspec.yaml`, `pubspec.lock`, and generated registrants after `pub get`; no Dart `FirebaseAuth` import exists. A guarded stale `firebase_auth` target name remains in `windows/CMakeLists.txt`, and the project-owned `FirebaseAuthException` name remains misleading. |
| Focused Firebase tests exist and pass | VERIFIED | Four tests pass. They cover adapter dedupe/allowlist, token callback, Analytics override normalization/clear, and injected Remote Config failure. |
| Full `flutter test` failures are unrelated | NOT_VERIFIED | The full run has pre-existing-looking feature/golden failures and a Flutter reporter crash, but the `AppRoot` pump failure could intersect the changed route/notification listener path. Evidence is insufficient to call all failures unrelated. |

## Notification and Token Findings

- Both notification-open paths use `FirebaseNotificationOpenAdapter`, then the
  existing `NotificationScheduler.queueExternalNotificationPayload()` and
  `AppRoot` payload resolver; there is no direct `Navigator` call.
- Only the allowlisted `task`, `goal`, `timeline`, `siConsole`, and `home`
  destinations are serialized. Unknown destinations fail closed and log no
  payload contents.
- The background handler logs only `messageId`, not notification data.
- Token refresh errors are non-fatal. The existing bridge writes the token to
  secure storage first and synchronizes through `auth.updateUser` metadata; it
  adds no table, RPC, or new backend contract.

## Privacy and Attribution Findings

- New Analytics user property is only `auth_source` (`supabase` or
  `signed_out`). Screen views are matched route paths. Login and sign-up event
  parameters contain only provider/method values.
- New Crashlytics attribution is only the Supabase user ID. Existing custom
  keys are version, build, platform, OS version, device model, and physical
  device state; no user content is added by this remediation.
- Existing unrelated Analytics call sites still include stable IDs and boolean
  fields (for example `goal_id` and `has_notes`). This audit found no new task,
  note, goal, journal, or prompt text logged by the remediation.
- Collection-state diagnostics are recorded at Firebase bootstrap. In a
  production release with a disabled configured collection flag, an error is
  logged without overriding the flag.

## Test Coverage Matrix

| Risk | Coverage |
| --- | --- |
| `getInitialMessage` routes intent | no coverage |
| `onMessageOpenedApp` routes intent | no coverage |
| duplicate opens ignored | direct automated test, adapter only |
| unsupported notification payload rejected | direct automated test, adapter only |
| `onTokenRefresh` persists and syncs | indirect automated test, callback only |
| unauthenticated token cached then later synced | no coverage |
| Analytics user ID after session restore/login | indirect automated test, static override only |
| Analytics clear on logout | indirect automated test, static override only |
| screen-view emission from router | indirect automated test, static override only |
| Crashlytics ID after login/session restore | no coverage |
| Crashlytics clear on logout | no coverage |
| Remote Config fetch failure fallback | direct automated test, injected fetch failure |
| Remote Config degraded-mode diagnostic | no coverage |
| production collection diagnostics | manual-only coverage |

## Full Test Failure Classification

| Failure | Category | Firebase-related? | Recommended action |
| --- | --- | --- | --- |
| `app_boot_widget_test.dart`: `AppRoot` pump throws `StateError: Bad state: No element` | widget/bootstrap | **Unproven**; changed `AppRoot` participates | Obtain a full stack trace and isolate notification/router listener initialization before release. |
| `smart_planner_input_output_test.dart`: null assertion at line 129 | Smart Planner data/test fixture | No direct Firebase path observed | Repair fixture/context separately. |
| `widget_accessibility_semantics_test.dart`: timeline search expectation | widget behavior | No direct Firebase path observed | Investigate Timeline filtering behavior separately. |
| `widget_coverage_gain_test.dart`: missing `TOP OPPORTUNITY` | widget behavior | No direct Firebase path observed | Investigate SI Console data/render state separately. |
| `trajectory_engine_screen_golden_test.dart`: 54.92% pixel diff | golden baseline / UI drift | No direct Firebase path observed | Review visual diff and update baseline only if intended. |
| Later release/provider suites fail to load | Flutter test runner | No; follows reporter `RangeError` and missing temporary listeners | Re-run after resolving the Flutter/test runner crash; do not classify as product failures yet. |
| Flutter reporter `RangeError (start)`, then temp-listener deletion errors | tooling/infrastructure | No direct Firebase path observed | Re-run with an alternate reporter or update/repair Flutter test tooling. |

The first five application failures were also present in the prior validation
output. That history is evidence of pre-existence, not proof that the current
`AppRoot` change is uninvolved; therefore the audit does not mark the full
suite unrelated.

## Changed Files Review

This is a mixed worktree audit. The classifications below describe the current
tracked `git diff`; they do **not** attribute every edit to the Firebase pass.

### EXPECTED_FIREBASE_SCOPE

- `lib/system/firebase/firebase_bootstrap.dart`
- `lib/system/firebase/firebase_messaging_bootstrap.dart`
- `lib/core/debug/app_analytics.dart`
- `lib/data/services/remote_config_service.dart`
- `lib/app/app_root.dart`
- `lib/app/startup/app_bootstrap.dart`
- `lib/system/notifications/notification_scheduler.dart`

### EXPECTED_DEPENDENCY_SCOPE

- `pubspec.yaml`
- `pubspec.lock`
- `macos/Flutter/GeneratedPluginRegistrant.swift`
- `windows/flutter/generated_plugin_registrant.cc`
- `windows/flutter/generated_plugins.cmake`

### EXPECTED_TEST_SCOPE

- `test/system/firebase/firebase_remediation_test.dart` (untracked)

### REPORT_ONLY

- `FIREBASE_MESSAGING_ANALYTICS_FIX_REPORT.md` (untracked)
- `FIREBASE_REMEDIATION_VERIFICATION_AUDIT.md` (this report, untracked)

### QUESTIONABLE

- `lib/features/auth/screens/auth_gate.dart`: telemetry changes are in scope,
  but the diff had removed Supabase verification email. This audit restored it.
- `lib/state/providers/service_providers.dart`: token-handler binding is in
  scope, but the same diff also changes SI workspace dependencies.
- `lib/app/router/app_router.dart`: changed but not required by the chosen
  `routerDelegate` listener implementation.
- `test/release/notification_release_contract_test.dart`: notification-related,
  but not a direct test of this remediation’s runtime paths.

### OUT_OF_SCOPE

Each remaining tracked changed path is outside the Firebase remediation scope:

` .env.example`, `.gitignore`, `README.md`, `ios/Runner/Runner.entitlements`,
`lib/app/router/info_pages.dart`, `lib/app/router/route_paths.dart`,
`lib/config/env.dart`, `lib/data/di/repositories_providers.dart`,
`lib/data/local/shared_prefs_storage.dart`, `lib/data/local/task_entity_mapper.dart`,
`lib/data/remote/goals_remote_gateway.dart`, `lib/data/remote/habits_remote_gateway.dart`,
`lib/data/remote/settings_remote_gateway.dart`, `lib/data/remote/tasks_remote_gateway.dart`,
`lib/data/repositories/calendar_repository.dart`,
`lib/data/repositories/completion_event_repository.dart`,
`lib/data/repositories/goal_repository.dart`, `lib/data/repositories/habit_repository.dart`,
`lib/data/repositories/identity_repository.dart`, `lib/data/repositories/insight_repository.dart`,
`lib/data/repositories/log_repository.dart`, `lib/data/repositories/memory_repository.dart`,
`lib/data/repositories/notifications_repository.dart`,
`lib/data/repositories/progression_repository.dart`, `lib/data/repositories/project_repository.dart`,
`lib/data/repositories/routine_repository.dart`, `lib/data/repositories/session_repository.dart`,
`lib/data/repositories/si_engine_repository.dart`, `lib/data/repositories/subtask_repository.dart`,
`lib/data/repositories/task_repository.dart`, `lib/data/repositories/timeline_repository.dart`,
`lib/data/services/auth_service.dart`, `lib/data/services/backup_service.dart`,
`lib/data/services/workspace_store_service.dart`,
`lib/data/storage/adapters/goal_entity_adapter.dart`, `lib/data/storage/hive_adapters.dart`,
`lib/data/sync/sync_operation.dart`, `lib/data/sync/sync_queue_store.dart`,
`lib/domain/entities/session_entity.dart`, `lib/features/auth/application/auth_controller.dart`,
`lib/features/auth/data/datasources/supabase_auth_remote_data_source.dart`,
`lib/features/auth/data/repositories/auth_repository_impl.dart`,
`lib/features/monetization/data/repositories/ai_credit_repository.dart`,
`lib/features/monetization/presentation/screens/paywall_screen.dart`,
`lib/features/settings/ui/settings_screen.dart`, `lib/state/controllers/learning_controller.dart`,
`lib/state/controllers/prediction_controller.dart`, `lib/state/providers/habits_provider.dart`,
`lib/state/services/credit_service.dart`, `lib/state/services/offline_sync_queue_service.dart`,
`lib/state/services/preference_service.dart`, `lib/state/services/state_si_engine_service.dart`,
`lib/tutorial/mission/mission_repository.dart`, `lib/tutorial/tutorial_repository.dart`,
`supabase/.temp/cli-latest`, `supabase/.temp/gotrue-version`,
`supabase/.temp/linked-project.json`, `supabase/.temp/pooler-url`,
`supabase/.temp/postgres-version`, `supabase/.temp/project-ref`,
`supabase/.temp/rest-version`, `supabase/.temp/storage-version`,
`supabase/functions/ai-proxy/index.ts`, `supabase/functions/monetization-verify/index.ts`,
`test/coverage_expansion/storage_serialization_test.dart`,
`test/features/auth/integration/auth_integration_test.dart`,
`test/features/auth/supabase_auth_service_test.dart`, `test/features/sync/unit/sync_unit_test.dart`,
`test/release/auth_release_protection_test.dart`,
`test/release/deep_link_release_contract_test.dart`,
`test/release/p21_core_loop_route_priority_contract_test.dart`, and
`web/.well-known/apple-app-site-association`.

Untracked non-Firebase work also includes backend/Supabase migrations and
tests, Maestro flows, `node_modules/`, package files, storage/router additions,
and staging-validation assets. They were not changed by this audit and must be
reviewed independently before any release.

## Remaining Blockers

### Release Blockers

- Resolve or conclusively isolate the `AppRoot` pump failure.
- Add direct tests for the actual FCM cold/warm stream wiring and Crashlytics
  set/clear calls, or document approved device-level evidence.
- Re-run the full test suite without the Flutter reporter crash and classify
  actual product failures.

### Pre-release Manual Verification

- Firebase project/platform configuration and privacy/consent review.
- Device FCM delivery, Analytics DebugView, Crashlytics non-fatal delivery,
  and production collection diagnostics.

### Test Debt

- Real FCM initial/warm delivery, persisted-token bridge behavior, auth-stream
  Analytics/Crashlytics lifecycle, router-to-screen event, and degraded-mode
  diagnostic assertions.

### Documentation Cleanup

- Remove the stale guarded `firebase_auth` target name from
  `windows/CMakeLists.txt` when the Windows compatibility shim is next changed.
- Rename the project-owned `FirebaseAuthException` in a dedicated auth
  migration; it is not imported from Firebase Auth but is misleading.

### Safe To Defer

- Updating the prior implementation report to match this stricter audit.
- Resolving unrelated Smart Planner, Timeline, SI Console, and golden failures
  after their owning changes are isolated.

## Manual Verification Checklist

- [ ] Tap notification while app is terminated.
- [ ] Tap notification while app is backgrounded.
- [ ] Receive foreground notification.
- [ ] Refresh FCM token and verify server/local persistence.
- [ ] Login restores Analytics user ID.
- [ ] Logout clears Analytics user ID.
- [ ] Login restores Crashlytics user ID.
- [ ] Logout clears Crashlytics user ID.
- [ ] Navigate key app screens and verify `screen_view` emission.
- [ ] Simulate Remote Config fetch failure and verify fallback.
- [ ] Confirm analytics/crash collection diagnostics in production flavor.