# Edge Cases Audit Report

**Date:** June 24, 2026  
**Status:** Audit Complete | Good Coverage | Gaps Identified  
**Scope:** Empty/null/malformed inputs, interrupted flows, session expiration

---

## 1. Executive Summary

**Current State:** Strong handling of common edge cases with good null safety and input validation patterns. Some gaps in session management, token refresh during operations, and concurrent operation safety.

**Risk Areas:**
- ⚠️ **MEDIUM:** Token expiration mid-operation (AI generation, paywall verification) — no refresh mechanism
- ⚠️ **MEDIUM:** User sign-out during async operation — no cancellation or state rollback
- ⚠️ **MEDIUM:** Concurrent operations (AsyncGate helps, but not all endpoints use it)
- ⚠️ **LOW:** Malformed deep links — gracefully handled but no user feedback
- ⚠️ **LOW:** Empty JSON arrays — caught but could offer better guidance

**Strengths:**
- ✅ **Null safety:** Comprehensive null checks (`?.`, `??`, `if (x == null)`)
- ✅ **Empty/whitespace trimming:** Consistently applied before validation
- ✅ **Malformed JSON handling:** FormatException and TypeError caught with reseed fallback
- ✅ **Input validation:** All user inputs trimmed and checked for empty
- ✅ **Concurrent operation safety:** AsyncGate used for critical state mutations
- ✅ **Widget lifecycle:** `mounted` checks in most async callbacks, proper dispose

---

## 2. Detailed Analysis

### 2.1 Empty/Null/Malformed Input Handling ✅ Good

#### 2.1.1 Console Input Validation

**File:** `lib/core/state/app_state.dart`

**Current Implementation:**
```dart
Future<void> updateFromConsole(String input) async {
  final String value = input.trim();  // ✅ Trim whitespace
  if (value.isEmpty) {               // ✅ Reject empty
    return;                           // ✅ Graceful exit
  }
  // ... process
}
```

**Coverage:**
- ✅ Empty strings rejected
- ✅ Whitespace-only input rejected
- ✅ Null-safe with trim() before isEmpty

**Example Behaviors:**
```
Input: ""           → Silently ignored ✅
Input: "   "        → Silently ignored ✅
Input: null         → Doesn't happen (passed as String) ✅
Input: "add:"       → Processed; title extracted and trimmed ✅
Input: "add:   "    → Title extracted but may be empty after trim (⚠️)
```

**Gap:**
```dart
// Current:
if (lower.startsWith('add:')) {
  final String title = value.substring(4).trim();
  if (title.isNotEmpty) { // ✅ Validated
    // create task
  }
}

// Works, but no feedback if user enters "add:" with no title
// Silently discards input
```

#### 2.1.2 Task Creation Validation

**File:** `lib/core/state/app_state.dart`

**Current:**
```dart
Future<void> createTask(String title) async {
  final String trimmed = title.trim();
  if (trimmed.isEmpty) {
    runtimeError = 'Task title cannot be empty.';  // ✅ User feedback
    notifyListeners();
    return;
  }
  // ... create task
}
```

**Coverage:**
- ✅ Empty titles rejected
- ✅ User notification on empty input
- ✅ Trimmed before validation

#### 2.1.3 Mission & Workspace Data JSON Parsing

**File:** `lib/data/services/mission_service.dart`

**Current Implementation:**
```dart
Future<List<MissionModel>> loadMissions() async {
  final String? raw = await _store.readString(_missionsKey);
  if (raw == null || raw.trim().isEmpty) {  // ✅ Null + empty check
    await saveMissions(_defaultMissions);
    return _defaultMissions;
  }
  
  try {
    final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .cast<Map<String, dynamic>>()
        .map((Map<String, dynamic> e) => MissionModel.fromJson(e))
        .toList();
  } on FormatException catch (error) {     // ✅ Catches malformed JSON
    Logger.error('Mission payload corrupt. Resetting defaults. $error');
    await saveMissions(_defaultMissions);
    return _defaultMissions;
  } on TypeError catch (error) {           // ✅ Catches shape mismatch
    Logger.error('Mission payload invalid shape. Resetting defaults. $error');
    await saveMissions(_defaultMissions);
    return _defaultMissions;
  }
}
```

