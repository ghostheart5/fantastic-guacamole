# ChronoSpark — Security Audit

**Date:** 2026-08-06
**Scope:** Secrets, environment configuration, authentication, local storage, cryptography, network, logging, PII
**Method:** READ-ONLY. All secret values redacted — key names, lengths, and prefixes only.

---

## MUST ROTATE

**None.**

A full sweep for `sk-`, `sk-ant-`, `AIza`, `eyJ` (JWT), `service_role`, `-----BEGIN`, `password=`, `secret=`, `token=`, and `Bearer ` across the repository (excluding `build/`, `.dart_tool/`, `.git/`) found **no committed credential requiring rotation**.

Specifically verified:

| Suspected exposure | Actual finding |
|---|---|
| `.env` bundled as a Flutter asset | **Byte-identical to `.env.example`.** Every value blank or a dev default. No secret present. |
| `.env` in git history | Not tracked, never committed. Only `.env.example` is versioned. |
| `supabase/.temp/pooler-url` | **No embedded password.** Structural test for `postgresql://USER:PASSWORD@HOST` did not match — user and host only. |
| Anthropic API key | Server-side only, `Deno.env.get("ANTHROPIC_API_KEY")` — never in client code or assets. |
| Supabase `service_role` key | Server-side only, in `verify-receipt` — never reaches the client. |
| Firebase API keys in `firebase_options.dart` | Present, and **correctly so** — these are project identifiers, not secrets, designed to ship. Protected by Security Rules and API-key restrictions, not concealment. |
| Keystore / `key.properties` | Not committed. Only `.example` templates. |

---

## Summary

The configuration security model is **stronger than it first appears**, because of one control that is easy to miss and worth naming explicitly: risk-bearing environment keys deliberately ignore the bundled `.env` file in release builds (SEC-A below). That neutralizes the entire class of "repackage the APK with a modified `.env`" attacks against mock login, paywall bypass, and tester access.

One key was left out of that protection, and it is enabled.

| ID | Severity | Finding |
|---|---|---|
| SEC-01 | MEDIUM | `VERBOSE_LOGS=true` ships in the asset `.env` and is **not** risk-gated → verbose logging in release |
| SEC-02 | MEDIUM | AI proxy accepts a client-supplied system prompt (cost/abuse) |
| SEC-03 | MEDIUM | `flutter_secure_storage` used with no explicit `AndroidOptions` |
| SEC-04 | MEDIUM | Two auth providers; sign-out completeness unverified |
| SEC-05 | LOW | `.env` as a bundled asset is a standing invitation to future exposure |
| SEC-06 | LOW | `supabase/.temp/` committed (project ref, org ID, region) |
| SEC-07 | LOW | `security definer` functions pin `search_path = public`, not `''` |
| SEC-08 | INFO | Privacy-policy alignment and account deletion need confirmation |

Cross-references: the **CRITICAL** finding in this system is `SUP-01` (cross-tenant RLS read) — see `SUPABASE_AUDIT.md`. It is a data-exposure issue rather than a secrets issue, so it is owned by that document.

---

## SEC-A · The control that makes this design work

**File:** `lib/config/env.dart:411-425`

```dart
static bool _readRiskBool(String key, bool fallback) {
  if (kReleaseMode) {
    return fallback;          // .env is bypassed entirely in release
  }
  return _readBool(key, fallback);
}

/// String counterpart of [_readRiskBool]. Used for the app flavor, which
/// gates every other production check.
static String _readRiskString(String key, String fallback) {
  if (kReleaseMode) {
    return fallback;
  }
  return _readString(key, fallback);
}
```

Keys routed through the risk-gated readers (`env.dart:113-126` and following):

