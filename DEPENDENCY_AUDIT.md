# ChronoSpark — Dependency Audit

**Date:** 2026-08-06
**Manifest:** `pubspec.yaml` (50 direct: 46 runtime + 4 dev-tooling + 2 SDK)
**Lock:** `pubspec.lock` — **tracked in git** despite a `.gitignore` entry (see DEP-14)
**SDK:** `environment: sdk: ^3.12.0` vs installed Dart 3.12.2 — **compatible, no action**

---

## Summary

| Category | Count |
|---|---|
| Direct runtime dependencies | 46 |
| Direct dev dependencies | 6 |
| **Unused — zero import sites** | **13 runtime + 4 dev = 17** |
| Functional duplicates | 3 pairs |
| Discontinued upstream | 1 (`hive`) |
| Codegen toolchain generating nothing | 7 packages |

The single largest finding is that **the entire code-generation pipeline is dead weight** — 7 packages configured, zero generated files, zero annotations. Second is that **`cloud_firestore` and `firebase_storage` are declared but never imported**, pulling two large native SDKs into every APK for no benefit.

---

## DEP-01 · HIGH · The codegen toolchain generates nothing

**Files:** `pubspec.yaml:57, 77, 78, 99-102`

**Evidence — measured across all of `lib/`, `test/`, `integration_test/`, `tool/`:**

```
*.g.dart files                0
*.freezed.dart files          0
@freezed annotations          0
@riverpod annotations         0
@JsonSerializable annotations 0
package:freezed_annotation/   0 import sites
package:json_annotation/      0 import sites
package:riverpod_annotation/  0 import sites
.dart_tool/build cache        absent (build_runner has never run)
```

Seven packages exist to support code generation that does not happen:

| Package | Declared at | Resolved |
|---|---|---|
| `riverpod_annotation` | `pubspec.yaml:57` | (runtime) |
| `json_annotation` | `pubspec.yaml:77` | 4.12.0 |
| `freezed_annotation` | `pubspec.yaml:78` | 3.1.0 |
| `build_runner` | `pubspec.yaml:99` | (dev) |
| `riverpod_generator` | `pubspec.yaml:100` | (dev) |
| `freezed` | `pubspec.yaml:101` | (dev) |
| `json_serializable` | `pubspec.yaml:102` | (dev) |

**Impact:** Three runtime packages ship in the app binary for nothing. Four dev packages pull a heavy transitive tree (`analyzer`, `build`, `source_gen`, `dart_style`) that slows `pub get` and CI resolution. Anyone reading `pubspec.yaml` reasonably concludes the project uses Freezed and Riverpod codegen — it does not; providers are hand-written.

**Production risk:** Low direct risk; meaningful maintenance and build-time cost, plus an actively misleading signal about the codebase's conventions.

**Fix:** Remove all seven unless codegen is imminently planned. If it *is* planned, add one generated model to prove the pipeline and commit the output. Note `flutter_riverpod` (used, 3.3.2) is separate from `riverpod_annotation` (unused) — keep the former.

---

## DEP-02 · HIGH · `cloud_firestore` and `firebase_storage` declared but never imported

**Files:** `pubspec.yaml:82, 83`

```yaml
cloud_firestore: ^6.6.0      # resolved 6.6.0 — 0 import sites
firebase_storage: ^13.4.3    # resolved 13.4.3 — 0 import sites
```

**Impact:** Both federate to large native Android/iOS SDKs. Their presence adds method-count and APK size, extends the minification surface, and — because the Firebase Gradle plugin initializes registered components — can add measurable cold-start work for features the app never calls. It also implies a Firestore data model exists, which drives a pointless "where are the Firestore rules?" question (there are none in the repo; see `FIREBASE_AUDIT.md`).

**Fix:** Delete both lines. If Firestore is planned, add it back with the rules file in the same commit.

---

## DEP-03 · MEDIUM · Thirteen unused runtime packages