**Coverage:**
- ✅ Null payloads → fallback to defaults
- ✅ Empty strings → fallback
- ✅ Invalid JSON → caught and reseeded
- ✅ Schema mismatches → caught and reseeded
- ✅ Recovery logging

**Similar Pattern Applied To:**
- `workspace_store_service.dart` (Creator, Temporal, SI workspaces) ✅
- `chronologs_service.dart` (loading chronologs) ✅

#### 2.1.4 Authentication Input Validation

**File:** `lib/data/services/auth_service.dart`

**Current:**
```dart
Future<void> deleteCurrentAccount({required String password}) async {
  final User? user = _auth.currentUser;
  if (user == null) {
    throw FirebaseAuthException(code: 'no-current-user', ...);
  }
  
  final String email = user.email?.trim() ?? '';  // ✅ Null-coalesce + trim
  if (email.isEmpty) {                            // ✅ Validate
    throw FirebaseAuthException(code: 'missing-email', ...);
  }
  
  if (password.trim().isEmpty) {                  // ✅ Validate password
    throw FirebaseAuthException(code: 'missing-password', ...);
  }
  // ... proceed
}
```

**Coverage:**
- ✅ Null email handled
- ✅ Empty password rejected
- ✅ Explicit error codes

#### 2.1.5 Deep Link Parsing

**File:** `lib/core/utils/deep_link_parser.dart`

**Current:**
```dart
Uri? normalizeSupportedDeepLink(Uri uri) {
  final String? target = _extractSupportedTarget(uri);
  if (target == null) {
    return null;  // ✅ Reject unsupported targets
  }
  return Uri.parse('chronospark://$target');  // ✅ Normalize
}

String? _extractSupportedTarget(Uri uri) {
  // Try query param
  final String? queryTarget = uri.queryParameters['target']?.trim();
  if (queryTarget != null && supportedDeepLinkTargets.contains(queryTarget)) {
    return queryTarget;  // ✅ Trim before validate
  }
  // Try path
  final String pathTarget = uri.pathSegments.firstOrNull?.toLowerCase().trim() ?? '';
  if (supportedDeepLinkTargets.contains(pathTarget)) {
    return pathTarget;
  }
  return null;  // ✅ Graceful rejection
}
```

**Coverage:**
- ✅ Malformed URIs → null return (caught by caller)
- ✅ Unsupported targets → null return
- ✅ Trimming applied
- ✅ Whitelist validation

**Gaps:**
- ⚠️ No user feedback when deep link is invalid (silently ignored)
- ⚠️ Error not logged for debugging

**Current Usage in Notification Delivery:**
```dart
void _handleDeepLinkPayload(String? payload) {
  if (payload == null || payload.trim().isEmpty) {
    return;  // ✅ Null/empty check
  }
  
  final Uri? uri = Uri.tryParse(payload.trim());  // ✅ Safe parsing
  if (uri == null) {
    return;  // ✅ Malformed URI rejected
  }
  
  if (_deepLinkHandler != null) {
    _deepLinkHandler!(uri);
  } else {
    _pendingDeepLinks.add(uri);  // ✅ Queue if handler not ready
  }
}
```

---

### 2.2 Interrupted Flows ⚠️ Partial Coverage

#### 2.2.1 Widget Lifecycle — mounted Checks ✅ Good

**Pattern:** Async operations check `mounted` before updating UI

**Files Using Pattern:**
- `main_shell.dart`: 3 mounted checks before setState/notifyListeners ✅
- `creator_home.dart`: 1 mounted check ✅
- `chronologs_home.dart`: 3 mounted checks ✅
- `temporal_ops_home.dart`: 1 mounted check ✅

**Example:**
```dart
Future<void> _loadData() async {
  final result = await service.fetch();
  if (!mounted) return;  // ✅ Check before setState
  setState(() => data = result);
}
```

**Dispose Methods:** All StatefulWidgets properly dispose controllers ✅

#### 2.2.2 Concurrent Operation Safety — AsyncGate ✅ Good