| Key | Reader | Release behaviour |
|---|---|---|
| `CHRONOSPARK_APP_FLAVOR` | `_readRiskString` | `.env` ignored; default `'prod'` (line 18) |
| `CHRONOSPARK_ENABLE_MOCK_LOGIN` | `_readRiskBool` | `.env` ignored |
| `CHRONOSPARK_ENABLE_MOCK_MODE` | `_readRiskBool` | `.env` ignored |
| `CHRONOSPARK_PAYWALL_DISABLED` | `_readRiskBool` | `.env` ignored |
| `CHRONOSPARK_ENABLE_TESTER_FULL_ACCESS` | `_readRiskBool` | `.env` ignored |

**Why this matters.** The `.env` file ships inside the APK as a Flutter asset (`pubspec.yaml:115`) and is trivially extractable — and modifiable — by unzipping the APK and repackaging. Without this control, an attacker could set `CHRONOSPARK_PAYWALL_DISABLED=true` or `CHRONOSPARK_ENABLE_MOCK_LOGIN=true` in the asset and unlock paid features or bypass authentication. `_readRiskBool`/`_readRiskString` make the bundled file **inert for exactly those keys** in any release build.

There is a **second, independent layer**: `env.dart:180-219` gates mock behaviour on `!isProduction` as well —

```dart
return !isProduction && (isMockMode || enableMockLogin);   // line 219
```

— and `_appFlavorDefine` defaults to `'prod'` (line 18), so a release build with no `--dart-define` at all still resolves to production. Two independent controls must both fail before a bypass activates.

This is genuinely good design and should not be refactored away. The finding below is that one key was omitted from it.

---

## SEC-01 · MEDIUM · Verbose logging is enabled in release builds

**Files:** `.env` (`CHRONOSPARK_VERBOSE_LOGS = true`) · `lib/config/env.dart:115-116` · `lib/core/debug/logger.dart:13,18,23`

```dart
// env.dart:115 — note: _readBool, NOT _readRiskBool
static bool get enableVerboseLogs =>
    _readBool('CHRONOSPARK_VERBOSE_LOGS', _enableVerboseLogsDefine);
```

```dart
// logger.dart:13
if (!enabled || (!kDebugMode && !Env.enableVerboseLogs)) return;
```

**Trace the release path:**

1. `CHRONOSPARK_VERBOSE_LOGS` uses `_readBool`, so — unlike the risk-gated keys — the bundled `.env` **is** consulted in release.
2. The shipped `.env` sets it to `true` (a non-blank value, so it is not skipped by the blank-value fallthrough at `env.dart:367`).
3. In a release build `kDebugMode` is `false`, so the guard reduces to `if (!enabled || !Env.enableVerboseLogs) return;`.
4. `Env.enableVerboseLogs` is `true` → **the guard does not return, and logging proceeds.**

The compile-time default is correct (`_enableVerboseLogsDefine` defaults to `false`, line 20-23) — but the `.env` value overrides it, and CI does not pass a `--dart-define` for this key (`android-release.yml:118-127` sets eight defines; `CHRONOSPARK_VERBOSE_LOGS` is not among them).

**Impact:** Diagnostic logging is active in production, writing to logcat. On Android, logcat is readable by the user, by any app with `READ_LOGS` on a rooted device, and is captured in bug reports and by crash-reporting SDKs. Whatever the logger emits — user IDs, emails, request payloads, AI prompt content, task titles — leaves the app's private storage boundary.

**Production risk:** PII exposure of unknown breadth, plus a small performance and battery cost. The severity depends on what is actually logged; the exposure channel is certain.

**Recommended fix — pick one, ideally both:**

```bash
# 1. The immediate fix — blank the value so the default (false) applies
CHRONOSPARK_VERBOSE_LOGS=
```

```yaml
# 2. The durable fix — set it explicitly at build time
--dart-define=CHRONOSPARK_VERBOSE_LOGS=false
```

**And close the class of bug**, since this key is a diagnostic-exposure risk in the same way the others are a bypass risk:

```dart
static bool get enableVerboseLogs =>
    _readRiskBool('CHRONOSPARK_VERBOSE_LOGS', _enableVerboseLogsDefine);
```

**Then audit what is logged.** Grep every `Logger.info` / `Logger.debug` call site for user identifiers, email addresses, tokens, request bodies, and AI prompt content, and ensure none are emitted regardless of the flag.

---

## SEC-02 · MEDIUM · AI proxy accepts a client-supplied system prompt

**File:** `supabase/functions/ai-proxy/index.ts:53, 94, 132`

```ts
system?: string;                    // client-supplied
...
if (system) anthropicBody.system = system;
```

Any authenticated user can replace the system prompt, turning the proxy into a general-purpose LLM billed to the app owner and bypassing the app's persona, safety framing, and output constraints.

Compounded by `SUP-03` — rate limiting is per-isolate in-memory and does not hold across the function's execution model, so the volume ceiling is weaker than the code implies.

By contrast, the model **is** correctly server-controlled (`index.ts:128` always uses `DEFAULT_MODEL`), so a client cannot select a more expensive model. `system` is the inconsistency.

**Fix:** Remove `system` from `ProxyRequest`; compose it server-side from a fixed template. If per-mode variation is needed, accept a `mode` enum mapped to server-side templates. Full detail in `SUPABASE_AUDIT.md` SUP-04.

---

## SEC-03 · MEDIUM · `flutter_secure_storage` has no explicit platform options

**Files:** `pubspec.yaml:45` (`flutter_secure_storage: ^10.3.1`, resolved 10.3.1) · 3 import sites

A search for `AndroidOptions`, `IOSOptions`, and `encryptedSharedPreferences` across all Dart source returned **no matches** — the plugin is used with default options everywhere.

**Impact:** flutter_secure_storage changed its Android storage backend between major versions; v10 reworked it relative to the v8/v9 behaviour where `encryptedSharedPreferences: true` was an explicit opt-in. Relying on an unstated default for the store that holds session tokens means the actual on-device protection is undocumented and will silently change on the next major upgrade.

**This is a "verify and pin" finding, not a confirmed weakness** — the v10 default may well be correct. What is missing is the explicit declaration that makes it reviewable and upgrade-safe.

**Fix:** Declare options at every construction site and document the intent:

```dart
const FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
  iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
);
```

Then confirm on a real device what is actually written — inspect `/data/data/com.ghostheart5.chronospark/shared_prefs/` on a rooted device or emulator and verify the values are ciphertext.

---

## SEC-04 · MEDIUM · Dual authentication providers

`firebase_auth: ^6.5.4` and `supabase_flutter: ^2.16.0` are both used. Supabase RLS keys entirely off `auth.uid()` — a Supabase-issued UUID — so Supabase must be the identity of record for any data access to work.

**Security-relevant risk:** sign-out completeness. If signing out clears one provider but not the other, a device retains a valid session for a user who believes they have signed out. On a shared or lost device that is a real account-takeover vector.

**Fix:** Ensure sign-out clears Supabase session, Firebase session, `flutter_secure_storage`, and all Hive boxes and `SharedPreferences` keys holding user-scoped data. Add an integration test asserting that after sign-out, both `Supabase.instance.client.auth.currentSession` and `FirebaseAuth.instance.currentUser` are null and no user data remains locally. See `FIREBASE_AUDIT.md` FB-03 for the architectural dimension.

---

## SEC-05 · LOW · `.env` as a bundled asset invites future exposure

**File:** `pubspec.yaml:114-115`

```yaml
  assets:
    - .env
```

Everything in a Flutter `assets:` list is packed into the APK/AAB and extractable with `unzip`. Today this is **safe** — the file contains no secrets, and SEC-A neutralizes tampering for risk-bearing keys.

