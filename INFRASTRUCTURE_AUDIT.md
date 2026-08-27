# ChronoSpark — Infrastructure Audit

**Date:** 2026-08-06
**Commit:** `1c1d2e6` on `agents/pubspec-main-yml-android-changes`
**App:** `fantastic_guacamole` v4.0.0+2026071133 → `com.ghostheart5.chronospark`
**Toolchain:** Flutter 3.44.6 / Dart 3.12.2 (stable, 2026-07-08)
**Scope:** READ-ONLY. No files were modified.

---

## Executive summary

The infrastructure is **substantially better engineered than a codebase this size usually is.** Release signing hard-fails rather than falling back to debug; the AI proxy and receipt verifier both authenticate callers, cap payload sizes, and keep provider keys server-side; the receipt verifier makes a real Google Play Developer API call with a service-account JWT and binds purchase tokens to prevent account sharing; notifications correctly use inexact alarms to avoid the `SCHEDULE_EXACT_ALARM` Play-policy surface; `allowBackup` is off, cleartext traffic is off, and the advertising-ID permissions are explicitly stripped.

Several assumptions that would normally be findings were checked and **cleared**:

| Suspected | Actual |
|---|---|
| `.env` bundled as an asset leaks secrets | `.env` is byte-identical to `.env.example` — every value blank or a dev default. **No secret is exposed.** |
| `supabase/.temp/pooler-url` leaks a DB password | No embedded password. User + host only. |
| Release build falls back to the debug keystore | `build.gradle.kts:96` raises a hard `error()` instead. |
| Exact alarms declared without a runtime check | Code uses `inexactAllowWhileIdle`; no exact-alarm permission needed. |
| `targetSdk` below the Play requirement | Resolves to 36 via Flutter 3.44 defaults — meets the Aug-2026 bar. |

The real problems cluster in four places: **one cross-tenant RLS hole**, **a security-scanning pipeline that scans nothing**, **an obsolete Play Billing library**, and **a large volume of dependency dead weight**.

### Findings by severity

| Severity | Count | Headline |
|---|---|---|
| CRITICAL | 1 | Any authenticated user can read every user's metrics row |
| HIGH | 5 | CodeQL scans only Swift; Billing 6.0.1; unpinned Flutter in CI; no release quality gate; metrics table PK/claim flaw |
| MEDIUM | 11 | Edge-function rate limiting is per-isolate; client-controlled system prompt; no fetch timeouts; keystore not cleaned up; unverified App Links; no dependency scanning |
| LOW / INFO | 15 | 17 unused packages, dead codegen toolchain, orphan MainActivity, template workflow noise |

**Release blockers: 4.** See `RELEASE_BLOCKERS.md`.

---

## 1. System inventory

### External services

| Service | Purpose | Auth | Required at launch? | Status |
|---|---|---|---|---|
| Supabase (Postgres + Auth + Storage + Edge Functions) | Cloud sync, profiles, purchase bindings | Anon key + user JWT | No — degrades to local-only | Configured; **1 RLS hole** |
| Anthropic API (`api.anthropic.com/v1/messages`) | SI / Smart Planner generation | Server-side `x-api-key`, via edge proxy | No | Correctly proxied |
| Google Play Billing | Subscriptions | Play Billing Library | No | **Library obsolete** |
| Google Play Developer API | Server-side receipt verification | Service-account JWT (RS256) | No | Correctly implemented |
| Firebase (Core, Auth, Analytics, Crashlytics, Messaging, Remote Config) | Identity, telemetry, push, flags | `google-services.json` | No | Wired, gated by flags |
| Cloud Firestore / Firebase Storage | — | — | — | **Declared, never imported** |

### Data stores

| Store | Contents | Encrypted |
|---|---|---|
| Hive (13 files) | Tasks, sessions, SI state | Not verified encrypted |
| SharedPreferences (23 files) | Settings, flags, local state | No (by design) |
| flutter_secure_storage (3 files) | Tokens / sensitive values | Yes (Keystore-backed) |
| Supabase Storage `chronospark-sync` | User sync blobs | Private bucket, per-user prefix policies — **correct** |

The bucket policies at `supabase/migrations/202607110002_data_policies.sql:74-116` scope every operation to `split_part(name, '/', 1) = auth.uid()::text`. This is the correct pattern and is implemented correctly for select/insert/update/delete.

---

## 2. Cross-cutting findings

### INF-01 · CRITICAL · Cross-tenant read on `user_daily_metrics`

**File:** `supabase/migrations/202607110002_data_policies.sql:48-52`

```sql
create policy "user_daily_metrics_select_authenticated"
on public.user_daily_metrics
for select
to authenticated
using (true);
```

