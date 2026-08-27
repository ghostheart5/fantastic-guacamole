# ChronoSpark — Google Play Audit

**Date:** 2026-08-06
**Application ID:** `com.ghostheart5.chronospark`
**Version:** `4.0.0` (`versionName`) / `2026071133` (`versionCode`)
**Build:** AGP 8.11.1 · Gradle 8.14.3 · Kotlin 2.2.20 · JDK 17
**SDK:** compileSdk 36 · minSdk 24 · targetSdk 36

---

## Summary

The Android build configuration is **well constructed**. Release signing raises a hard error rather than silently falling back to the debug keystore — the single most common Play-submission defect, and it is handled correctly here. `allowBackup` is off, cleartext traffic is off, advertising-ID permissions are stripped, every component sets `android:exported`, and the permission set is minimal and justified.

Two items block a submission, and one purchase-flow detail is worth confirming before shipping.

| ID | Severity | Finding |
|---|---|---|
| GP-01 | **HIGH — BLOCKER** | Play Billing Library 6.0.1 pinned; Play requires v7+ (v8 current) |
| GP-02 | HIGH | No Play Console upload path; release stops at a GitHub artifact |
| GP-03 | MEDIUM | App Links declared `autoVerify` but no `assetlinks.json` / blank cert fingerprint |
| GP-04 | MEDIUM | ProGuard missing `-keepattributes`; minify + optimize is enabled |
| GP-05 | LOW | Test plugin (`IntegrationTestPlugin.java`) lives in the `main` source set |
| GP-06 | LOW | Orphan `com.example.fantastic_guacamole.MainActivity` |
| GP-07 | LOW | Deprecated `package` attribute in the manifest under AGP 8 |
| GP-08 | LOW | `versionCode` scheme is date-derived and near-irreversible |
| GP-09 | INFO | No Play Console assets, listing, or Data Safety artifacts in-repo |

---

## GP-01 · HIGH · **RELEASE BLOCKER** · Play Billing Library 6.0.1

**File:** `android/app/build.gradle.kts:104-108`

```kotlin
dependencies {
    implementation("androidx.core:core-splashscreen:1.0.1")
    implementation("com.android.billingclient:billing:6.0.1")   // ← line 106
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
```

**Two independent problems:**

**1. Play Console rejects it.** Google Play required Billing Library 7+ for new app updates as of 31 August 2025, and has since moved the floor to v8. An AAB built against 6.0.1 fails validation at upload with a policy error. This is a hard gate, not a warning.

**2. It can downgrade the plugin's own Billing Client.** `in_app_purchase_android: ^0.5.1` declares its own `com.android.billingclient:billing` dependency. Gradle resolves a single version per module, and an explicit `implementation` declaration participates in that resolution — so pinning 6.0.1 can force the plugin below the API level it compiles against. The symptom is `NoSuchMethodError` or `NoClassDefFoundError` **at purchase time in release builds only**, which minification makes maximally difficult to diagnose.

**Impact:** Cannot ship. If somehow shipped, the purchase flow is the most likely thing to break — directly, revenue.

**Production risk:** Blocker plus latent revenue loss.

**Recommended fix — delete the line entirely:**

```kotlin
dependencies {
    implementation("androidx.core:core-splashscreen:1.0.1")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
```

`in_app_purchase_android` resolves and ships the Billing Client version it was built against. Manually pinning it is the source of the problem, not the fix.

**Verify:**

```bash
./gradlew :app:dependencies --configuration releaseRuntimeClasspath | grep billingclient
```

Confirm the resolved version is ≥ 7. If `in_app_purchase_android` 0.5.1 itself resolves below 7, upgrade `in_app_purchase` / `in_app_purchase_android` — that upgrade, not a manual pin, is the correct lever.

---

## GP-02 · HIGH · No path from CI to the Play Console

**File:** `.github/workflows/android-release.yml`

Steps: checkout → Flutter → deps → secret guard → decode keystore → write `key.properties` → **verify upload-key fingerprint** → Firebase config → validate production config → build AAB → `actions/upload-artifact@v4` → Create GitHub Release.

There is no `r0adkll/upload-google-play`, no Fastlane, no `bundletool`, and no Play Developer API publishing step. The pipeline produces a correctly signed AAB and then stops.

**Impact:** Every release requires a human to download the artifact from GitHub and hand-upload it to the Play Console. That is a manual step in the most consequential part of the process — the point where the wrong artifact, or an artifact from the wrong commit, does the most damage. There is also no automated track management (internal → closed → production), no staged rollout, and no release-notes propagation.