Measured by import-site count for `package:<name>/` across all Dart source:

| Package | Constraint | Resolved | Sites | Assessment |
|---|---|---|---|---|
| `cloud_firestore` | ^6.6.0 | 6.6.0 | 0 | Remove — see DEP-02 |
| `firebase_storage` | ^13.4.3 | 13.4.3 | 0 | Remove — see DEP-02 |
| `just_audio` | ^0.10.5 | 0.10.6 | 0 | Remove — duplicate, see DEP-04 |
| `internet_connection_checker_plus` | ^2.8.0 | 2.9.1+2 | 0 | Remove — duplicate, see DEP-04 |
| `encrypt` | ^5.0.3 | 5.0.3 | 0 | Remove — see DEP-05 |
| `logger` | ^2.6.1 | 2.7.0 | 0 | Remove or adopt — see DEP-06 |
| `image_picker` | ^1.1.2 | 1.2.3 | 0 | Remove — see DEP-07 |
| `cached_network_image` | ^3.4.1 | 3.4.1 | 0 | Remove |
| `vibration` | ^3.2.0 | — | 0 | Remove — see DEP-08 |
| `path_provider` | ^2.1.1 | 2.1.6 | 0 | Remove as *direct* dep (still transitive) |
| `riverpod_annotation` | ^4.0.3 | — | 0 | Remove — see DEP-01 |
| `json_annotation` | ^4.9.0 | 4.12.0 | 0 | Remove — see DEP-01 |
| `freezed_annotation` | ^3.0.0 | 3.1.0 | 0 | Remove — see DEP-01 |

**Correctly declared despite zero direct imports** (do not remove):

| Package | Why it stays |
|---|---|
| `in_app_purchase_android` | Federated platform implementation for `in_app_purchase`; 1 site confirms explicit use |
| `flutter_native_splash` | Build-time config consumer (`pubspec.yaml:189-192`) |
| `flutter_launcher_icons` | Build-time config consumer (`pubspec.yaml:194-200`) |
| `integration_test` | SDK package used by the test runner, not imported by `lib/` |
| `cupertino_icons` | Font asset, referenced by class not import |

---

## DEP-04 · MEDIUM · Three functional duplicate pairs

**Audio — `just_audio` vs `audioplayers`** (`pubspec.yaml:52, 54`)
`audioplayers` has 1 import site; `just_audio` has 0. Two full audio stacks are declared; one is used. `audio_session` (1 site) is legitimately used alongside `audioplayers` to configure the platform audio category and is **not** a duplicate.
→ Remove `just_audio`.

**Connectivity — `connectivity_plus` vs `internet_connection_checker_plus`** (`pubspec.yaml:68, 69`)
`connectivity_plus` has 1 import site; `internet_connection_checker_plus` has 0. These solve adjacent problems (interface state vs actual reachability), so holding both can be defensible — but only one is wired.
→ Remove `internet_connection_checker_plus`.

**Storage — `hive` + `shared_preferences` + `flutter_secure_storage`** (`pubspec.yaml:36, 37, 45`)
All three are genuinely used (13 / 23 / 3 sites). This is **not** a duplicate — it is a reasonable tiering: Hive for structured domain data, SharedPreferences for flags and settings, secure storage for tokens. **No action.** Verify from `SECURITY_AUDIT.md` that the tier boundaries hold (nothing sensitive in the unencrypted tiers).

---

## DEP-05 · MEDIUM · `encrypt` declared, never used

**File:** `pubspec.yaml:67`

Zero import sites. The good news is that this eliminates a whole class of finding — there is no hand-rolled crypto, no hardcoded IV, no ECB mode, and no static salt anywhere, because the package is simply not called. `crypto: ^3.0.3` (resolved 3.0.7) **is** used at 1 site.

**Impact:** Dependency bloat only. But an unused crypto library is a trap: the next developer who needs encryption finds it already in `pubspec.yaml` and reaches for it without design review.

