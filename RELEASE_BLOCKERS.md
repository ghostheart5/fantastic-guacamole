# ChronoSpark — Release Blockers

**Date:** 2026-08-06
**Target:** Google Play production release of `com.ghostheart5.chronospark` v4.0.0 (`versionCode` 2026071133)

A **blocker** is something that either prevents the artifact from being accepted by Google Play, exposes user data on release, or causes a release to ship broken with no signal. Everything else is tracked in the companion audits.

---

## Verdict

**4 blockers. Do not submit until BLOCK-01 through BLOCK-04 are resolved.**

| # | Severity | Blocker | Type | Effort |
|---|---|---|---|---|
| BLOCK-01 | CRITICAL | `user_daily_metrics` readable by every authenticated user | Data exposure | ~5 min |
| BLOCK-02 | HIGH | Play Billing Library 6.0.1 — below the Play minimum | Play rejection | ~10 min + verify |
| BLOCK-03 | HIGH | Release can ship with no Firebase → no crash reporting | Ships broken, silently | ~15 min |
| BLOCK-04 | HIGH | Account-deletion endpoint referenced but does not exist | Play policy | Investigate |

BLOCK-01 should be fixed **immediately and independently of the release** — it is a live data exposure affecting the running production backend right now, not something that waits for a build.

---

## BLOCK-01 · CRITICAL · Every authenticated user can read every user's metrics

**File:** `supabase/migrations/202607110002_data_policies.sql:47-52`
**Status:** **LIVE IN PRODUCTION** — this is applied to the running Supabase project, independent of any app release.

```sql
create policy "user_daily_metrics_select_authenticated"
on public.user_daily_metrics
for select
to authenticated
using (true);
```

**Why it blocks:** Any user who can sign in — including an attacker who self-registers — can read the entire table: `user_id`, `device_id`, `date`, `tasks_created`, `tasks_completed`, `momentum_peak` for every user, every day. The Supabase anon key is publishable by design and extractable from the client; RLS *is* the security boundary, and here it is absent. This is a cross-tenant data breach reportable under GDPR Art. 33 (72 hours) and analogous CCPA provisions.

Every sibling policy in the codebase gets this right (`profiles_select_own`, `purchase_bindings_select_own`), which confirms the pattern is understood and this one is an outlier.

**Fix:**

```sql
drop policy if exists "user_daily_metrics_select_authenticated" on public.user_daily_metrics;
create policy "user_daily_metrics_select_own"
on public.user_daily_metrics
for select
to authenticated
using (auth.uid() = user_id);
```

**Verify:** Sign in as user A, `select * from user_daily_metrics`, confirm only A's rows return. Repeat as user B.

**Also do:**
- Review PostgREST logs for broad `user_daily_metrics` selects to assess whether exposure occurred.
- Fix `SUP-02` in the same session — the PK omits `user_id`, and the UPDATE policy lets any user claim rows where `user_id is null`. BLOCK-01 makes that practical by handing attackers the full `device_id` list.

Full detail: `SUPABASE_AUDIT.md` SUP-01, SUP-02.

---

## BLOCK-02 · HIGH · Play Billing Library 6.0.1 is below the Play minimum

**File:** `android/app/build.gradle.kts:106`

```kotlin
implementation("com.android.billingclient:billing:6.0.1")
```

**Why it blocks:** Google Play required Billing Library 7+ for app updates from 31 August 2025 and has since raised the floor to v8. An AAB built against 6.0.1 **fails validation at upload** — a hard gate, not a warning.

There is a second, quieter problem. `in_app_purchase_android` declares its own Billing Client dependency, and Gradle resolves one version per module. An explicit `implementation` pin participates in that resolution and can force the plugin *below* the API level it was compiled against, producing `NoSuchMethodError` at purchase time **in release builds only** — where minification makes it hardest to diagnose.

**Fix — delete the line:**

```kotlin
dependencies {
    implementation("androidx.core:core-splashscreen:1.0.1")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
```

`in_app_purchase_android` resolves and ships the version it expects. The manual pin is the cause, not the cure.

**Verify:**

```bash
./gradlew :app:dependencies --configuration releaseRuntimeClasspath | grep billingclient
```

Confirm the resolved version is ≥ 7. If `in_app_purchase_android` 0.5.1 itself resolves below 7, upgrade `in_app_purchase` / `in_app_purchase_android` — that upgrade is the correct lever, never a manual pin.