**Note the fingerprint verification step is genuinely good** (`android-release.yml:63-67`) — it runs `keytool -list -v` against the decoded keystore and compares the SHA-1 to the expected upload key, catching a wrong-keystore mistake before the build. That control is more valuable than most projects have. It just is not followed through to publication.

**Production risk:** Manual-step risk at the release boundary; no rollout control.

**Fix:** Add a publish job gated on manual approval (GitHub Environments):

```yaml
- uses: r0adkll/upload-google-play@v1
  with:
    serviceAccountJsonPlainText: ${{ secrets.PLAY_SERVICE_ACCOUNT_JSON }}
    packageName: com.ghostheart5.chronospark
    releaseFiles: build/app/outputs/bundle/release/app-release.aab
    track: internal
    status: completed
```

Note the receipt-verification edge function already requires a Google service account with `androidpublisher` scope — publishing needs a **separate** service account with Play Console release permissions. Do not reuse the verification account.

---

## GP-03 · MEDIUM · App Links declared verified but cannot verify

**Files:** `AndroidManifest.xml:50-76` · `.env` (`CHRONOSPARK_ANDROID_SHA256_CERT` — blank)

Three intent filters declare `android:autoVerify="true"`:

| Scheme | Host | Path prefix |
|---|---|---|
| https | `ghostheart5.github.io` | `/fantastic-guacamole/app` |
| https | `chronospark.app` | `/app` |
| https | `www.chronospark.app` | `/app` |

Android App Links verification requires a Digital Asset Links file at `https://<host>/.well-known/assetlinks.json` containing the **release** signing certificate's SHA-256 fingerprint. `CHRONOSPARK_ANDROID_SHA256_CERT` is empty, and `scripts/generate_well_known.dart` — which appears to exist for exactly this purpose — has no CI invocation.

**Impact:** Verification fails silently at install. Android falls back to the app-chooser disambiguation dialog instead of opening links directly in the app. Nothing errors; the feature simply does not work as designed, and the failure is invisible without explicitly querying link state.

Additionally: because the app is (presumably) distributed via Play App Signing, the fingerprint that must appear in `assetlinks.json` is the **Play-managed app signing certificate**, not the upload certificate. Using the upload cert here is the classic mistake and produces exactly the same silent failure.

**Fix:**
1. Retrieve the **app signing** SHA-256 from Play Console → Setup → App integrity.
2. Populate `CHRONOSPARK_ANDROID_SHA256_CERT` (CI secret).
3. Generate and host `assetlinks.json` at `/.well-known/` on each of the three hosts.
4. Verify: `adb shell pm get-app-links com.ghostheart5.chronospark` — every domain should read `verified`.

Also confirm `chronospark.app` is actually registered and serving; if it is not, remove those two filters rather than shipping a permanently-failing declaration.

---

## GP-04 · MEDIUM · ProGuard rules omit `-keepattributes`

**File:** `android/app/proguard-rules.pro` (15 lines) · `build.gradle.kts:83-89`

```kotlin
isMinifyEnabled = true
isShrinkResources = true
proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
```

The existing rules are **sensible** — Flutter embedding, `GeneratedPluginRegistrant`, `io.flutter.plugins.**`, `flutterlocalnotifications`, Firebase, GMS measurement, and `billingclient.api` are all kept. That covers the main crash surfaces.

What is missing is attribute retention:

```proguard
-keepattributes Signature, InnerClasses, EnclosingMethod
-keepattributes RuntimeVisibleAnnotations, RuntimeVisibleParameterAnnotations
-keepattributes AnnotationDefault
-keepattributes SourceFile, LineNumberTable
```

**Impact:**
- **`Signature` / `InnerClasses`** — `flutter_local_notifications` serializes scheduled notifications with Gson, which resolves generic types via `TypeToken`. Stripping generic signatures breaks that at runtime, and the failure mode is *scheduled notifications silently never firing after a reboot* — a bug that looks like a scheduling problem and is nearly impossible to trace to ProGuard.
- **`SourceFile` / `LineNumberTable`** — without these, Crashlytics stack traces have no line numbers even when the mapping file uploads correctly. Combined with `FB-01`, release crash reports could be doubly unreadable.