**File:** `lib/core/utils/async_gate.dart`

**Pattern:**
```dart
class AsyncGate<T> {
  Future<void> _tail = Future<void>.value();
  
  Future<T> run(Future<T> Function() operation) {
    // Serializes all operations; prevents concurrent mutations
    final Completer<T> completer = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        final T result = await operation();
        completer.complete(result);
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }
}
```

**Used For:**
- ✅ Console input updates (`_consoleUpdateGate` in AppState)
- ✅ Paywall status updates in PaywallService

**Gaps:**
- ⚠️ Not all async operations use gate (e.g., `createTask` directly mutations)
- ⚠️ No timeout on queued operations (could build up unbounded)
- ⚠️ No cancellation mechanism if user navigates away

#### 2.2.3 Operation Cancellation — Missing ❌

**Current State:** No mechanism to cancel in-flight operations

**Scenarios:**
```dart
// User taps "Generate response" then immediately closes console
// → Request still fires; response queued and shown later
// → Confusing UX if user has moved to different page

// User signs out while AI request is pending
// → Token may have expired; request will fail
// → Error shown but appears mid-flow

// User closes app during paywall initialization
// → In-progress async operations may not complete gracefully
// → Could leave inconsistent state
```

**Gap Example:**
```dart
// Current (no cancellation):
Future<String?> generateResponse({...}) async {
  final Result<String> result = await generateResponseSafe(...);
  // No way to cancel this; it will complete even if user navigates away
}

// Recommended pattern (not implemented):
Future<String?> generateResponse({required CancelToken cancel}) async {
  if (cancel.isCancelled) return null;
  final Result<String> result = await generateResponseSafe(...);
  if (cancel.isCancelled) return null; // Cancel point
  return result.value;
}
```

#### 2.2.4 Stream Subscriptions — Properly Cleaned Up ✅

**Pattern:**
```dart
// Main shell deep link subscription
StreamSubscription<Uri>? _externalDeepLinkSub;

@override
void dispose() {
  _externalDeepLinkSub?.cancel();  // ✅ Cleanup
  super.dispose();
}
```

**Applied To:**
- ✅ Deep link subscriptions (main_shell.dart)
- ✅ Notification subscriptions (notification_delivery_service.dart)
- ✅ Auth state changes (auth_gate.dart implicitly via StreamBuilder)

---

### 2.3 Token & Session Expiration Mid-Operation ⚠️ Gaps

#### 2.3.1 Token Refresh Mechanism

**Current Implementation:**

```dart
// auth_service.dart
Future<String?> getIdToken({bool forceRefresh = false}) async {
  return _auth.currentUser?.getIdToken(forceRefresh);  // ✅ Refresh support
}
```

**Uses:**
```dart
// ai_service.dart
final Future<String?> Function() _tokenProvider =
    tokenProvider ??
    (() async => FirebaseAuth.instance.currentUser?.getIdToken());

// During request:
final String? idToken = await _tokenProvider();
if (idToken == null) {
  return Result.err(UnexpectedFailure('AI request requires an authenticated session.'));
}
```

**Issues:**
- ⚠️ **NO FORCED REFRESH:** Default `getIdToken()` uses cached token
- ⚠️ **Token may be stale:** If token expired before request, request will fail
- ⚠️ **No retry with refresh:** After 401, doesn't try force refresh

**Current Scenario:**
```
1. User signs in; gets auth token (expires in 1 hour)
2. App runs for 50 minutes
3. User makes AI request
4. Request uses cached token (may be expired)
5. Server returns 401 Unauthorized
6. ❌ No automatic refresh; error shown to user
```

**Better Approach (Not Implemented):**
```dart
// Should implement:
Future<String> getValidIdToken() async {
  String? token = await _auth.currentUser?.getIdToken();
  if (token == null) return null;
  
  // Check expiration; refresh if needed
  final DecodedToken decoded = parseJwt(token);
  if (DateTime.now().isAfter(decoded.expiration)) {
    token = await _auth.currentUser?.getIdToken(forceRefresh: true);
  }
  return token;
}
```

#### 2.3.2 Paywall Verification Token Refresh