**Then test a real purchase** against a Play internal-testing track using a licence-tester account, on the actual signed AAB. Confirm the flow completes and `completePurchase` is called (`google_play_paywall_repository.dart:463`) — an unacknowledged purchase is auto-refunded after 3 days.

Full detail: `GOOGLE_PLAY_AUDIT.md` GP-01.

---

## BLOCK-03 · HIGH · A release can ship with no Firebase and no crash reporting

**Files:** `android/app/build.gradle.kts:11-22` · `.github/workflows/android-release.yml:78-81`

```kotlin
if (hasGoogleServicesJson) {
    apply(plugin = "com.google.gms.google-services")
    apply(plugin = "com.google.firebase.crashlytics")
} else {
    logger.lifecycle("google-services.json was not found … Skipping Firebase Gradle plugins for this build.")
}
```

The CI step that provides the file is named **"Configure optional Firebase Android file"** and reads from `secrets.ANDROID_GOOGLE_SERVICES_JSON_BASE64` / `ANDROID_GOOGLE_SERVICES_JSON`.

**Why it blocks:** If either secret is unset, misnamed, or malformed, the build **still succeeds** and produces a signed, shippable AAB with no Crashlytics Gradle plugin (no native crash reporting, no NDK symbols, no mapping-file upload), no `google-services` resource (runtime Firebase init fails), and inert Analytics, Remote Config, and FCM. The only signal is one `logger.lifecycle` line in Gradle output.

Because `isMinifyEnabled = true`, any crash reaching you by another route is obfuscated and unreadable — the mapping upload that would have fixed that is performed by the very plugin that was skipped.

Shipping blind to crashes on a paid app is a release-stopping condition even though nothing technically fails.

**Fix — make the release path strict.** In `build.gradle.kts`:

```kotlin
val isReleaseBuild = gradle.startParameter.taskNames.any { it.contains("Release", ignoreCase = true) }
if (!hasGoogleServicesJson && isReleaseBuild) {
    error("google-services.json is required for release builds.")
}
```

And assert in CI before building:

```yaml
- name: Assert Firebase config present
  run: test -s android/app/google-services.json || { echo "::error::google-services.json missing"; exit 1; }
```

**Verify:** Build a release AAB, install it, trigger a deliberate crash, and confirm it appears in the Crashlytics console **with a deobfuscated stack trace including line numbers**. If the trace is obfuscated, fix `GP-04` (missing `-keepattributes SourceFile, LineNumberTable`) before shipping.

Full detail: `FIREBASE_AUDIT.md` FB-01.

---

## BLOCK-04 · HIGH · Account-deletion endpoint is referenced but does not exist

**Files:** `.env` (`CHRONOSPARK_ACCOUNT_DELETE_ENDPOINT`) · `.github/workflows/android-release.yml:126` · `supabase/functions/`

`.env` declares the key, CI passes it as a `--dart-define` from a secret, so the app expects an account-deletion endpoint. But `supabase/functions/` contains only **`ai-proxy`** and **`verify-receipt`**. There is no `account-delete` function in the repository.

**Why it blocks:** Google Play **requires** apps that support account creation to provide both an in-app account-deletion path and a publicly reachable web URL for deletion requests. This is a policy gate enforced at review, and non-compliance is a common rejection reason.

Two possibilities, both needing resolution before submission:

1. **The function was never written** → in-app deletion fails at runtime, and the Play requirement is unmet.
2. **It exists but is deployed outside this repository** → it works, but is unversioned, unreviewable, and undeployable from source — which is its own problem.

**Fix:**
- Confirm which case applies: `supabase functions list` against the linked project.
- If missing, implement it. It must delete the `auth.users` row (which cascades to `profiles`, `user_daily_metrics`, and `purchase_bindings` via `on delete cascade`) and remove the user's objects from the `chronospark-sync` storage bucket — cascades do not reach storage.
- If it exists elsewhere, bring the source into `supabase/functions/account-delete/`.
- Publish the web deletion URL and reference it in the Play Console listing.

**Related:** `user_daily_metrics` has no DELETE grant or policy (`SUP-13`), so users cannot selectively erase activity history. Full-account deletion works via cascade; granular deletion does not. Confirm this matches what the privacy policy promises.

Full detail: `SECURITY_AUDIT.md` SEC-08, `GOOGLE_PLAY_AUDIT.md` GP-09.

---

## Strongly recommended before release (not blockers)