Most Flutter plugins ship `consumer-proguard-rules.pro` that AGP merges automatically, which is why this often works anyway — but `proguard-android-optimize.txt` is the more aggressive default variant, and relying on transitive consumer rules for a revenue-critical purchase flow is a thin margin.

**Fix:** Add the `-keepattributes` lines above, plus `speech_to_text` keeps. Then **test a real release build end to end** — install the actual AAB (via `bundletool build-apks --local-testing`) and exercise: schedule a notification → reboot → confirm it fires; complete a test purchase; trigger a deliberate crash and confirm the Crashlytics trace is deobfuscated with line numbers.

---

## GP-05 · LOW · Integration-test plugin ships in the production source set

**File:** `android/app/src/main/java/dev/flutter/plugins/integration_test/IntegrationTestPlugin.java`

This is in `src/main/`, not `src/androidTest/`, so it compiles into every build variant including release.

**Impact:** Test scaffolding in the shipped APK. Minor size cost; more importantly it is a code path with no production purpose inside the release binary, and `-keep class io.flutter.plugins.** { *; }` in `proguard-rules.pro` may well prevent it from being stripped.

**Fix:** Move to `android/app/src/androidTest/java/`, or delete it — `integration_test` normally injects this automatically during test builds and does not require a checked-in copy.

`GeneratedPluginRegistrant.java` in the same directory is expected: Flutter generates it and it belongs in `main`.

---

## GP-06 · LOW · Orphan MainActivity from an incomplete rename

**Files:**
- `android/app/src/main/kotlin/com/ghostheart5/chronospark/MainActivity.kt` — **active**
- `android/app/src/main/kotlin/com/example/fantastic_guacamole/MainActivity.kt` — **dead**

`AndroidManifest.xml:30` declares `android:name=".MainActivity"`, which resolves relative to the manifest package `com.ghostheart5.chronospark`. The `com.example.fantastic_guacamole` copy is never referenced.

**Impact:** Dead code that compiles into the APK. Pairs with the stale `com.example.chronospark` entry in `google-services.json` (`FIREBASE_AUDIT.md` FB-05) — both are residue from the same unfinished package rename. The real cost is confusion: a developer editing the wrong `MainActivity` sees no effect.

**Fix:** Delete `android/app/src/main/kotlin/com/example/`.

---

## GP-07 · LOW · Deprecated `package` attribute in the manifest

**File:** `android/app/src/main/AndroidManifest.xml:3`

```xml
<manifest xmlns:android="..." package="com.ghostheart5.chronospark">
```

AGP 8 takes the application ID from `namespace` in `build.gradle.kts` (line 52) and ignores the manifest `package` attribute, emitting a warning. The two agree here, so behaviour is correct.

**Impact:** None today. It becomes a live hazard if `namespace` is ever changed without updating the manifest — the values would silently disagree, and `.MainActivity` resolution depends on the manifest package.

**Fix:** Remove the `package` attribute. Keep `namespace` in Gradle as the single source of truth.

---

## GP-08 · LOW · Date-derived `versionCode` constrains future releases

**Files:** `pubspec.yaml:19` (`4.0.0+2026071133`) · `android/gradle.properties` (`CHRONOSPARK_VERSION_CODE=2026071133`)

`2026071133` is well under Play's 2,100,000,000 ceiling and is monotonic while the scheme holds. It reads as `YYYYMMDD` + a 2-digit counter.

**Impact:** Two constraints worth knowing. The scheme allows only 100 builds per day (`00`–`99`), and — more significantly — it is **effectively irreversible**: because `versionCode` must always increase and this one already encodes a 2026 date, migrating to a simple incrementing integer later would require starting above 2,026,071,133, consuming most of the remaining headroom.

**Fix:** No action needed; the scheme works. Document it so nobody "simplifies" it to `versionCode 1` later, which Play would reject permanently for this package name.

**Note the duplication:** the version is declared in both `pubspec.yaml:19` and `android/gradle.properties`, with Gradle preferring the property (`build.gradle.kts:32-38`). These can drift. Prefer deriving from `pubspec.yaml` alone, or add a CI assertion that they match.

---

## GP-09 · INFO · No Play Console artifacts in the repository

Absent: Fastlane config, store listing metadata, screenshots, feature graphic, privacy-policy URL mapping, and Data Safety declaration.

Present but unwired: `feature.png` (1.3 MB) and `chronospark_emulator.png` (568 KB) sit in the repo root, unreferenced by any tooling.

**Impact:** Listing content is managed by hand in the console, so it is unversioned and unreviewable. For the Data Safety form specifically, the answers must match what the app actually does — and this audit establishes several relevant facts:

- Data **is** sent off-device: Supabase (sync, metrics, profiles), Anthropic (AI prompts — see `SECURITY_AUDIT.md` for what user content reaches the provider), Firebase Analytics and Crashlytics.
- Advertising ID is **not** collected (`AndroidManifest.xml:4-12` removes it) — declare accordingly.
- Account deletion: `.env` references `CHRONOSPARK_ACCOUNT_DELETE_ENDPOINT`, but **no such edge function exists** in `supabase/functions/`. Play requires an in-app account-deletion path *and* a web URL for apps that support account creation. **Confirm this before submission** — it is a policy requirement, not a nicety.

**Fix:** Adopt Fastlane `supply` so listing metadata is versioned. Complete the Data Safety form against the flows enumerated in `INFRASTRUCTURE_AUDIT.md` §1. Verify the account-deletion endpoint exists and is deployed.

---

## A. Configuration reference

| Setting | Value | Source | Assessment |
|---|---|---|---|
| `applicationId` / `namespace` | `com.ghostheart5.chronospark` | `gradle.properties`, `build.gradle.kts:30,52` | ✅ Not `com.example.*` |
| `compileSdk` | 36 | `maxOf(flutter.compileSdkVersion, 34)` → Flutter 3.44 = 36 | ✅ |
| `minSdk` | 24 | `flutter.minSdkVersion` | ✅ Android 7.0+ |
| `targetSdk` | 36 | `maxOf(flutter.targetSdkVersion, 34)` → 36 | ✅ Meets Aug-2026 Play requirement |
| `versionCode` | 2026071133 | `gradle.properties` | ✅ Valid — see GP-08 |
| `versionName` | 4.0.0 | `gradle.properties` | ✅ |
| Java / Kotlin target | 17 / JVM_17 | `build.gradle.kts:57-58, 112` | ✅ |
| Core library desugaring | enabled, `desugar_jdk_libs:2.1.5` | line 59, 107 | ✅ Required by `flutter_local_notifications` |
| `isMinifyEnabled` | true | line 83 | ✅ — see GP-04 |
| `isShrinkResources` | true | line 84 | ✅ |
| Release signing | hard `error()` if unconfigured | lines 91-99 | ✅ **Correct** |
| AGP / Gradle / Kotlin | 8.11.1 / 8.14.3 / 2.2.20 | `settings.gradle.kts`, wrapper | ✅ Current, compatible |

**The `maxOf(flutter.*, 34)` pattern** sets a *floor*, not a value — the effective SDK level tracks whatever Flutter ships. That is why `targetSdk` is 36 today and meets Play's requirement. It also means **the Play compliance of this build is a function of the Flutter version**, which `CI_CD_AUDIT.md` CI-03 shows is unpinned. Pinning `flutter-version` is what makes this guarantee stable.

### Signing — verified correct

```kotlin
if (releaseSigningConfig != null) {
    signingConfig = releaseSigningConfig
} else {
    error("Release signing is not configured. Populate android/key.properties …")
}
```

There is **no** `signingConfig = signingConfigs.getByName("debug")` fallback in the release block — the most common cause of a rejected or unshippable AAB. `hasReleaseSigningValues()` (lines 40-49) additionally rejects placeholder values starting with `YOUR_`, so a half-filled `key.properties` fails loudly rather than producing a mis-signed build.

`git ls-files` confirms **no keystore, no `key.properties`, and no `.jks` file is committed** — only `key.properties.example` and `release.properties.example`.

---

## B. Permission audit

Every permission in `AndroidManifest.xml` maps to a declared, used capability.

| Permission | Line | Justification | Verdict |
|---|---|---|---|
| `INTERNET` | 13 | Supabase, Anthropic proxy, Firebase | ✅ |
| `com.android.vending.BILLING` | 14 | `in_app_purchase` | ✅ |
| `POST_NOTIFICATIONS` | 15 | `flutter_local_notifications`, FCM | ✅ Runtime request required on API 33+ |
| `RECORD_AUDIO` | 17 | `speech_to_text` (1 import site) | ✅ Commented as post-action request |
| `WAKE_LOCK` | 18 | Notification delivery and scheduled work | ✅ |
| `RECEIVE_BOOT_COMPLETED` | 19 | Reschedules notifications after reboot | ✅ Paired with the boot receiver, line 91-100 |
| `AD_ID` + 2 AdServices | 4-12 | **Removed** via `tools:node="remove"` | ✅ Privacy-positive |

