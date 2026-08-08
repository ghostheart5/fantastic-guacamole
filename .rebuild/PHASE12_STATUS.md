# Phase 12 Status — Edge-Case Test Suite

Date: 2026-08-08

## Scope

Phase 12 adds the edge-case unit tests called out in the Phase 11 gate notes
and the Audit V2 Scorecard. No production code is changed. All three test
targets had zero coverage before this phase.

---

## Changes Made

### 1 · `CancelToken` unit tests

**File:** `test/core/utils/cancel_token_test.dart`

The `CancelToken` utility was introduced in Phase 11. This test file provides
complete unit coverage for its public API:

| Test | Assertion |
|------|-----------|
| starts uncancelled | `isCancelled` is false on a fresh token |
| `cancel()` sets isCancelled | `isCancelled` becomes true after `cancel()` |
| `cancel()` is idempotent | calling `cancel()` twice does not throw |
| `throwIfCancelled()` silent when not cancelled | no exception before `cancel()` |
| `throwIfCancelled()` throws `CancelledException` | exception type is correct |
| `throwIfCancelled()` remains throwing | second call after `cancel()` still throws |
| `CancelledException.toString()` | non-empty, contains type name |
| independent tokens | cancelling one does not affect another |

---

### 2 · `parseSecureHttpsEndpoint` unit tests

**File:** `test/data/network/secure_endpoint_test.dart`

`parseSecureHttpsEndpoint` was present in production code but had no test
coverage. Tests verify that the function correctly:

| Test | Assertion |
|------|-----------|
| valid HTTPS URL | returns non-null Uri with correct host |
| URL with path and query | accepted |
| HTTP URL | returns null |
| URL with embedded user info | returns null |
| empty string | returns null |
| whitespace-only string | returns null |
| plain hostname (no scheme) | returns null |
| non-URL string | returns null |
| leading/trailing whitespace | trimmed, then parsed correctly |
| HTTPS URL with empty host | returns null |

---

### 3 · Prompt-length cap tests in `SIAIService`

**File:** `test/engine/si/si_ai_service_test.dart` (extended)

A `_CapturingEngineService` subclass overrides `handleUserInput` to record the
`SIInputPacket` the engine receives, then delegates to `super` for the real
response. This lets the tests assert on exactly what text arrived at the engine
boundary — verifying the 5,000-character cap applied by `SIAIService.sendText`.

| Test | Assertion |
|------|-----------|
| text at exactly 5,000 chars | passed unchanged; engine receives 5,000 chars |
| text over 5,000 chars (7,500) | truncated to exactly 5,000 chars |
| short text | passed unchanged |

---

## Protected-File Integrity

All six tracked files are unchanged:

```
OK: CODE_OF_CONDUCT.md
OK: LICENSE
OK: SECURITY.md
OK: README.md
OK: web/privacy.html
OK: assets/legal/privacy_policy.txt
```

---

## Phase 12 gate

Phase 12 is complete.

- `CancelToken` has full unit coverage.
- `parseSecureHttpsEndpoint` has full boundary-condition coverage.
- `SIAIService.sendText` prompt-length cap is verified at the engine boundary.

No production code was modified. All tests are pure Dart (no platform channel
or Firebase dependencies) and run under `flutter test` without additional setup.