**Fix:** Remove. Re-add deliberately if and when an encryption requirement is specified.

---

## DEP-06 · MEDIUM · `logger` declared, never used

**File:** `pubspec.yaml:79` — resolved 2.7.0, zero import sites.

Logging goes through something else (see `SECURITY_AUDIT.md` for what the app actually logs and whether it is release-gated).

**Fix:** Either remove, or adopt it deliberately as the single logging facade with a `kReleaseMode` guard. The current state — declared but bypassed — is the worst of both.

---

## DEP-07 · MEDIUM · `image_picker` unused but may still widen the permission surface

**File:** `pubspec.yaml:76` — resolved 1.2.3, zero import sites.

`image_picker` contributes entries to the merged Android manifest and, on iOS, requires `NSPhotoLibraryUsageDescription` / `NSCameraUsageDescription` in `Info.plist`. Shipping a media-access dependency the app never invokes complicates the Play Data Safety form and, on iOS, invites a review question about why photo access is requested for a feature that does not exist.

**Fix:** Remove. Confirm the merged manifest afterwards with `./gradlew :app:processReleaseManifest` and inspect `app/build/intermediates/merged_manifests/`.

---

## DEP-08 · LOW · `vibration` unused; VIBRATE permission arrives by manifest merge

**File:** `pubspec.yaml:56` — zero import sites.

`android/app/src/main/AndroidManifest.xml` does **not** declare `VIBRATE` directly, but the `vibration` plugin declares it in its own manifest, so it merges into the final APK regardless. The app therefore requests a permission for a package it never calls.

**Fix:** Remove the dependency; `VIBRATE` disappears from the merged manifest with it. If haptics are wanted, `HapticFeedback` from `flutter/services.dart` needs no dependency and no permission.

---

## DEP-09 · MEDIUM · `hive` 2.2.3 is discontinued upstream

**File:** `pubspec.yaml:37, 38` — `hive: ^2.2.3`, `hive_flutter: ^1.1.0`

Hive v2 is no longer actively maintained; the ecosystem has moved to `hive_ce` (community edition) or Isar. Hive is used at **13 import sites** and holds core domain data, so this is real technical debt rather than removable bloat.

**Impact:** No security fixes, no Dart/Flutter compatibility updates. A future Flutter release that breaks Hive v2 would strand the app's primary local store, with 13 call sites to migrate under time pressure.

**Production risk:** Low today, rising. Not a release blocker.

**Fix:** Plan a migration to `hive_ce` (largely drop-in, same box API) or Isar. Do this deliberately, not as part of a release.

---

## DEP-10 · LOW · Anthropic model is one generation behind

**File:** `supabase/functions/ai-proxy/index.ts:46`

```ts
const DEFAULT_MODEL = "claude-sonnet-4-6";
```

Verified against current Anthropic model documentation: `claude-sonnet-4-6` **is a valid, active model ID** — not deprecated, not retired. It is the previous-generation Sonnet. `claude-sonnet-5` is the current Sonnet at the same `$3/$15` per-MTok list price, with materially better coding and agentic performance.

The `anthropic-version: 2023-06-01` header at line 139 is **correct and current** — that value is the stable API version, not a date to bump.

**Fix (optional):** Move to `claude-sonnet-5`. Note it uses a different tokenizer (~30% more tokens for the same text), so re-baseline the 8,000-char prompt cap and `MAX_TOKENS = 1024` before switching. Not urgent; nothing is broken.

---

## DEP-11 · LOW · Model ID is hardcoded in the edge function

**File:** `supabase/functions/ai-proxy/index.ts:46`

The model string is a module constant, so changing it requires a function redeploy rather than a config change.

**Fix:** `Deno.env.get("ANTHROPIC_MODEL") ?? "claude-sonnet-4-6"` — a Supabase secret update then swaps models without a code change.