**Not declared, correctly:**
- `SCHEDULE_EXACT_ALARM` / `USE_EXACT_ALARM` — not needed, because `notification_scheduler.dart:223,274` uses `AndroidScheduleMode.inexactAllowWhileIdle`. This is a **deliberate and correct** trade: exact alarms require a Play Console policy declaration that a productivity app does not qualify for. Reminders may drift by minutes under Doze; that is the right price.
- `QUERY_ALL_PACKAGES` — absent. Its presence is a Play policy violation; the manifest instead uses a scoped `<queries>` block for `ACTION_PROCESS_TEXT` (lines 112-117), which is the correct approach.
- `VIBRATE` — not declared directly, but merges in from the `vibration` plugin, which has **zero import sites**. Removing that dependency removes the permission (`DEPENDENCY_AUDIT.md` DEP-08).
- Camera / storage — not declared, but `image_picker` (also unused) may contribute entries at merge time. Removing it removes the question (DEP-07).

**Verify the merged manifest before submission** — plugin manifests contribute permissions that never appear in the app's own file:

```bash
./gradlew :app:processReleaseManifest
# then inspect android/app/build/intermediates/merged_manifests/release/AndroidManifest.xml
```

### Component export flags

| Component | `exported` | Correct? |
|---|---|---|
| `.MainActivity` | `true` | ✅ Required — has LAUNCHER intent filter |
| `ScheduledNotificationReceiver` | `false` | ✅ |
| `ScheduledNotificationBootReceiver` | `false` | ✅ Receives `BOOT_COMPLETED` via system broadcast |

All components declare `android:exported` explicitly, required since API 31. No component is over-exported.

### Application flags

| Flag | Value | Assessment |
|---|---|---|
| `android:allowBackup` | `false` | ✅ Prevents user data reaching Google Drive backups unencrypted |
| `android:fullBackupContent` | `false` | ✅ Consistent |
| `android:usesCleartextTraffic` | `false` | ✅ All traffic is HTTPS |
| `android:enableOnBackInvokedCallback` | `true` | ✅ Predictive back, Android 13+ |

---

## C. Billing implementation

**File:** `lib/data/repositories/google_play_paywall_repository.dart`

| Requirement | Status | Evidence |
|---|---|---|
| `completePurchase` called on success | ✅ | line 463 |
| `completePurchase` called for pending | ✅ | lines 470-471, guarded by `purchase.pendingCompletePurchase` |
| `restorePurchases` implemented | ✅ | lines 72-73, 384, 407; surfaced in UI at `paywall_page.dart:129` |
| Restored purchases distinguished | ✅ | lines 430-431, 443 — handles `purchased` and `restored` |
| Error state handled | ✅ | line 464 |
| Server-side verification | ✅ | `verify-receipt` edge function — see `SUPABASE_AUDIT.md` |

**The acknowledgement path is correct.** Google Play automatically refunds any purchase not acknowledged within three days; a missing `completePurchase` is one of the most expensive bugs in mobile commerce, and it is handled here — including the `pendingCompletePurchase` branch, which is the case most implementations miss.

Product IDs are allowlisted server-side (`verify-receipt/index.ts:8-11`): `chronospark_premium_monthly`, `chronospark_premium_annual`. These must exactly match the Play Console subscription IDs — verify before launch, as a mismatch causes verification to reject legitimate purchases with `"Missing required fields"`.

**Entitlement storage** could not be confirmed by this audit — a targeted search for premium/entitlement state being written to `SharedPreferences` or Hive returned no matches, which suggests entitlement is derived from the verified subscription state rather than cached in a user-editable local store. **Confirm this holds**: if premium status is ever persisted to `SharedPreferences`, a rooted user can edit it to unlock paid features. Entitlement should come from `verify-receipt` or `purchase_bindings`, with any local cache treated strictly as a non-authoritative offline hint.

---

## Priority

1. **GP-01** — blocks submission. Delete the pinned Billing dependency, verify the resolved version.
2. **GP-04** — add `-keepattributes` and test a real release build before shipping; interacts with GP-01 in the purchase path.
3. **GP-03** — fix before advertising deep links.
4. **GP-09** — confirm the account-deletion endpoint exists; it is a Play policy requirement.
5. **GP-02** — automate publishing once the above are resolved.
6. **GP-05 – GP-08** — housekeeping.