**Why it still warrants a finding:** the pattern is a trap for the next developer. `.env` is the conventional place to put secrets, it is gitignored (which signals "secrets go here"), and the file's own header even warns *"Values here are embedded in the built app… never put a service-role key or signing material in a client .env."* That warning exists because the author recognized the hazard. A future contributor adding `CHRONOSPARK_SOME_API_KEY=sk-live-…` to `.env` would ship it publicly with no build error, no CI failure, and no review signal.

`scripts/security_secret_guard.ps1` exists and **is** invoked by CI (`android-release.yml:26`), which is a meaningful mitigation — the effectiveness depends on its pattern coverage, which should be reviewed against the specific key formats in use (`sk-ant-`, `eyJ`, `AIza`, `-----BEGIN`).

**Fix (defence in depth):**
- Rename the asset to `.env.public` or `app_config.env` to break the "secrets live here" association.
- Move all secret-bearing configuration exclusively to `--dart-define`, and keep the asset for non-sensitive defaults only.
- Add a CI assertion that the asset contains no value matching a secret pattern, failing the build rather than warning.

---

## SEC-06 · LOW · `supabase/.temp/` is committed

`git ls-files supabase/` returns nine `.temp/` files including `linked-project.json` (project ref, name, organization ID and slug), `project-ref`, and `pooler-url`.

**Verified: no password in `pooler-url`.** The connection string carries user and host only.

**Impact:** Low. The project ref appears in the client Supabase URL regardless and is not secret. Disclosed: organization ID/slug and exact region (`aws-1-us-west-2`) — mild reconnaissance value. These are CLI-local state files that should not be versioned.

**Fix:** Add `supabase/.temp/` to `.gitignore`; `git rm -r --cached supabase/.temp`.

---

## SEC-07 · LOW · `security definer` search path

**Files:** `202607110001_profiles.sql:56-57` · `20260712143000_resilient_handle_new_user.sql:4-5`

`set search_path = public` rather than the hardened `set search_path = ''`. Mitigated by fully-qualified object names inside the function bodies and by Postgres 17 revoking `CREATE` on `public` from `PUBLIC` by default. Detail in `SUPABASE_AUDIT.md` SUP-07.

---

## SEC-08 · INFO · Privacy policy and account deletion

Privacy artifacts exist in several places: `privacy/`, `privacy-policy/`, `privacy.html`, `assets/legal/privacy_policy.txt`, and `SECURITY.md`.

**Two items to confirm before submission:**

1. **Does the policy match what the code does?** This audit establishes the actual data flows: task and session content to Supabase; behavioural metrics (`tasks_created`, `tasks_completed`, `momentum_peak`, `device_id`) to `user_daily_metrics`; **user-generated content to Anthropic** via the AI proxy; crash traces to Crashlytics; events to Firebase Analytics. The AI disclosure is the one most often missed — users should be told their task content is processed by a third-party LLM provider, and ideally given an opt-out.

2. **Account deletion.** `.env` declares `CHRONOSPARK_ACCOUNT_DELETE_ENDPOINT` and `android-release.yml:126` passes it as a dart-define, but **no `account-delete` function exists** under `supabase/functions/` (only `ai-proxy` and `verify-receipt`). If the endpoint is not deployed, in-app deletion fails. Google Play **requires** both an in-app deletion path and a web URL for apps supporting account creation — this is a policy gate, not an optional feature. See `GOOGLE_PLAY_AUDIT.md` GP-09.

**Consent:** `CHRONOSPARK_ENABLE_ANALYTICS` and `CHRONOSPARK_ENABLE_CRASH_REPORTING` both default to `false` — the privacy-respecting default. Confirm the toggle is wired to a user-facing consent choice, not only to build configuration; under GDPR, analytics generally requires consent, while crash reporting is usually defensible as legitimate interest.

---

## A. Verified-clean areas

Checked and found sound — recorded so the absence of a finding is not mistaken for an absence of review.

### Network