**Evidence:** The `using (true)` predicate applies no `auth.uid()` filter. Every other policy in the repo correctly scopes to the owner (`profiles_select_own` uses `auth.uid() = id`; `purchase_bindings_select_own` uses `auth.uid() = user_id`), which makes this one an outlier rather than a deliberate design.

**Impact:** Any authenticated user — including a self-registered attacker — can `select * from user_daily_metrics` and read every user's `device_id`, `user_id`, `tasks_created`, `tasks_completed`, and `momentum_peak` for every date. This is a behavioural-profile dataset covering the entire user base.

**Production risk:** Cross-tenant data breach. Directly reportable under GDPR Art. 33 / CCPA. Trivially exploitable — one anon signup plus one REST call.

**Fix:** `using (auth.uid() = user_id)`. If a genuine aggregate view is needed, expose it through a `security definer` function that returns only aggregates, with `set search_path = ''` pinned.

---

### INF-02 · HIGH · Security scanning covers none of the codebase

**File:** `.github/workflows/codeql.yml:22`

The CodeQL matrix declares exactly one language: `swift` (on `macos-latest`). This is a Flutter application — 719 Dart files under `lib/`. CodeQL has no Dart/Flutter analyzer at all, and the iOS directory is an unmodified scaffold, so the scan has essentially nothing to analyze.

**Impact:** The repository displays a passing CodeQL badge and produces SARIF uploads while providing **zero** coverage of the application. Worse, `.github/workflows/codeql.yml:91` sets `continue-on-error: true` on the SARIF upload, so even the upload failing is invisible.

**Production risk:** False assurance. Reviewers and any future compliance process will read "CodeQL: passing" as "this code has been statically analyzed for security defects." It has not.

**Fix:** Either remove the workflow (honest) or replace it with tooling that actually covers Dart — `dart analyze --fatal-infos`, `flutter analyze`, and a dependency scanner. Remove `continue-on-error: true` so failures surface.

---

### INF-03 · HIGH · Google Play Billing Library 6.0.1

**File:** `android/app/build.gradle.kts:106`

```kotlin
implementation("com.android.billingclient:billing:6.0.1")
```

**Impact (two distinct problems):**
1. Google Play required Billing Library 7+ for app updates as of August 2025 and has since moved the floor to v8. A submission built against 6.0.1 is rejected at the Play Console.
2. `in_app_purchase_android` ships its own transitively-resolved Billing Client. Pinning 6.0.1 manually can force a **downgrade** below what the plugin expects, producing runtime `NoSuchMethodError` failures in release builds specifically — the exact class of bug minification makes hardest to diagnose.

**Production risk:** Release blocker plus a latent purchase-flow crash.

**Fix:** Delete the explicit line entirely and let `in_app_purchase_android` resolve its own Billing Client version. Verify with `./gradlew :app:dependencies --configuration releaseRuntimeClasspath | grep billing`.

---

### INF-04 · HIGH · Release builds are not reproducible

**Files:** all six workflows — e.g. `android-release.yml:21`, `main.yml:27`, `dart.yml:26`

Every workflow specifies `channel: stable` with **no** `flutter-version`. `android-release.yml` and `dart.yml` correctly pin the *action* to a commit SHA (`1a449444c387…`) — good supply-chain hygiene — but then let the SDK float.

**Impact:** Two runs of the same tag, weeks apart, compile against different Flutter and Dart SDKs. A stable-channel release can change `targetSdk` defaults (the very mechanism this project relies on to reach 36), Gradle requirements, and plugin behaviour. A rebuild-to-reproduce of a shipped artifact is impossible.

**Production risk:** A release that built and passed last month may fail or behave differently today, with no changed commit to explain it.

**Fix:** Pin `flutter-version: 3.44.6` in every workflow, and add a `.fvmrc` or `.tool-versions` so local builds match.

---

### INF-05 · HIGH · Metrics table primary key omits the owner

**File:** `supabase/migrations/202607110002_data_policies.sql:1-11, 61-67`

```sql
primary key (device_id, date)
...
using (user_id is null or auth.uid() = user_id)
```

Two compounding flaws:
1. The PK is `(device_id, date)` with no `user_id`. `device_id` is client-supplied. Two users on the same `device_id` collide, and a malicious client can pick another user's `device_id` to occupy their PK slot and deny them writes.
2. The UPDATE policy's `user_id is null or …` branch lets any authenticated user claim any orphaned row (`with check` then stamps it to themselves).

INF-01 makes both practical: the `using (true)` SELECT lets an attacker enumerate every `device_id` first.

**Fix:** `primary key (user_id, device_id, date)`; make `user_id` `not null`; drop the `user_id is null` branch from the UPDATE policy.

---

### INF-06 · MEDIUM · Edge-function rate limiting does not hold

**Files:** `supabase/functions/ai-proxy/index.ts:11,33-40` · `supabase/functions/verify-receipt/index.ts:18,40-47`

```ts
const requestWindows = new Map<string, number[]>();
```