**File:** `lib/data/services/paywall_receipt_verifier.dart`

**Current:**
```dart
final Future<String?> Function() _tokenProvider =
    tokenProvider ??
    (() async => FirebaseAuth.instance.currentUser?.getIdToken());

Future<ReceiptVerificationStatus> _verifyPayload(...) async {
  final String? idToken = await _tokenProvider();
  if (idToken == null) {
    // Treat as deferred; will retry later
    return ReceiptVerificationStatus.deferred;
  }
  // Make request with idToken
}
```

**Gap:** Same as AI service — no forced refresh

#### 2.3.3 User Sign-Out During Operation ⚠️ Not Handled

**Scenario:**
```
1. User in middle of AI conversation
2. Simultaneously: user opens settings and signs out
3. In-flight AI request tries to get auth token
4. Token is null (user signed out)
5. Request fails with "requires authenticated session"
6. Error shown mid-conversation (confusing)
```

**Current Flow:**
```dart
// No guard against sign-out during operation
final String? idToken = await _tokenProvider();
if (idToken == null) {
  return Result.err(UnexpectedFailure('...'));
}
```

**Better Approach (Not Implemented):**
```dart
// Check if user is still authenticated before starting operation
if (FirebaseAuth.instance.currentUser == null) {
  return Result.err(UnexpectedFailure('Session expired. Please sign in again.'));
}

// During operation, check again
final String? idToken = await _tokenProvider();
if (idToken == null) {
  return Result.err(UnexpectedFailure('Session expired. Please sign in again.'));
}
```

---

### 2.4 Edge Cases by Feature

#### 2.4.1 AI Service Edge Cases

| Scenario | Handling | Status |
|----------|----------|--------|
| Empty prompt | Rejected (isEmpty check) | ✅ Good |
| Null/expired token | Returns NetworkFailure | ⚠️ Could force refresh |
| Empty response body | Caught (content.isEmpty) | ✅ Good |
| No choices in response | Caught (choices.isEmpty) | ✅ Good |
| Rate limited (429) | Deferred + queued | ✅ Good |
| Server error (500) | Deferred + queued | ✅ Good |
| Network timeout | Deferred + queued | ✅ Good |
| User signs out mid-request | Request fails; error shown | ⚠️ Could be clearer |
| Prompt injection / extremely long | No validation | ⚠️ Gap |

#### 2.4.2 Paywall Edge Cases

| Scenario | Handling | Status |
|----------|----------|--------|
| Store unavailable on init | Uses cached premium | ✅ Good |
| Receipt verification fails | Deferred + queued | ✅ Good |
| No products fetched | Shows "Loading..." indefinitely | ⚠️ Gap |
| Purchase mid-verification | Queues for retry | ✅ Good |
| Token expired during verification | NetworkFailure | ⚠️ Could force refresh |
| Malformed receipt | Invalid status | ✅ Good |
| User sign-out during verification | Request fails (no token) | ⚠️ Not handled gracefully |

#### 2.4.3 Authentication Edge Cases

| Scenario | Handling | Status |
|----------|----------|--------|
| Empty email | Validation error | ✅ Good |
| Empty password | Validation error | ✅ Good |
| Whitespace-only email | Not explicitly trimmed in UI layer | ⚠️ Gap |
| Too many login attempts | Progressive backoff (2s-60s) | ✅ Good |
| Network timeout on login | Throws; no retry | ⚠️ Gap |
| User deleted during session | Handled by Firebase (resets to null) | ✅ Good |
| Token refresh fails | Returns null; request fails | ⚠️ Could retry |

#### 2.4.4 Data Persistence Edge Cases

| Scenario | Handling | Status |
|----------|----------|--------|
| Corrupt JSON in storage | Reseeded from defaults | ✅ Good |
| Missing storage key | Returns null; uses defaults | ✅ Good |
| Schema evolution | Type casting handles basic cases | ⚠️ Limited |
| Concurrent read/write | No locking in SecureStore | ⚠️ Gap |
| Storage quota exceeded | Not handled (would throw) | ⚠️ Gap |

---

