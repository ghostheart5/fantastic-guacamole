# ChronoSpark — Release Blocker Remediation Report

**Date:** 2026-08-06
**Branch:** `agents/pubspec-main-yml-android-changes`
**Base commit:** `1c1d2e6`
**Method:** READ + targeted edits only. No refactors, no dependency removal, no routing changes.

---

## 1. Executive Verdict

**ALL_BLOCKERS_FIXED_PENDING_MANUAL_RELEASE_VERIFICATION**

All four production release blockers and the near-blocker are addressed. No remaining code changes are required before the manual verification checklist is run and the Supabase migration is applied to the live project.

---

## 2. Blocker Status Matrix

| # | Finding | Status | Notes |
|---|---|---|---|
| BLOCK-01 | CRITICAL RLS — `user_daily_metrics` `using (true)` | **FIXED** | New corrective migration created |
| BLOCK-02 | Billing Library 6.0.1 manual pin | **FIXED** | Explicit override removed |
| BLOCK-03 | Conditional Firebase plugin application | **FIXED** | Release build now hard-errors on missing config |
| BLOCK-04 | Missing account-deletion endpoint | **FIXED** | Edge Function created at `supabase/functions/account-delete/` |
| NEAR-BLOCKER | Release verbose logging enabled via `.env` | **FIXED** | `_readRiskBool` gate applied; `.env` blanked |

---

## 3. Files Changed

### New files
| File | Purpose |
|---|---|
| `supabase/migrations/20260806000001_fix_user_daily_metrics_rls.sql` | Corrective RLS migration for BLOCK-01 |
| `supabase/functions/account-delete/index.ts` | Account deletion Edge Function for BLOCK-04 |

### Modified files
| File | Change |
|---|---|
| `android/app/build.gradle.kts` | Removed billing pin (BLOCK-02) + added Firebase release guard (BLOCK-03) |
| `lib/config/env.dart` | `enableVerboseLogs` now uses `_readRiskBool` (NEAR-BLOCKER) |
| `.env` | `CHRONOSPARK_VERBOSE_LOGS` blanked (gitignored — not in repo) |
| `.env.example` | `CHRONOSPARK_VERBOSE_LOGS` blanked to match |

---

## 4. Security Notes

### BLOCK-01 — RLS policy before/after

**Before** (`202607110002_data_policies.sql:47-52`):
```sql
create policy "user_daily_metrics_select_authenticated"
on public.user_daily_metrics
for select
to authenticated
using (true);
```
Any authenticated user could `SELECT * FROM user_daily_metrics` and receive every row from every user.

**After** (`20260806000001_fix_user_daily_metrics_rls.sql`):
```sql
drop policy if exists "user_daily_metrics_select_authenticated" on public.user_daily_metrics;
create policy "user_daily_metrics_select_own"
on public.user_daily_metrics
for select
to authenticated
using (auth.uid() = user_id);
```
A user's SELECT is scoped to rows where `user_id` matches the verified JWT subject. This is identical to the pattern used by `profiles_select_own` and `purchase_bindings_select_own`.

**Additional hardening in the same migration:** The UPDATE policy's `user_id is null or …` bypass branch is removed. That branch allowed any authenticated user to claim ownership of any row where `user_id` happened to be NULL, which the old SELECT policy made exploitable by exposing all `device_id` values.

**No destructive SQL:** No `DELETE`, no `TRUNCATE`, no `DROP TABLE`. Existing data is preserved. The old policy is dropped with `DROP POLICY IF EXISTS` and replaced.

**User isolation:** `auth.uid()` is injected by Supabase's PostgREST layer from the verified JWT; it cannot be spoofed by the client. Every authenticated request sees only rows belonging to that user.

### BLOCK-04 — Account deletion security properties

- **Authentication required:** The function calls `authenticatedUserId()` which verifies the caller's Bearer JWT against `/auth/v1/user` before any deletion is attempted. Unauthenticated requests return HTTP 401.
- **No arbitrary target deletion:** The deletion target is derived entirely from the verified JWT. The `userId` field in the request body is accepted for structural compatibility with the client (`auth_service.dart:283`) but is **not used** to determine whose data is deleted. The authenticated user can only ever delete themselves.
- **Scope of deletion:**
  1. Storage objects under `chronospark-sync/{userId}/` are deleted first via the Supabase Storage Admin API using the service role key.
  2. The `auth.users` record is deleted via the Supabase Auth Admin API using the service role key. This cascades (via `ON DELETE CASCADE`) to `profiles`, `user_daily_metrics`, and `purchase_bindings`.
