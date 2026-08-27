# Error Handling & Reliability Audit Report

**Date:** June 24, 2026  
**Status:** Audit Complete | Mixed Coverage | Improvements Recommended  
**Scope:** Network failures, API/DB errors, user-facing error messaging, retry strategies, offline resilience

---

## 1. Executive Summary

**Current State:** Good foundational error handling infrastructure with solid retry patterns, sanitization, and offline queuing. However, gaps exist in error coverage, user guidance, and consistency across features.

**Risk Areas:**
- ⚠️ **HIGH:** Paywall initialization failures not user-visible; premium access silently degrades
- ⚠️ **HIGH:** AI service errors occasionally swallowed; user sees "Network unavailable" without root cause
- ⚠️ **MEDIUM:** No user-friendly error recovery suggestions (e.g., "Check connection" vs technical details)
- ⚠️ **MEDIUM:** Inconsistent error display (SnackBars vs inline messages; missing error page for startup)
- ⚠️ **MEDIUM:** Some error scenarios not tested (e.g., corrupted secure storage, permission denials)

**Strengths:**
- ✅ **Network resilience:** 3-attempt retry with exponential backoff + server-provided retry-after
- ✅ **Offline recovery:** Deferred queues for paywall and AI services; automatic replay on network recovery
- ✅ **Sensitive data protection:** Email, tokens, API keys redacted before display/logging
- ✅ **Auth rate limiting:** Progressive backoff after failed sign-in attempts
- ✅ **Storage recovery:** Corrupt data detected and reseeded from defaults

---

## 2. Detailed Analysis

### 2.1 Network Error Handling ✅ Good

**File:** `lib/core/utils/network_resilience.dart`

**Current Implementation:**
```dart
// 3 attempts with exponential backoff
// Retries on: 408 (Timeout), 425 (Too Early), 429 (Rate Limited), 5xx (Server Error)
// Backoff: 350ms + jitter → 900ms + jitter → 1500ms + jitter
// Server Retry-After header respected (clamped 1-30s)
```

**Coverage:**
- ✅ HTTP timeouts (12s default)
- ✅ ClientExceptions (connection lost, DNS failure)
- ✅ Server-provided retry-after delays
- ✅ Jitter to prevent thundering herd

**Gaps:**
- ⚠️ No distinction between permanent (4xx client) vs transient (5xx) errors in caller
- ⚠️ All non-retryable errors rethrown without context
- ⚠️ No circuit breaker for repeatedly failing services

**Example Usage:**
```dart
// AI Service
final http.Response response = await NetworkResilience.runHttpWithRetry(
  () => _client.post(...).timeout(Duration(seconds: 8)),
  timeout: const Duration(seconds: 12),
  maxAttempts: 3,
);

// Result: caller receives Exception or response (no Result type)
```

---

### 2.2 API/Database Failure Handling ⚠️ Inconsistent

#### 2.2.1 Paywall Receipt Verification

**File:** `lib/data/services/paywall_receipt_verifier.dart`

**Handles:**
- ✅ Network failures → deferred queue
- ✅ Permanent failures (401, 403) → invalid (rejected)
- ✅ Transient failures (408, 429, 5xx) → deferred (queued)
- ✅ Queue persistence in secure storage
- ✅ Automatic replay on `replayPendingVerifications()`

**Gaps:**
- ⚠️ No timeout-specific handling (uses 12s network timeout)
- ⚠️ Invalid status silently discards receipt (no user notification)
- ⚠️ If endpoint misconfigured, silent failure during verification

```dart
enum ReceiptVerificationStatus { verified, invalid, deferred }

// Caller must check status; no typed Result
final ReceiptVerificationStatus status = await verifyPurchaseStatus(purchase);
if (status == ReceiptVerificationStatus.deferred) {
  await queuePendingVerification(purchase);
  // Show user: "Purchase verification pending..."
}
```

#### 2.2.2 AI Service Request Handling

**File:** `lib/data/services/si_ai_service.dart`

**Handles:**
- ✅ Network failures → deferred queue (408, 429, 5xx)
- ✅ Rate limiting with sliding-window counter
- ✅ Temporary blocking after 3+ consecutive failures
- ✅ Request queue persistence
- ✅ Automatic replay on new request or bootstrap