These do not stop a submission, but each is cheap and materially reduces release risk.

| # | Item | Why | Ref |
|---|---|---|---|
| R-01 | Blank `CHRONOSPARK_VERBOSE_LOGS` in `.env` | Verbose logging is **active in release** — the asset sets `true` and the key is not risk-gated. PII to logcat. **~1 min fix.** | `SECURITY_AUDIT.md` SEC-01 |
| R-02 | Add `-keepattributes` to `proguard-rules.pro` | Missing `Signature`/`InnerClasses` can break `flutter_local_notifications` Gson deserialization (reminders silently never fire after reboot); missing `SourceFile`/`LineNumberTable` strips line numbers from crash traces | `GOOGLE_PLAY_AUDIT.md` GP-04 |
| R-03 | Add `flutter analyze` + `flutter test` to the release workflow | A tag on a red commit currently produces a signed release | `CI_CD_AUDIT.md` CI-02 |
| R-04 | Pin `flutter-version: 3.44.6` in all workflows | Non-reproducible builds; also stabilizes the `targetSdk` 36 guarantee, which is currently derived from whatever Flutter `stable` supplies | `CI_CD_AUDIT.md` CI-03 |
| R-05 | Remove the client-controlled `system` prompt in `ai-proxy` | Any user can repurpose the owner's Anthropic budget; per-isolate rate limiting does not effectively cap it | `SUPABASE_AUDIT.md` SUP-04, SUP-03 |
| R-06 | Add the FCM default notification channel + white-silhouette icon | Background push renders with a blank/grey square icon on a "Miscellaneous" channel | `FIREBASE_AUDIT.md` FB-02 |
| R-07 | Clean up the keystore after the build (`if: always()`) | Signing material persists in the workspace for the rest of the job | `CI_CD_AUDIT.md` CI-04 |
| R-08 | Remove or replace the CodeQL workflow | Scans only Swift in a Dart codebase — implies security coverage that does not exist | `CI_CD_AUDIT.md` CI-01 |

---

## Pre-submission verification

Run against the **actual signed release AAB**, not a debug build. Several of these findings only manifest in release (minification, `kReleaseMode` gating, ProGuard).

```bash
bundletool build-apks --bundle=app-release.aab --output=app.apks \
  --local-testing --ks=<keystore> --ks-key-alias=<alias>
bundletool install-apks --apks=app.apks
```

- [ ] **RLS** — sign in as two users; confirm neither can read the other's `user_daily_metrics` rows
- [ ] **Billing** — resolved Billing Client ≥ 7; complete a test purchase; confirm acknowledgement
- [ ] **Restore** — reinstall, restore purchases, confirm entitlement returns
- [ ] **Crashlytics** — force a crash; confirm it appears **with a deobfuscated trace and line numbers**
- [ ] **Notifications** — schedule a reminder, reboot the device, confirm it fires (exercises R-02)
- [ ] **Push** — send an FCM notification with the app backgrounded; confirm a correct icon and channel (R-06)
- [ ] **Account deletion** — exercise the in-app path end to end (BLOCK-04)
- [ ] **Logging** — `adb logcat` during normal use; confirm no PII, tokens, or AI prompt content (R-01)
- [ ] **Deep links** — `adb shell pm get-app-links com.ghostheart5.chronospark`; expect `verified` (GP-03)
- [ ] **Offline** — airplane mode; confirm graceful degradation, no crash, no hang
- [ ] **Merged manifest** — inspect `build/intermediates/merged_manifests/release/AndroidManifest.xml` for permissions contributed by plugins
- [ ] **Data Safety** — form matches actual flows: Supabase, **Anthropic (user content)**, Crashlytics, Analytics; advertising ID **not** collected

---

## Suggested sequence

**Now, independent of the release**
1. BLOCK-01 — the RLS policy. Live exposure; ~5 minutes.
2. `SUP-02` — the metrics PK and UPDATE policy, same table, same session.

**Release preparation**
3. BLOCK-02 — Billing dependency; verify resolution.
4. BLOCK-03 — Firebase assertion in Gradle and CI.
5. BLOCK-04 — resolve the account-deletion endpoint.
6. R-01, R-02 — one-line log fix, ProGuard attributes.
7. Build the AAB and run the full verification checklist.

**Post-release hardening**
8. R-03 through R-08.
9. Remove the 17 unused packages (`DEPENDENCY_AUDIT.md`) — do this in isolation, never bundled with a release.