## 3. Specific Gaps & Recommendations

### 3.1 Critical Gaps

**1. Token Expiration During Operations**

**Issue:** Long-running operations may use stale auth tokens

**Scenarios:**
- User mobile app in background for 45 minutes (token expires after 1 hour)
- User makes AI request → uses cached token → request fails with 401

**Fix:**
```dart
// Implement token freshness check
Future<String?> getValidIdToken() async {
  String? token = await _auth.currentUser?.getIdToken();
  if (token == null) return null;
  
  // If token will expire within 5 minutes, force refresh
  final DateTime? expiration = _getTokenExpiration(token);
  if (expiration != null && DateTime.now().add(Duration(minutes: 5)).isAfter(expiration)) {
    token = await _auth.currentUser?.getIdToken(forceRefresh: true);
  }
  return token;
}

String? _getTokenExpiration(String jwt) {
  try {
    final List<String> parts = jwt.split('.');
    if (parts.length != 3) return null;
    final String payload = parts[1];
    // Decode base64; extract exp claim
    final Map<String, dynamic> decoded = jsonDecode(
      utf8.decode(base64Url.decode(payload.padRight(payload.length + payload.length % 4, '=')))
    );
    final int? exp = decoded['exp'] as int?;
    if (exp == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(exp * 1000);
  } catch (_) {
    return null;
  }
}
```

**2. No Operation Cancellation**

**Issue:** In-flight operations can't be cancelled if user navigates away or signs out

**Fix:**
```dart
// Implement CancelToken pattern
class CancelToken {
  bool _cancelled = false;
  
  bool get isCancelled => _cancelled;
  
  void cancel() {
    _cancelled = true;
  }
}

// Usage:
Future<String?> generateResponse({
  required String prompt,
  required CancelToken cancelToken,
}) async {
  if (cancelToken.isCancelled) {
    return Result.err(UnexpectedFailure('Operation cancelled.'));
  }
  
  final Result<String> result = await generateResponseSafe(...);
  
  if (cancelToken.isCancelled) {
    return Result.err(UnexpectedFailure('Operation cancelled.'));
  }
  
  return result.value;
}

// Caller cancels when navigating away:
@override
void dispose() {
  _operationCancelToken.cancel();  // Cancels any in-flight operations
  super.dispose();
}
```

**3. User Sign-Out Not Handled in Long-Running Operations**

**Issue:** User signs out while operation is pending; request fails mid-flow

**Fix:**
```dart
// Guard against sign-out
Future<void> safeOperation() async {
  if (FirebaseAuth.instance.currentUser == null) {
    return Result.err(UnexpectedFailure('No active session.'));
  }
  
  try {
    await operation();
  } catch (e) {
    if (FirebaseAuth.instance.currentUser == null) {
      return Result.err(UnexpectedFailure('Session was closed. Please sign in again.'));
    }
    rethrow;
  }
}
```

---

### 3.2 Medium-Priority Gaps

**1. Prompt Injection & Input Size Validation**

**Current:** No limit on prompt length

**Fix:**
```dart
const int maxPromptLength = 5000;

Future<Result<String>> generateResponseSafe({
  required String prompt,
}) async {
  final String trimmed = prompt.trim();
  
  if (trimmed.isEmpty) {
    return Result.err(UnexpectedFailure('Prompt cannot be empty.'));
  }
  
  if (trimmed.length > maxPromptLength) {
    return Result.err(UnexpectedFailure('Prompt too long. Max $maxPromptLength characters.'));
  }
  
  // Proceed...
}
```

**2. Concurrent Read/Write in SecureStore**

**Issue:** No protection against concurrent access to storage

**Fix:**
```dart
class SecureStore {
  final AsyncGate<void> _gate = AsyncGate<void>();
  
  Future<String?> readString(String key) {
    return _gate.run(() => _unsafeRead(key));
  }
  
  Future<void> writeString(String key, String value) {
    return _gate.run(() => _unsafeWrite(key, value));
  }
}
```

**3. Missing Error Recovery for Products Query**

**Current:**
```dart
// If products query fails, UI shows "Loading..." forever
await Future.wait([queryProducts()]);  // No timeout
```