**Failure Escalation Logic:**
```dart
_consecutiveFailures tracking:
  1-2 failures: 5s block
  3 failures: 10s block
  4 failures: 20s block
  5+ failures: 60s block

// After block expires, tries again
// If succeeds, resets counter; if fails, escalates
```

**Gaps:**
- ⚠️ No response content validation (e.g., empty choices array)
- ⚠️ Rate limit block user-visible but no clear retry guidance
- ⚠️ Error messages vary: "temporarily overloaded" vs "request rate limit exceeded"

#### 2.2.3 Authentication Errors

**File:** `lib/data/services/auth_service.dart`

**Handles:**
- ✅ Failed sign-in attempts → progressive backoff (2s to 60s)
- ✅ Credential validation (wrong password, user not found)
- ✅ Account deletion requires re-authentication
- ✅ Firebase auth errors propagated with codes

**Gaps:**
- ⚠️ No retry mechanism for transient auth failures (network timeout during sign-in)
- ⚠️ Auth errors not wrapped in custom Result type
- ⚠️ No offline auth state recovery

#### 2.2.4 Workspace Data Persistence

**File:** `lib/data/services/workspace_store_service.dart`

**Handles:**
- ✅ Corrupt JSON → logged and reseeded from defaults
- ✅ Type mismatches → caught and reseeded
- ✅ Missing assets → graceful empty state fallback
- ✅ Schema evolution with type conversion

**Gaps:**
- ⚠️ Only TypeError caught (other exceptions swallowed)
- ⚠️ Seed loading failures silent (catches all exceptions)
- ⚠️ No user notification if data loss detected and reset

---

### 2.3 User-Facing Error Messaging ⚠️ Partial

**Current Patterns:**

1. **Error Sanitization:** ✅ Good
   ```dart
   // Redacts: emails, bearer tokens, API keys, sensitive field names
   'Authorization: Bearer eyJ...' → 'Authorization: Bearer [redacted-token]'
   'serverVerificationData: [...]' → '[redacted-sensitive-field]'
   ```

2. **Error Display:**
   - ✅ SnackBars for paywall operations (purchase, restore, plan changes)
   - ✅ Inline error panels in Console and Nexus pages
   - ✅ Settings page displays runtimeError inline
   - ⚠️ No error page for startup failures
   - ⚠️ No error history/log for debugging

3. **Error Messages:**
   - ✅ Provide context: "Purchase verification deferred due to network conditions..."
   - ✅ Provide guidance: "Premium status will refresh automatically once connectivity stabilizes"
   - ⚠️ Inconsistent phrasing across features
   - ⚠️ No suggest-next-action guidance (e.g., "Retry" button)

**Examples:**

Good:
```dart
'Verification deferred due to network conditions. Premium status will refresh automatically once connectivity stabilizes.'
'AI service is temporarily overloaded. Retry in 15s.'
```

Needs improvement:
```dart
'AI network unavailable.' // What to do?
'Could not process console input.' // Why? Retry? Check format?
'Purchase failed. Please try again.' // Still failing? Contact support?
```

---

### 2.4 Retry & Fallback Strategies

#### 2.4.1 Explicit Retries ✅ Good

| Layer | Mechanism | Config | Status |
|-------|-----------|--------|--------|
| Network | `NetworkResilience.runHttpWithRetry()` | 3 attempts, 350-1500ms backoff | ✅ Implemented |
| Paywall Verification | Deferred queue + replay | Replay on new purchase + bootstrap | ✅ Implemented |
| AI Requests | Deferred queue + replay | Replay on new request + bootstrap | ✅ Implemented |
| Sign-In | Progressive backoff | 2s to 60s after failed attempts | ✅ Implemented |

#### 2.4.2 Fallback Strategies

| Scenario | Fallback | Status |
|----------|----------|--------|
| Network timeout on startup | Cached premium status | ✅ Implemented |
| Store unavailable | Cached products, disable purchase | ✅ Implemented |
| Corrupt workspace data | Reseed from seed JSON | ✅ Implemented |
| AI service down | Offer local mock response (dev mode) | ✅ Implemented |
| Auth state unavailable | Show login screen | ✅ Implemented |

#### 2.4.3 Missing Retry Patterns ⚠️