---

## DEP-12 · LOW · Deno standard library is three years stale

**Files:** `ai-proxy/index.ts:1` · `verify-receipt/index.ts:1`

```ts
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
```

`std@0.177.0` dates to early 2023. Modern Deno provides `Deno.serve()` natively, and `deno.land/std` has been superseded by JSR.

**Fix:** Replace `serve(handler)` with `Deno.serve(handler)` and drop the import entirely. Behaviourally identical for these handlers.

---

## DEP-13 · INFO · No `dependency_overrides`, no git or path pins

`pubspec.yaml` contains no `dependency_overrides` block and no dependency sourced from a git ref or local path. Every dependency resolves from pub.dev under a caret constraint. **This is clean** and worth preserving.

---

## DEP-14 · LOW · `pubspec.lock` is gitignored but tracked

**Files:** `.gitignore` (`pubspec.lock` under "# Flutter/Dart") · `git ls-files pubspec.lock` → **tracked**

The lock file was committed before the ignore rule was added, so Git continues to track it (`.gitignore` only affects untracked files). The **effective behaviour is correct** — an application should commit its lock file, and CI gets reproducible resolution.

**Impact:** The contradiction is a trap. A developer trusting `.gitignore` may assume lock changes are not versioned and skip reviewing them, letting a silent transitive-dependency bump through unexamined.

**Fix:** Delete the `pubspec.lock` line from `.gitignore`.

---

## Full direct-dependency table

Import-site counts measured across `lib/`, `test/`, `integration_test/`, `tool/`.