Both functions rate-limit using a module-level in-memory `Map`. Supabase Edge Functions are stateless and horizontally scaled across isolates; each isolate holds its own `Map`, and every cold start resets it.

**Impact:** The advertised limits (20/min for AI, 10/min for receipts) are best-effort per-isolate, not per-user. An attacker distributing requests across isolates multiplies their effective quota. Separately, `requestWindows` is never evicted — user IDs accumulate for the isolate's lifetime, a slow memory leak.

**Production risk:** On the AI proxy this is a direct spend risk — the ceiling on the owner's Anthropic bill is weaker than it appears.

**Fix:** Move the counter to Postgres (a `rate_limits` table with a windowed upsert) or Upstash Redis. At minimum, evict empty entries.

---

### INF-07 · MEDIUM · Client controls the AI system prompt

**File:** `supabase/functions/ai-proxy/index.ts:94, 132`

```ts
const { ..., system, maxTokens = MAX_TOKENS } = body;
...
if (system) anthropicBody.system = system;
```

The `system` field is taken from the request body and forwarded to Anthropic unvalidated. Any authenticated user can supply an arbitrary system prompt.

**Impact:** The proxy becomes a general-purpose LLM billed to the app owner. A user can repurpose it for unrelated work — the app's own guardrails, persona, and output-shape constraints are all overridable. Note the model itself is *not* client-overridable (line 128 hardcodes `DEFAULT_MODEL`), which is the right call and makes the `system` passthrough the inconsistent one.

**Fix:** Drop `system` from `ProxyRequest`. Compose the system prompt server-side from a fixed template plus a small allowlisted parameter set.

---

### INF-08 · MEDIUM · No timeout on upstream calls

**Files:** `ai-proxy/index.ts:134` · `verify-receipt/index.ts:155, 217`

No `AbortSignal.timeout()` on any outbound `fetch` — to Anthropic, to Google's OAuth endpoint, or to the Play Developer API. A slow upstream holds the function until the platform's own timeout fires, consuming an invocation slot.

**Fix:** `fetch(url, { signal: AbortSignal.timeout(30_000) })` and return 504 on `TimeoutError`.

---

### INF-09 · LOW · `purchase_bindings` race causes a spurious denial, not a double-bind

**Files:** `verify-receipt/index.ts:64-92` · `202607050001_purchase_bindings.sql:2`

`bindPurchaseToken` does a read-then-insert with no transaction, so two concurrent requests for the same `purchaseToken` can both pass the lookup and both attempt an insert. **The database prevents the dangerous outcome:**

```sql
token_hash text primary key,
```

The primary key on `token_hash` means the second insert fails, `inserted.ok` is false, and `bound` is false — so `valid: valid && bound` **denies** entitlement rather than granting a duplicate binding. The anti-sharing control holds.

**Impact:** The losing request returns `{valid: false, error: "purchase binding failed"}` to a legitimate purchaser. A retry succeeds, because the lookup then finds their own binding and returns true. Transient, self-healing, user-visible as a one-off purchase failure.

**Fix (optional):** Replace the read-then-insert with a single `on conflict (token_hash) do nothing` upsert followed by a read-back, so a race resolves to the correct answer on the first attempt.

---

### INF-10 · MEDIUM · Deep links are declared verified but cannot verify

**Files:** `AndroidManifest.xml:50-76` · `.env` (`CHRONOSPARK_ANDROID_SHA256_CERT`)

Three `<intent-filter android:autoVerify="true">` blocks claim `ghostheart5.github.io`, `chronospark.app`, and `www.chronospark.app`. App Links verification requires an `assetlinks.json` at each domain containing the release certificate SHA-256. `CHRONOSPARK_ANDROID_SHA256_CERT` is blank, and `scripts/generate_well_known.dart` (which would generate it) has no CI invocation.

**Impact:** Verification fails silently. Android falls back to the app-chooser dialog instead of opening links directly — degraded UX with no error anywhere.

**Fix:** Populate the cert fingerprint, generate and host `assetlinks.json` at `/.well-known/` on each domain, and confirm with `adb shell pm get-app-links com.ghostheart5.chronospark`.

---

### INF-11 · MEDIUM · No automated dependency scanning

No `.github/dependabot.yml`, no Renovate config, no `osv-scanner`. With 50 direct and hundreds of transitive packages, CVE disclosures reach this project only if someone reads the news.

**Fix:** Add `.github/dependabot.yml` with a `pub` ecosystem entry and a `github-actions` entry.

---

### INF-12 · MEDIUM · Release workflow has no quality gate

**File:** `.github/workflows/android-release.yml`

Step list: checkout → Flutter → deps → secret guard → keystore → key.properties → fingerprint verify → Firebase config → validate prod config → **build AAB** → artifact → GitHub Release. There is no `flutter test` and no `flutter analyze`.