1. **Transient Auth Failures:**
   ```dart
   // Current: throws immediately on timeout
   final UserCredential credential = await _auth.signInWithEmailAndPassword(...);
   
   // Should: retry with backoff for network timeouts
   // (currently only rate-limits on credential failure)
   ```

2. **Telemetry/Analytics Upload Failures:**
   ```dart
   // Current: silent failure if TelemetryService can't upload
   // Should: queue events for retry (like AI/Paywall)
   ```

3. **Notification Permission Prompts:**
   ```dart
   // Current: asks once, silently disables if denied
   // Should: offer to re-prompt on settings open
   ```

---

### 2.5 Offline Resilience ✅ Good (Partial)

**Deferred Queue Pattern:**

```dart
// Paywall Receipt Verifier
// 1. Queue pending verifications on network failure
await queuePendingVerification(purchase);

// 2. Replay when network recovers
await replayPendingVerifications();

// 3. Integrate into bootstrap
_aiService.replayDeferredRequests();  // Called post-frame in bootstrap

// 4. Integration with PaywallService
_replayPendingReceiptVerifications();  // Called after new purchase
```

**Covered:**
- ✅ Paywall verification
- ✅ AI request generation
- ❌ Telemetry events
- ❌ Analytics events
- ❌ Settings/config changes

**Gaps:**
- ⚠️ No telemetry event queue (fires immediately, fails silently)
- ⚠️ No analytics event queue (similarly synchronous)
- ⚠️ Analytics failures can't cause user-visible errors, but pollutes logs

---

### 2.6 Error Testing Coverage

**Current Tests:**

| Area | Tests | Coverage |
|------|-------|----------|
| Paywall deferred queue | 3 tests | network failure → queue → replay ✅ |
| AI deferred queue | 3 tests | network failure → queue → replay ✅ |
| Deep link parsing | 4 tests | malformed → graceful ✅ |
| Workspace recovery | 3 tests | corrupt JSON → reseed ✅ |
| **Auth retry** | ❌ 0 | No tests for backoff |
| **Network timeout** | ❌ 0 | No tests for retry logic itself |
| **Startup error handling** | ❌ 0 | No tests for error display on startup |
| **Permission denial** | ❌ 0 | No tests for notification perms |
| **Secure storage failure** | ❌ 0 | No tests for read/write errors |

---

## 3. Gaps & Improvements

### 3.1 Critical Issues

**1. Paywall Initialization Silently Fails**

**Current:**
```dart
// If store unavailable, uses cached premium
// No user notification of degraded state
```

**Impact:** User loses premium features without warning if store temporarily offline during bootstrap.

**Fix:**
```dart
// Add user notification
if (!available) {
  onPremiumChanged(cachedPremium);
  onError?.call(
    '⚠️ App Store connection lost. Using cached premium status. '
    'Your purchases will verify when connectivity recovers.'
  );
}
// AppState should surface this as a banner: 
// runtimeError = '[INFO] Store connection unstable...'
```

**2. Error Messages Lack Actionability**

**Current:**
```dart
'Purchase failed. Please try again.'
'Could not process console input.'
```

**Impact:** User doesn't know if retry will help, or if it's a client-side validation error.

**Fix:**
```dart
// Add structured error types with recovery guidance
sealed class UserFacingError {
  final String message;
  final String? retryGuidance;
}

class NetworkError extends UserFacingError {
  NetworkError() : super(
    message: 'Network connection lost.',
    retryGuidance: 'Check WiFi/mobile signal and retry.',
  );
}

class ValidationError extends UserFacingError {
  ValidationError(String field) : super(
    message: 'Invalid $field format.',
    retryGuidance: null, // Don't suggest retry
  );
}
```

**3. No Startup Error Page**

**Current:**
```dart
// If bootstrap fails, shows generic "Startup partially failed" message
// User sees blank screen with no guidance
```

**Impact:** User confused; may force-close app thinking it's hung.

**Fix:**
```dart
// Add ErrorRecoveryScreen
class ErrorRecoveryScreen extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Icon(Icons.error_outline, size: 64),
          Text('ChronoSpark encountered a problem'),
          Text(error),
          ElevatedButton(
            onPressed: onRetry,
            child: Text('Retry'),
          ),
          TextButton(
            onPressed: () => /* Clear app data */,
            child: Text('Clear app data and restart'),
          ),
        ],
      ),
    );
  }
}
```