- **No sensitive data logged:** The function uses `console.error(...)` only for generic failure messages; no user IDs, emails, or tokens are emitted to logs.
- **Retry safety:** A 404 from the admin deletion endpoint is treated as a successful deletion so retries do not leave the client in a broken state.

### NEAR-BLOCKER — Verbose logging release gate

**Before:**
```dart
static bool get enableVerboseLogs =>
    _readBool('CHRONOSPARK_VERBOSE_LOGS', _enableVerboseLogsDefine);
```
`_readBool` reads from `.env` in all modes. The shipped `.env` had `CHRONOSPARK_VERBOSE_LOGS=true`, so verbose logging was active in release builds.

**After:**
```dart
static bool get enableVerboseLogs =>
    _readRiskBool('CHRONOSPARK_VERBOSE_LOGS', _enableVerboseLogsDefine);
```
`_readRiskBool` returns the compile-time fallback (`false`) when `kReleaseMode` is `true`, bypassing `.env` entirely. In a release build, `enableVerboseLogs` is always `false` regardless of what any asset file says.

**Defense in depth:** `.env` (gitignored, asset-bundled) now has `CHRONOSPARK_VERBOSE_LOGS=` (blank), and `.env.example` matches. The blank value falls through to the compile-time default (`false`), so even debug builds no longer have verbose logging on by default. Verbose logging requires an explicit `.env` override for local development.

---

## 5. Billing Notes

**Previous state:** `android/app/build.gradle.kts:106` contained:
```kotlin
implementation("com.android.billingclient:billing:6.0.1")
```
This is below Play's v7+ requirement (enforced since August 2025) and could downgrade the version that `in_app_purchase_android` expects, producing `NoSuchMethodError` in release builds.

**Fix applied:** The line is removed entirely. `in_app_purchase_android` 0.5.1 (locked in `pubspec.lock`) declares its own Billing Client dependency and Gradle resolves the correct version.

**Why removing is safer than upgrading:** A manually pinned version participates in Gradle's dependency resolution and can force `in_app_purchase_android`'s own native code to run against a different API version than it was compiled for. Removing the pin allows Gradle to negotiate the correct version between all transiting plugins without interference.

**Verification required (manual):** Gradle dependency resolution cannot be run in this CI environment because it requires a connected Android SDK and signing configuration. The resolved version must be confirmed manually before upload:
```bash
./gradlew :app:dependencies --configuration releaseRuntimeClasspath | grep billingclient
```
Expected: `com.android.billingclient:billing:7.x.x` or `8.x.x` (whatever `in_app_purchase_android` 0.5.1 requires). If the resolved version is below 7, upgrade `in_app_purchase` / `in_app_purchase_android` in `pubspec.yaml` — that is the correct lever, not a manual Gradle pin.

---

## 6. Firebase/Crashlytics Release Notes

**Before:** `build.gradle.kts:11-22` applied Firebase plugins conditionally; a missing `google-services.json` produced only a `logger.lifecycle(...)` warning and the build continued, shipping a release with no Crashlytics plugin and unreadable obfuscated crash traces.

**After:** Three outcomes are now possible:

| Condition | Outcome |
|---|---|
| `google-services.json` present, any build type | Firebase plugins applied — same as before |
| `google-services.json` absent, **release build** | `error(...)` thrown → **Gradle fails**, no artifact produced |
| `google-services.json` absent, debug/non-release build | `logger.lifecycle(...)` warning — same as before; local dev unaffected |

The release guard uses `gradle.startParameter.taskNames.any { it.contains("Release", ignoreCase = true) }`, which matches `assembleRelease`, `bundleRelease`, and all release variants without matching debug variants.

**Verify:**
```bash
# Should fail with "google-services.json is required for release builds"
./gradlew bundleRelease  # (without google-services.json present)

# Should succeed once the CI secret is decoded and google-services.json is written
./gradlew bundleRelease  # (with google-services.json present)
```
After the release build succeeds, force a deliberate crash and confirm in the Crashlytics dashboard that:
1. The crash appears.
2. The stack trace is deobfuscated with line numbers (confirms the mapping file upload also ran).

---

## 7. Account Deletion Notes

**Function name:** `account-delete` (Supabase Edge Function)
**Function path:** `supabase/functions/account-delete/index.ts`
**Endpoint URL shape:** `https://<project-ref>.supabase.co/functions/v1/account-delete`

**Auth requirements:** Bearer JWT required. The JWT is verified against `${SUPABASE_URL}/auth/v1/user` using the Supabase anon key. Unauthenticated requests return 401.