**Fix:**
```dart
// Add timeout
try {
  await Future.wait([queryProducts()]).timeout(
    const Duration(seconds: 15),
    onTimeout: () {
      onError?.call('Store query timed out. Using cached products.');
      return;
    },
  );
} catch (e) {
  onError?.call('Could not fetch products. Using cached data.');
}
```

---

### 3.3 Low-Priority Improvements

**1. Deep Link Error Logging**

```dart
// Current: silently ignores invalid deep links
// Add:
void _handleDeepLinkPayload(String? payload) {
  if (payload == null || payload.trim().isEmpty) {
    Logger.info('Empty deep link payload');
    return;
  }
  
  final Uri? uri = Uri.tryParse(payload.trim());
  if (uri == null) {
    Logger.warning('Malformed deep link URI: $payload');
    return;
  }
  
  final Uri? normalized = normalizeSupportedDeepLink(uri);
  if (normalized == null) {
    Logger.warning('Unsupported deep link target: ${uri.host}');
    return;
  }
  // ...
}
```

**2. Email Input Trimming in Auth UI**

Currently: UI doesn't trim email before passing to service

```dart
// Auth UI should trim:
final String email = _emailController.text.trim();
final String password = _passwordController.text;  // Don't trim (spaces intentional)

await authService.signIn(email: email, password: password);
```

**3. Better Error Messages for Empty Input**

```dart
// Current:
if (value.isEmpty) return;  // Silent

// Better:
if (value.isEmpty) {
  showMessage('Please enter a value before submitting.');
  return;
}
```

---

## 4. Testing Gaps

| Scenario | Tested | Status |
|----------|--------|--------|
| Empty string input | ✅ Implicit | Token expiration during AI request | ❌ Not tested |
| User sign-out during operation | ❌ Not tested |
| Malformed JSON recovery | ✅ Yes (workspace tests) |
| Concurrent mutations | ⚠️ Partial (console gate tested) |
| Stream disposal on widget close | ✅ Yes (dispose methods) |
| Null token during request | ❌ Not tested |
| Operation cancellation | ❌ Not tested |
| Network timeout on auth | ❌ Not tested |
| Prompt length limits | ❌ Not tested |

---

## 5. Recommendations

### Immediate (Next Sprint)

1. ✅ **Implement token freshness check** (1-2 hrs) — prevents 401 failures on stale tokens
2. ✅ **Add operation cancellation support** (2-3 hrs) — prevents mid-flow disruptions
3. ✅ **Add prompt input validation** (30 min) — prevent excessively long prompts
4. ✅ **Improve error messages for empty input** (30 min) — better UX

### Short-term (2-3 Sprints)

5. ✅ **Add sign-out guards** (1-2 hrs) — clearer error on session expiration
6. ✅ **Add concurrent SecureStore protection** (1 hr) — prevent data corruption
7. ✅ **Improve products query timeout** (30 min) — prevent infinite loading
8. ✅ **Add deep link error logging** (30 min) — better debugging

### Long-term (Future)

9. ⚠️ Network retry for sign-in timeouts
10. ⚠️ Exponential backoff for transient failures during operations
11. ⚠️ Comprehensive test coverage for edge cases

---

## 6. Summary Table

| Category | Status | Issues | Effort |
|----------|--------|--------|--------|
| **Null/Empty Input** | ✅ Good | None critical | — |
| **Malformed Data** | ✅ Good | Better logging | 30min |
| **Interrupted Flows** | ⚠️ Partial | No cancellation; no sign-out guards | 4-6hrs |
| **Session Expiration** | ⚠️ Poor | No token refresh; no session checks | 2-3hrs |
| **Concurrent Ops** | ✅ Partial | AsyncGate used; no storage protection | 1hr |
| **Input Validation** | ✅ Good | Missing prompt length limit | 30min |
| **Stream Cleanup** | ✅ Good | None | — |

**Overall:** Solid foundation with thoughtful null safety and input validation. Key improvements needed in token management and operation cancellation.

**Estimated Total Effort to Fix All Issues:** ~10-15 hours across 1-2 sprints.