| Package | Constraint | Resolved | Sites | Verdict |
|---|---|---|---|---|
| `flutter` | sdk | — | — | SDK |
| `cupertino_icons` | ^1.0.8 | 1.0.9 | 0 | Keep (font asset) |
| `shared_preferences` | ^2.3.2 | — | 23 | **Used** |
| `hive` | ^2.2.3 | 2.2.3 | 13 | Used — **discontinued** (DEP-09) |
| `hive_flutter` | ^1.1.0 | 1.1.0 | — | Used with `hive` |
| `flutter_riverpod` | ^3.3.2 | 3.3.2 | many | **Used** |
| `go_router` | ^17.3.0 | 17.3.0 | many | **Used** |
| `in_app_purchase` | ^3.2.0 | 3.3.0 | yes | **Used** |
| `in_app_purchase_android` | ^0.5.1 | 0.5.1 | 1 | Federated impl — keep |
| `http` | ^1.3.0 | 1.6.0 | 6 | **Used** |
| `url_launcher` | ^6.3.1 | — | 1 | **Used** |
| `flutter_secure_storage` | ^10.3.1 | 10.3.1 | 3 | **Used** |
| `flutter_local_notifications` | ^22.0.1 | 22.0.1 | yes | **Used** |
| `app_links` | ^7.2.0 | 7.2.1 | 1 | **Used** |
| `flutter_dotenv` | ^6.0.1 | 6.0.1 | yes | **Used** |
| `supabase_flutter` | ^2.16.0 | — | yes | **Used** |
| `flutter_svg` | ^2.3.0 | 2.3.0 | 2 | **Used** |
| `lottie` | ^3.4.0 | 3.5.1 | 6 | **Used** |
| `just_audio` | ^0.10.5 | 0.10.6 | **0** | **REMOVE** (DEP-04) |
| `audio_session` | ^0.2.2 | 0.2.4 | 1 | **Used** |
| `audioplayers` | ^6.8.1 | 6.8.1 | 1 | **Used** |
| `flutter_tts` | ^4.2.3 | 4.2.5 | 1 | **Used** |
| `vibration` | ^3.2.0 | — | **0** | **REMOVE** (DEP-08) |
| `riverpod_annotation` | ^4.0.3 | — | **0** | **REMOVE** (DEP-01) |
| `intl` | ^0.20.0 | 0.20.3 | 2 | **Used** |
| `firebase_core` | ^4.11.0 | 4.11.0 | yes | **Used** |
| `firebase_auth` | ^6.5.4 | 6.5.4 | yes | **Used** |
| `firebase_crashlytics` | ^5.0.0 | 5.2.4 | yes | **Used** |
| `firebase_analytics` | ^12.0.0 | 12.4.3 | 1 | **Used** |
| `firebase_messaging` | ^16.0.0 | 16.4.1 | 1 | **Used** |
| `device_info_plus` | ^13.0.0 | 13.2.0 | 1 | **Used** |
| `package_info_plus` | ^10.0.0 | 10.2.0 | 1 | **Used** |
| `crypto` | ^3.0.3 | 3.0.7 | 1 | **Used** |
| `encrypt` | ^5.0.3 | 5.0.3 | **0** | **REMOVE** (DEP-05) |
| `connectivity_plus` | ^7.2.0 | 7.2.0 | 1 | **Used** |
| `internet_connection_checker_plus` | ^2.8.0 | 2.9.1+2 | **0** | **REMOVE** (DEP-04) |
| `path_provider` | ^2.1.1 | 2.1.6 | **0** | **REMOVE as direct** |
| `timezone` | ^0.11.1 | — | 2 | **Used** |
| `flutter_timezone` | ^4.1.1 | 4.1.1 | 1 | **Used** |
| `firebase_remote_config` | ^6.5.3 | 6.5.3 | 1 | **Used** |
| `share_plus` | ^13.2.0 | — | 3 | **Used** |
| `cached_network_image` | ^3.4.1 | 3.4.1 | **0** | **REMOVE** |
| `image_picker` | ^1.1.2 | 1.2.3 | **0** | **REMOVE** (DEP-07) |
| `json_annotation` | ^4.9.0 | 4.12.0 | **0** | **REMOVE** (DEP-01) |
| `freezed_annotation` | ^3.0.0 | 3.1.0 | **0** | **REMOVE** (DEP-01) |
| `logger` | ^2.6.1 | 2.7.0 | **0** | **REMOVE/adopt** (DEP-06) |
| `permission_handler` | ^12.0.1 | 12.0.3 | 1 | **Used** |
| `speech_to_text` | ^7.4.0 | — | 1 | **Used** |
| `cloud_firestore` | ^6.6.0 | 6.6.0 | **0** | **REMOVE** (DEP-02) |
| `firebase_storage` | ^13.4.3 | 13.4.3 | **0** | **REMOVE** (DEP-02) |

### Dev dependencies

| Package | Constraint | Verdict |
|---|---|---|
| `flutter_test` / `integration_test` | sdk | Keep |
| `flutter_native_splash` | ^2.4.1 | Keep — build-time config |
| `flutter_launcher_icons` | ^0.14.4 | Keep — build-time config |
| `flutter_lints` | ^6.0.0 | Keep |
| `build_runner` | ^2.4.13 | **REMOVE** (DEP-01) |
| `riverpod_generator` | ^4.0.4 | **REMOVE** (DEP-01) |
| `freezed` | ^3.0.0 | **REMOVE** (DEP-01) |
| `json_serializable` | ^6.9.5 | **REMOVE** (DEP-01) |

---

## Recommended action

Removing the 17 unused packages is a single low-risk change — by definition nothing imports them.

```yaml
# pubspec.yaml — delete these lines
just_audio, vibration, riverpod_annotation, encrypt,
internet_connection_checker_plus, path_provider, cached_network_image,
image_picker, json_annotation, freezed_annotation, logger,
cloud_firestore, firebase_storage
# dev_dependencies
build_runner, riverpod_generator, freezed, json_serializable
```

Verify with `flutter pub get && flutter analyze && flutter test`. Because none are imported, a clean analyze is strong evidence the removal is safe. Do this **separately** from any release commit.