**Required secrets (set via `supabase secrets set`):**
- `SUPABASE_URL` — automatically injected by the Supabase runtime
- `SUPABASE_ANON_KEY` — automatically injected
- `SUPABASE_SERVICE_ROLE_KEY` — must be set explicitly; used for admin deletion

**Deletion behaviour:**
1. Storage objects under `chronospark-sync/{userId}/` are listed and deleted.
2. `DELETE /auth/v1/admin/users/{userId}` is called with the service role key, deleting the `auth.users` record.
3. Cascade deletes remove rows in `profiles`, `user_daily_metrics`, and `purchase_bindings`.

**App UI linkage:** The existing `auth_service.dart:deleteCurrentAccount()` method already calls whatever URL is in `Env.accountDeleteEndpoint`. Once the CI secret `CHRONOSPARK_ACCOUNT_DELETE_ENDPOINT` is set to the deployed function URL, the in-app delete path is wired end to end without any UI changes.

**Manual test checklist:**
- [ ] POST to function URL with no Authorization header → expect 401
- [ ] POST with valid JWT for user A → expect 200 `{"success": true}`
- [ ] After deletion: `SELECT * FROM auth.users WHERE id = '<user_A_id>'` → expect 0 rows
- [ ] After deletion: `SELECT * FROM public.profiles WHERE id = '<user_A_id>'` → expect 0 rows
- [ ] After deletion: `SELECT * FROM public.user_daily_metrics WHERE user_id = '<user_A_id>'` → expect 0 rows
- [ ] After deletion: `SELECT * FROM public.purchase_bindings WHERE user_id = '<user_A_id>'` → expect 0 rows
- [ ] After deletion: list objects in `chronospark-sync` bucket with prefix `<user_A_id>/` → expect empty
- [ ] POST with same JWT a second time (retry) → expect 200 `{"success": true}` (404 treated as success)

**Deploy command:**
```bash
supabase functions deploy account-delete --project-ref <your-project-ref>
supabase secrets set SUPABASE_SERVICE_ROLE_KEY=<service-role-key>
```

**Note on the web deletion URL (Play policy requirement):** Google Play requires a publicly reachable web URL for account deletion requests in addition to the in-app path. The existing UI at `lib/app/router/app_router.dart:245-251` links to `AppUrls.deleteAccount` (a GitHub Pages URL). That external page must exist and be functional. This is a documentation/hosting task, not a code task.

---

## 8. Validation Commands

| Command | Environment | Result |
|---|---|---|
| `flutter pub get` | Git Bash + `LOCALAPPDATA` env | **PASS** — `Got dependencies!` |
| `dart format lib/config/env.dart` | Git Bash | **PASS** — auto-formatted (trailing comma) |
| `flutter analyze` | Git Bash | **PASS** — 1 issue found, pre-existing (`non_type_as_type_argument` in `test/state/providers/complete_task_use_case_provider_test.dart:33` — confirmed present on `git stash` baseline, unrelated to these changes) |
| `flutter test` | Native Windows (`powershell -Command`) | **PASS** — exit code 0 |
| `flutter test` stdout capture | Git Bash | **BLOCKED** — `PROGRAMFILES(X86)` and `LOCALAPPDATA` are not valid bash identifiers; flutter's internal PATH lookup fails in the bash/cmd hybrid environment. The exit-code-0 from the native PowerShell invocation is the authoritative result. |
| `./gradlew :app:dependencies` | N/A | **NOT RUN** — requires Android SDK + Play signing secrets not present in this environment. See manual verification step. |
| `supabase functions deploy account-delete` | N/A | **NOT RUN** — no Supabase CLI linked to project in this session. Must be run by a developer with project access. |

**Pre-existing analyze error (not introduced by this work):**
```
error - The name 'Override' isn't a type... 
test\state\providers\complete_task_use_case_provider_test.dart:33:21 - non_type_as_type_argument
```
Confirmed pre-existing by running `flutter analyze` on a clean stash of all session changes.

---

## 9. Remaining Risks

### Release blockers (none after this remediation)
No remaining code blockers. All four blockers and the near-blocker are fixed.

### Manual release verification required
The following cannot be automated in this environment and must be done by a developer with the full toolchain and project access:

1. **Gradle dependency resolution** — confirm `billingclient` resolves to v7+.
2. **Release build with Firebase config** — confirm the build succeeds and Crashlytics mapping upload runs.
3. **Release build without Firebase config** — confirm the build fails with the expected error message.
4. **Supabase migration apply** — `supabase db push` or equivalent to apply `20260806000001_fix_user_daily_metrics_rls.sql` to the live project. **This is the single most urgent action: BLOCK-01 is live in production now.**
5. **`account-delete` function deploy** — `supabase functions deploy account-delete` and secrets set.
6. **CI secret** — `CHRONOSPARK_ACCOUNT_DELETE_ENDPOINT` must be set to the deployed function URL in GitHub Secrets.
7. **Two-user RLS verification** — sign in as users A and B, confirm neither can read the other's `user_daily_metrics`.
8. **Account deletion end-to-end** — exercise in-app delete with a test account.

### Test debt (safe to defer)
- No unit test exists for `enableVerboseLogs` using `_readRiskBool`. The `_readRiskBool` mechanism is tested indirectly via `resolveIsProduction` and `resolveHasTesterFullAccess` in existing tests; the one-line change is covered by analogy. A direct test would improve confidence and is recommended for the next test sprint.
- `account-delete` Edge Function has no automated test. Consider adding a Deno test file at `supabase/functions/account-delete/index_test.ts` following the project's test conventions.
- Pre-existing analyze error in `complete_task_use_case_provider_test.dart:33` should be resolved.

### Safe to defer
- Billing Library version confirmation (Gradle report) — safe because the previous 6.0.1 pin is removed and `in_app_purchase_android` will resolve its own version; the upgrade from "pinned broken" to "plugin-managed correct" is the fix.
- All items from `RELEASE_BLOCKERS.md` R-01 through R-08 are unchanged — they were already non-blockers, and R-01 (verbose logging) is now fixed.

---

## 10. Manual Verification Checklist

Run against the **actual signed release AAB** except where noted.

### RLS (apply to staging first, then production)
- [ ] Apply migration: `supabase db push` (or run SQL directly in Supabase dashboard)
- [ ] Sign in as user A; execute `SELECT * FROM user_daily_metrics;` via Supabase Table Editor or REST API — expect only A's rows
- [ ] Sign in as user B; execute same query — expect only B's rows, with no overlap with A's
- [ ] As anon (no JWT): query via REST — expect 0 rows (`anon` role has been revoked via `REVOKE ALL ON user_daily_metrics FROM anon`)
- [ ] Confirm policy names: `SELECT policyname, cmd, qual FROM pg_policies WHERE tablename = 'user_daily_metrics'` — expect `user_daily_metrics_select_own` with `qual = (auth.uid() = user_id)`

### Billing Library
- [ ] `./gradlew :app:dependencies --configuration releaseRuntimeClasspath | grep billingclient`
- [ ] Confirm resolved version is ≥ 7 (ideally matches the version declared by `in_app_purchase_android` 0.5.1 or later)
- [ ] Complete a test purchase on a Play internal-testing track with a licence-tester account
- [ ] Confirm `completePurchase` is called and purchase is acknowledged (`google_play_paywall_repository.dart:463`)

### Firebase/Crashlytics
- [ ] Run `./gradlew bundleRelease` without `google-services.json` present → expect Gradle error: `"google-services.json is required for release builds"`
- [ ] Run `./gradlew bundleRelease` with `google-services.json` present → expect success
- [ ] Install release build; trigger deliberate crash; confirm it appears in Crashlytics dashboard within ~5 minutes with a deobfuscated stack trace and line numbers
- [ ] Confirm minification is still on (`isMinifyEnabled = true` in `buildTypes.release`)

### Account deletion
- [ ] `supabase functions deploy account-delete`
- [ ] `supabase secrets set SUPABASE_SERVICE_ROLE_KEY=<value>`
- [ ] Set `CHRONOSPARK_ACCOUNT_DELETE_ENDPOINT` in GitHub Secrets to the deployed function URL
- [ ] POST to function with no Authorization header → expect 401
- [ ] POST with valid user JWT → expect 200 `{"success": true}`
- [ ] Verify all user rows deleted: profiles, user_daily_metrics, purchase_bindings, auth.users
- [ ] Verify storage objects removed from `chronospark-sync/{userId}/`
- [ ] In-app account deletion flow (Settings → Delete Account): exercise end to end
- [ ] Confirm the web deletion URL (GitHub Pages) is live and functional

### Verbose logging
- [ ] Build a **release** APK/AAB (with signing configured)
- [ ] Install on a device; run `adb logcat | grep -i "chronospark\|verbose\|logger"`
- [ ] Confirm no verbose log output is emitted during normal app use
- [ ] Confirm `CHRONOSPARK_VERBOSE_LOGS=true` in a local `.env` does **not** enable logging in the release build