---

### 3.2 High-Priority Improvements

**1. Telemetry & Analytics Event Queuing**

**Issue:** Events fire immediately; if network fails, lost forever (no retry).

**Solution:**
```dart
// New: EventQueueService
class EventQueueService {
  static const String _eventsQueueKey = 'telemetry_events_queue_v1';
  
  Future<void> queueEvent(String name, Map<String, Object>? params) async {
    final List<Map<String, dynamic>> queue = await _readQueue();
    queue.add({
      'name': name,
      'params': params,
      'timestamp': DateTime.now().toIso8601String(),
    });
    await _writeQueue(queue);
    
    // Try to flush immediately; if fails, will retry on next opportunity
    await flushQueue();
  }
  
  Future<void> flushQueue() async {
    final List<Map<String, dynamic>> queue = await _readQueue();
    for (final event in queue) {
      try {
        await TelemetryService.instance.logEvent(
          event['name'] as String,
          parameters: event['params'] as Map<String, Object>?,
        );
      } on Exception {
        break; // Stop; will retry rest on next flush
      }
    }
  }
}

// Integrate into bootstrap and NetworkMonitor
// Flush queue whenever connectivity recovered
```

**2. Transient Auth Retry**

**Issue:** Sign-in times out → immediately fails. Should retry with backoff.

**Current:**
```dart
final UserCredential credential = await _auth.signInWithEmailAndPassword(...);
// If timeout, throws immediately
```

**Fix:**
```dart
Future<UserCredential> signInWithRetry({
  required String email,
  required String password,
  int maxAttempts = 2,
}) async {
  late Exception lastError;
  
  for (int i = 0; i < maxAttempts; i++) {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      ).timeout(const Duration(seconds: 15));
    } on TimeoutException catch (e) {
      lastError = FirebaseAuthException(
        code: 'network-timeout',
        message: 'Sign-in timed out. Retrying...',
      );
      if (i < maxAttempts - 1) {
        await Future<void>.delayed(Duration(seconds: 2 << i));
      }
    } on FirebaseAuthException {
      rethrow; // Don't retry permanent failures
    }
  }
  throw lastError;
}
```

**3. Structured Error Recovery**

**Issue:** Errors display but no clear path to recovery.

**Fix:**
```dart
// lib/core/errors/error_recovery.dart
abstract class ErrorRecoveryAction {
  String get label;
  Future<void> execute();
}

class RetryAction extends ErrorRecoveryAction {
  final Future<void> Function() operation;
  
  @override
  String get label => 'Retry';
  
  @override
  Future<void> execute() => operation();
}

class OpenSettingsAction extends ErrorRecoveryAction {
  @override
  String get label => 'Open Settings';
  
  @override
  Future<void> execute() async {
    // Navigate to settings page
  }
}

// Update AppFailure to include recovery actions
class AppFailure {
  final String message;
  final List<ErrorRecoveryAction> recoveryActions; // New
}

// UI displays buttons for each action
ErrorPanel(
  error: error,
  onAction: (action) => action.execute(),
)
```

---

### 3.3 Medium-Priority Improvements

**1. Circuit Breaker for Failing Services**

Add after 5+ consecutive failures within 5 minutes:
```dart
// AI Service: stop querying; return cached response or error
// Paywall: stop verifying; rely on cache
// Auth: extend lockout period
```

**2. Error Analytics Dashboard**