**Impact:** A commit that fails all 136 tests still produces a signed, uploadable AAB. The `dart.yml` workflow does run tests, but on a different trigger — nothing blocks the release path on its result.

**Fix:** Add `flutter analyze --fatal-infos` and `flutter test` before the build step, or gate the release job on the CI workflow's conclusion.

---

## 3. Configuration state

`.env` and `.env.example` are **byte-identical**. Every value is blank or a dev default:

```
CHRONOSPARK_SUPABASE_URL          = <empty>
CHRONOSPARK_SUPABASE_ANON_KEY     = <empty>
CHRONOSPARK_AI_PROXY_ENDPOINT     = <empty>
CHRONOSPARK_RECEIPT_VERIFY_ENDPOINT = <empty>
CHRONOSPARK_ENABLE_CLOUD_SYNC     = false
CHRONOSPARK_ENABLE_ANALYTICS      = false
CHRONOSPARK_ENABLE_CRASH_REPORTING= false
CHRONOSPARK_APP_FLAVOR            = dev
CHRONOSPARK_ENFORCE_PROD_READINESS= false
```

This is **correct for the repository** — no secret is committed, and CI supplies real values via `--dart-define` (`android-release.yml:118-127`).

Two mechanisms make the asset-bundled `.env` far safer than the pattern usually is:

1. **Risk-bearing keys ignore `.env` entirely in release builds.** `lib/config/env.dart:411-425` routes `APP_FLAVOR`, `ENABLE_MOCK_LOGIN`, `ENABLE_MOCK_MODE`, `PAYWALL_DISABLED`, and `ENABLE_TESTER_FULL_ACCESS` through `_readRiskBool`/`_readRiskString`, which return the compile-time value when `kReleaseMode` is true. Repackaging the APK with a modified `.env` cannot enable mock login or disable the paywall.
2. **Blank values fall through to the `--dart-define`** (`env.dart:367`), and `_appFlavorDefine` defaults to `'prod'` (line 18) — so even a release build with no defines at all resolves to the production flavor.

**One key was left out of that protection.** `CHRONOSPARK_VERBOSE_LOGS` uses the non-risk-gated `_readBool` (`env.dart:115`), is set to a non-blank `true` in the shipped asset, and is not overridden by any CI dart-define — so **verbose logging is active in release builds**. See `SECURITY_AUDIT.md` SEC-01.

See `SECURITY_AUDIT.md` for the full configuration and secrets analysis.

---

## 4. What is genuinely well built

Worth recording so it is not accidentally "fixed":

- **`android/app/build.gradle.kts:91-99`** — release signing raises `error()` when `key.properties` is absent or contains `YOUR_` placeholders. No silent debug-key fallback.
- **`ai-proxy/index.ts:22-31`** — JWT verified against `/auth/v1/user` before any upstream call; provider key never leaves the server; 8,000-char prompt cap and 8-message history cap; errors return generic strings with no upstream leakage.
- **`verify-receipt/index.ts:113-164`** — a correct RS256 service-account JWT assertion flow against `androidpublisher`, using `subscriptionsv2`. Product IDs are allowlisted. `valid: valid && bound` means a binding failure denies entitlement rather than granting it.
- **`google_play_paywall_repository.dart:463,471`** — `completePurchase` is called for both completed and `pendingCompletePurchase` states. Unacknowledged purchases auto-refund after 3 days; this correctly avoids that revenue loss.
- **`notification_scheduler.dart:223,274`** — `inexactAllowWhileIdle` sidesteps `SCHEDULE_EXACT_ALARM` entirely, avoiding a Play policy declaration the app would not qualify for. `tz.initializeTimeZones()` and `setLocalLocation` run in `app_bootstrap.dart:313,410-412` before any scheduling.
- **`AndroidManifest.xml:4-12`** — advertising-ID permissions explicitly removed via `tools:node="remove"`, which simplifies the Play Data Safety declaration.
- **`202607110002_data_policies.sql:69-116`** — the `chronospark-sync` storage bucket is private with correct per-user prefix isolation on all four operations.

---

## Companion documents

| Document | Contents |
|---|---|
| `DEPENDENCY_AUDIT.md` | All 50 direct deps; 17 unused; duplicates; dead codegen toolchain |
| `SUPABASE_AUDIT.md` | RLS matrix, migrations, both edge functions |
| `FIREBASE_AUDIT.md` | Initialization, Crashlytics, unused Firestore/Storage |
| `GOOGLE_PLAY_AUDIT.md` | Billing, signing, manifest, SDK levels, Play policy |
| `SECURITY_AUDIT.md` | Secrets, env vars, auth, storage, network, logging |
| `CI_CD_AUDIT.md` | All six workflows, action pinning, secrets handling |
| `RELEASE_BLOCKERS.md` | The 4 items that block a Play submission |