| Check | Result |
|---|---|
| Cleartext `http://` URLs in Dart source | **None** (excluding XML namespace URIs and localhost) |
| `badCertificateCallback` / `HttpOverrides` | **None** — no certificate validation bypass anywhere |
| `usesCleartextTraffic` | `false` (`AndroidManifest.xml:27`) |

External hosts contacted at runtime: `<project>.supabase.co` (REST, Auth, Storage, Functions), `api.anthropic.com` (server-side only, via the proxy), `androidpublisher.googleapis.com` and `oauth2.googleapis.com` (server-side only), Firebase endpoints, Google Play Billing (IPC, not network). **The client never holds a third-party provider key** — every privileged call is brokered by an edge function.

### Cryptography

`encrypt: ^5.0.3` is declared but has **zero import sites** (`DEPENDENCY_AUDIT.md` DEP-05). This eliminates a whole class of finding by construction: there is no hand-rolled encryption, no hardcoded IV or key, no ECB mode, and no static salt, because no encryption code exists.

`crypto: ^3.0.3` is used at one site. Server-side, `verify-receipt/index.ts:49-54` uses `crypto.subtle.digest("SHA-256", …)` to hash purchase tokens before storage — correct: the raw token is never persisted, and SHA-256 is appropriate for a high-entropy opaque token (this is not password hashing, so the absence of a KDF is correct).

`verify-receipt/index.ts:113-164` implements RS256 service-account JWT signing via `crypto.subtle.importKey("pkcs8", …)` and `crypto.subtle.sign("RSASSA-PKCS1-v1_5", …)` — the correct primitive, using the platform crypto API rather than a hand-rolled implementation.

### Configuration loading

`lib/app/startup/app_bootstrap.dart:140-147`:

```dart
Future<void> _loadDotEnv() async {
  try {
    await dotenv.load(fileName: '.env');
    Logger.info('Loaded local .env configuration.');
  } on Object catch (error) {
    Logger.info('No local .env loaded: $error');
  }
}
```

Wrapped in `try`/`catch` — a missing or malformed `.env` degrades gracefully instead of crashing at launch. `_dotenvValue` (`env.dart:394`) is additionally try-guarded, so reads before load complete do not throw. Blank values correctly fall through to the `--dart-define` (`env.dart:367`), which is why CI's Supabase URL and endpoint defines take effect despite the blank asset values.

### Production readiness gate

`env.dart:293-311` implements `productionReadinessIssues()`, enumerating: crash reporting disabled, mock login enabled, global mock mode enabled, paywall-disabled override, tester full access. CI enables enforcement conditionally (`android-release.yml:110-115`) and **emits a warning when it disables it** for missing secrets — visible rather than silent. Good.

### Local storage tiering

| Store | Sites | Contents |
|---|---|---|
| `flutter_secure_storage` | 3 | Tokens / sensitive values — see SEC-03 |
| Hive | 13 | Structured domain data |
| `SharedPreferences` | 23 | Settings and flags |

The tiering is appropriate. **One item to confirm:** premium/entitlement state must not be cached in `SharedPreferences` or Hive as the authoritative source — a rooted user can edit both. A targeted search found no such writes, suggesting entitlement derives from the verified subscription state, which is correct. Confirm this holds as the paywall evolves; treat any local cache strictly as a non-authoritative offline hint. See `GOOGLE_PLAY_AUDIT.md` §C.

---

## Priority

1. **`SUP-01`** (in `SUPABASE_AUDIT.md`) — the cross-tenant RLS read is the only CRITICAL in the system. Fix first, independent of any release.
2. **SEC-01** — blank `CHRONOSPARK_VERBOSE_LOGS`, add the dart-define, move it to `_readRiskBool`, and audit log call sites for PII.
3. **SEC-02** — remove the client-controlled system prompt.
4. **SEC-03, SEC-04** — pin secure-storage options; verify sign-out completeness.
5. **SEC-05 – SEC-08** — hardening and compliance confirmation.