Track and surface:
- Most common errors (top 10)
- Error trends (spike detection)
- User impact (# users affected)
- Recovery success rate

**3. Network Monitoring**

```dart
class NetworkMonitor {
  late StreamSubscription<ConnectivityResult> _subscription;
  
  void _onConnectivityChange(ConnectivityResult result) {
    if (result == ConnectivityResult.none) {
      // Mark network offline; suppress non-critical error messages
    } else {
      // Network recovered; trigger all deferred queues
      await _paywall.replayPendingVerifications();
      await _ai.replayDeferredRequests();
      await _telemetry.flushQueue();
    }
  }
}
```

**4. User-Friendly Error Codes**

Replace technical errors:
```
Before:
'FirebaseAuthException: invalid-credential'

After:
'Email or password is incorrect. Try again or reset your password.'
```

---

## 4. Recommendations

### Immediate (Next Sprint)

1. ✅ **Add telemetry/analytics event queue** (30min implementation, high impact)
2. ✅ **Improve paywall error messaging** (15min, critical visibility)
3. ✅ **Add error recovery actions to UI** (2-4hrs, improves UX)
4. ✅ **Implement transient auth retry** (1-2hrs, prevents user-visible failures)

### Short-term (2-3 Sprints)

5. ✅ **Add startup error recovery screen** (2-3hrs, critical for robustness)
6. ✅ **Implement network connectivity monitor** (3-4hrs, enables offline queue flushing)
7. ✅ **Add structured error types with recovery guidance** (4-6hrs, improves consistency)
8. ✅ **Expand error test coverage** (4-5hrs, prevents regressions)

### Long-term (Future)

9. ⚠️ Circuit breaker pattern for services
10. ⚠️ Error analytics dashboard
11. ⚠️ In-app error reporting with user consent
12. ⚠️ User-facing error code translations

---

## 5. Code Examples

### Example 1: Enhanced Error Display

```dart
// lib/ui/widgets/error_panel.dart
class ErrorPanel extends StatelessWidget {
  final AppFailure error;
  final List<ErrorRecoveryAction> actions;
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        border: Border.all(color: Colors.red),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red),
              SizedBox(width: 12),
              Expanded(child: Text(error.message)),
            ],
          ),
          if (actions.isNotEmpty) ...[
            SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                for (final action in actions)
                  Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: ElevatedButton(
                      onPressed: () async {
                        try {
                          await action.execute();
                          // Success; error auto-clears
                        } on Exception catch (e) {
                          // Show retry error
                        }
                      },
                      child: Text(action.label),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
```

### Example 2: Event Queue Service

```dart
// lib/core/system/event_queue_service.dart
class EventQueueService {
  static const String _queueKey = 'event_queue_v1';
  final SecureStore _store;
  
  Future<void> queueEvent(String name, Map<String, Object>? params) async {
    final List<Map<String, dynamic>> queue = await _readQueue();
    queue.add({
      'name': name,
      'params': params,
      'timestamp': DateTime.now().toIso8601String(),
      'attempts': 0,
    });
    await _writeQueue(queue);
  }
  
  Future<void> flushQueue() async {
    if (!connectivity.isConnected) return;
    
    final List<Map<String, dynamic>> queue = await _readQueue();
    final List<Map<String, dynamic>> failed = [];
    
    for (final event in queue) {
      try {
        await TelemetryService.instance.logEvent(
          event['name'] as String,
          parameters: event['params'] as Map<String, Object>?,
        );
      } on Exception {
        final int attempts = (event['attempts'] as int? ?? 0) + 1;
        if (attempts < 3) {
          event['attempts'] = attempts;
          failed.add(event);
        }
        // Stop; will retry rest next time
        break;
      }
    }
    
    await _writeQueue(failed);
  }
  
  Future<List<Map<String, dynamic>>> _readQueue() async {
    final String? raw = await _store.readString(_queueKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .cast<Map<String, dynamic>>();
    } on Exception {
      return [];
    }
  }
  
  Future<void> _writeQueue(List<Map<String, dynamic>> queue) async {
    await _store.writeString(_queueKey, jsonEncode(queue));
  }
}
```

---

## 6. Summary

| Category | Status | Key Findings |
|----------|--------|--------------|
| **Network Resilience** | ✅ Good | 3-attempt retry with backoff; respects server delays |
| **API Error Handling** | ⚠️ Inconsistent | Paywall/AI good; Auth/Telemetry gaps; no transient retry |
| **Error Messaging** | ⚠️ Needs work | Sanitized well; lacks actionability and guidance |
| **Offline Recovery** | ✅ Good | Deferred queues for paywall/AI; missing telemetry |
| **Error Testing** | ⚠️ Minimal | Good coverage for queues; gaps in network/auth scenarios |
| **User Guidance** | ⚠️ Poor | No startup error page; inconsistent recovery actions |

**Overall:** Solid foundation with network resilience and offline recovery patterns. Immediate focus: improve error visibility, add actionable recovery guidance, and implement event queuing for telemetry/analytics.

**Effort to Fix All Issues:** ~30-40 hours across 2-3 sprints.
