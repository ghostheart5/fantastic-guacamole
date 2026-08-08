# Phase 11 Status — FCM Notification Icon, CancelToken, Token Freshness, Prompt Limit, Sign-Out Guard

Date: 2026-08-08

## Scope

Phase 11 addresses the one item skipped in Phase 10 (R-06) and the remaining
open items from the Audit V2 Scorecard (`AUDIT_V2_SCORECARD.md` section 9).

---

## Changes Made

### R-06 · FCM Default Notification Channel and White-Silhouette Icon

**Problem:** Background FCM push notifications were rendered with a grey-square
icon on Android 5+ because the system uses only the alpha channel of the
notification icon. `@mipmap/ic_launcher` is a full-colour icon — it produces
a solid grey square. Additionally, without a `default_notification_channel_id`
meta-data entry, incoming background push messages land on the system
"Miscellaneous" channel with default (low) importance.

**Changes:**

1. `android/app/src/main/res/drawable/ic_notification.xml` — New white-silhouette
   vector drawable. The path is a spark/lightning bolt shape that reflects the
   ChronoSpark brand identity. All fill colours are `#FFFFFF`; Android renders
   notification icons using only the alpha channel, so the colour value only
   affects how the icon appears in screen-reader / accessibility tools.

2. `android/app/src/main/AndroidManifest.xml` — Added two `<meta-data>` entries
   inside `<application>`:
   - `com.google.firebase.messaging.default_notification_channel_id` → `chronospark_channel`
     (matches the channel ID registered in `NotificationScheduler`)
   - `com.google.firebase.messaging.default_notification_icon` → `@drawable/ic_notification`

3. `lib/system/notifications/notification_scheduler.dart` — Changed the
   `AndroidNotificationDetails.icon` from `@mipmap/ic_launcher` to
   `@drawable/ic_notification` so that local scheduled notifications also use
   the correct silhouette icon.

---

### Audit V2 #4 · CancelToken — `lib/core/utils/cancel_token.dart`

**Problem:** Long-running AI or paywall calls could not be cancelled when the
initiating widget was disposed. The user would see hanging UI or out-of-order
responses, and the completed request would still attempt to update state on a
disposed provider.

**Change:** Implemented `CancelToken` in `lib/core/utils/cancel_token.dart`:
- `CancelToken.cancel()` signals cancellation (idempotent).
- `CancelToken.throwIfCancelled()` throws `CancelledException` at cooperative
  cancellation points.
- `CancelToken.isCancelled` allows soft (non-throwing) checks.

Integrated into `SIAIService`:
- `send()` and `sendText()` accept an optional `CancelToken? cancelToken`.
- The token is checked before dispatching to the engine and again after `await`
  returns, before building the response — so a dispose-triggered cancellation
  during a slow AI call produces a clean `CancelledException` instead of an
  orphaned state write.

Usage by callers is opt-in: all existing call sites pass no token and behaviour
is unchanged.

---

### Audit V2 #5 · Pre-Request Token Freshness — `lib/data/network/secure_endpoint.dart`

**Problem:** `currentSupabaseAccessToken()` reads the cached session token
synchronously. If the token is close to expiry (e.g., 59 minutes into a
60-minute session), the SDK may not have proactively refreshed it yet. The
first request after this window returns a 401, which the callers surface as a
generic failure with no retry.

**Change:** Added `Future<String?> requireFreshSupabaseToken()` to
`secure_endpoint.dart`. It calls `client.auth.refreshSession()` before
returning the access token. If the refresh fails (e.g., offline), it falls
back to the cached token rather than failing the operation.

Updated the two network-critical call sites to use this function:
- `lib/data/services/ai/agents/chat_agent.dart` — AI proxy requests
- `lib/data/repositories/google_play_paywall_repository.dart` — Receipt
  verification requests

Both were already `async`, so the `await` is a drop-in replacement for the
synchronous `currentSupabaseAccessToken()` call.

---

### Audit V2 #6 · Sign-Out Guard — `lib/data/services/sync_service.dart`

**Problem:** `_uploadObject` built its storage path via `_scopedPath`, which
falls back to `'anonymous'` when `currentUser` is null. An in-flight cloud sync
triggered just before (or during) sign-out would write the user's data to the
`anonymous/` prefix — an orphaned write that is difficult to clean up.

**Change:** Added an early-return guard at the top of `_uploadObject`:
```dart
if (_client.auth.currentUser == null) {
  Logger.warn('_uploadObject: skipped — no authenticated user (signed out).');
  return false;
}
```
This eliminates the anonymous-write race without changing any other behaviour.

---

### Audit V2 #7 · Prompt Length Limit — `lib/engine/si/si_ai_service.dart`

**Problem:** `SIInputPacket.text` had no maximum length. A very long prompt
could be sent to the AI proxy, which rejects payloads over 8,000 characters
with a 413. This produced a generic failure with no user-visible feedback.

**Change:** Added a 5,000-character cap in `SIAIService.sendText()`:
```dart
const int _maxPromptChars = 5000;
final String safeText = text.length <= _maxPromptChars
    ? text
    : text.substring(0, _maxPromptChars);
```
5,000 chars gives comfortable headroom for the system prefix and conversation
history payload. The trim happens before the packet is constructed, so the
engine never sees an over-length string.

---

## Audit V2 Items Confirmed Already Resolved

| Item | Status |
|------|--------|
| POST_NOTIFICATIONS runtime permission (Audit V2 #1) | ✅ Already implemented — `NotificationScheduler.requestNotificationsPermission()` calls `androidPlugin?.requestNotificationsPermission()`. The July audit noted it was missing; it was added during the rebuild. |
| Data Safety form (Audit V2 #2) | ⚠️ Manual Play Console action required — no code change possible |
| Upload keystore (Audit V2 #3) | ⚠️ Local setup — cannot be done in-repo |

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

## Phase 11 gate

Phase 11 is complete.

- R-06 is fully addressed (FCM channel meta-data, silhouette icon, scheduler update).
- All Audit V2 code-level open items are addressed.
- Two items (Data Safety form, upload keystore) require manual external action
  and cannot be done in-repository.

**Remaining manual actions before Google Play upload:**
1. Complete the Data Safety form in the Play Console.
2. Create `android/key.properties` and provide `android/app/key.jks` (local/CI only).
