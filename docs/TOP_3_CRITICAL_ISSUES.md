# Top 3 Critical Issues — Implementation Guide

**Completion Priority:** Phase 1 (1 Sprint)  
**Estimated Effort:** 5-8 hours total  
**Impact:** Prevents session failures, operation orphaning, and confusing errors

---

## 🔴 Issue #1: Token Expiration Mid-Operation

**Status:** NOT IMPLEMENTED  
**Severity:** CRITICAL  
**Time:** 1-2 hours

### Problem

When a user's Firebase auth token expires (default 1 hour), subsequent requests fail silently:

```
Timeline:
1. User signs in at 12:00 PM (token expires at 1:00 PM)
2. User uses app for 50 minutes; makes AI request at 12:50 PM
3. Request uses cached token (obtained at 12:00, not refreshed)
4. At ~1:00 PM, token actually expires on server
5. Server returns 401 Unauthorized
6. App shows error: "AI request requires an authenticated session"
7. User confused: "I just signed in!"
```

### Current Code (WRONG ❌)

**File:** `lib/data/services/si_ai_service.dart` (line 68)

```dart
final String? idToken = await _tokenProvider();
// _tokenProvider returns: FirebaseAuth.instance.currentUser?.getIdToken()
// This returns CACHED token; doesn't check if expired
```

### Solution

**File:** `lib/data/services/auth_service.dart`

Add method to get fresh token with expiration check:

```dart
Future<String?> getValidIdToken() async {
  String? token = await _auth.currentUser?.getIdToken();
  if (token == null) return null;
  
  // Check if token expires within 5 minutes; refresh if so
  final DateTime? expiration = _getTokenExpiration(token);
  if (expiration != null && 
      DateTime.now().add(Duration(minutes: 5)).isAfter(expiration)) {
    // Force refresh
    token = await _auth.currentUser?.getIdToken(forceRefresh: true);
  }
  return token;
}

String? _getTokenExpiration(String jwt) {
  try {
    final List<String> parts = jwt.split('.');
    if (parts.length != 3) return null;
    
    final String payload = parts[1];
    // Add padding to base64
    final String padded = payload + ('=' * (4 - payload.length % 4));
    
    final List<int> bytes = base64Url.decode(padded);
    final Map<String, dynamic> decoded = jsonDecode(utf8.decode(bytes));
    
    final int? exp = decoded['exp'] as int?;
    if (exp == null) return null;
    
    return DateTime.fromMillisecondsSinceEpoch(exp * 1000);
  } catch (_) {
    return null;  // Can't parse; assume valid
  }
}
```

**Update:**
- `si_ai_service.dart` — Use `authService.getValidIdToken()` instead of `FirebaseAuth.instance.currentUser?.getIdToken()`
- `paywall_receipt_verifier.dart` — Same change

### Testing

```dart
// Test: Expired token should be refreshed
test('getValidIdToken refreshes when expiring soon', () async {
  // Mock expired token
  // Mock FirebaseAuth.getIdToken(forceRefresh: true) to return fresh token
  final String? token = await authService.getValidIdToken();
  expect(token, isNotNull);
});

// Test: Valid token should not be refreshed
test('getValidIdToken keeps valid token', () async {
  // Mock valid token (expires in 1 hour)
  final String? token = await authService.getValidIdToken();
  // Verify getIdToken(forceRefresh: false) was called, not forceRefresh: true
});
```

### Validation

After implementation:
- ✅ Token is refreshed if expiring within 5 minutes
- ✅ No 401 errors due to stale tokens
- ✅ Existing auth tests still pass
- ✅ No added latency for fresh tokens

---

## 🔴 Issue #2: No Operation Cancellation

**Status:** NOT IMPLEMENTED  
**Severity:** CRITICAL  
**Time:** 2-3 hours

### Problem

When user navigates away, async operations continue and complete, confusing the UI:

```
Timeline:
1. User taps "Generate Response" button (starts 15-second AI request)
2. User immediately navigates to Creator tab
3. AI request completes in background and tries to update AppState
4. User sees "SI:" response appear randomly in their Creator workspace
5. Confused: "I wasn't asking for this"
```

### Current Code (WRONG ❌)

**File:** `lib/data/services/si_ai_service.dart`

```dart
Future<Result<String>> generateResponseSafe({...}) async {
  // No way to cancel this; it will complete even if caller doesn't care
  final result = await _makeRequest(...);
  return result;
}
```

### Solution

**New File:** `lib/core/utils/cancel_token.dart`

```dart
class CancelToken {
  bool _cancelled = false;
  
  bool get isCancelled => _cancelled;
  
  void cancel() {
    _cancelled = true;
  }
}
```

**Update:**
- `lib/data/services/si_ai_service.dart` — Add `cancelToken` parameter:

```dart
Future<Result<String>> generateResponseSafe({
  required String prompt,
  required Decision decision,
  required CancelToken cancelToken,
}) async {
  if (cancelToken.isCancelled) {
    return Result.err(UnexpectedFailure('Operation cancelled.'));
  }
  
  // Check again before making request
  final String? idToken = await _tokenProvider();
  if (cancelToken.isCancelled) {
    return Result.err(UnexpectedFailure('Operation cancelled.'));
  }
  
  final response = await _makeRequest(idToken, prompt);
  
  // Check after request completes
  if (cancelToken.isCancelled) {
    return Result.err(UnexpectedFailure('Operation cancelled.'));
  }
  
  return response;
}
```

- `lib/core/state/app_state.dart` — Create and pass cancel token:

```dart
Future<void> generateResponse({required String prompt}) async {
  final CancelToken cancelToken = CancelToken();
  _currentOperationCancel = cancelToken;  // Store so can cancel later
  
  try {
    final Result<String> result = await _aiService.generateResponseSafe(
      prompt: prompt,
      decision: decision ?? _fallbackDecision(),
      cancelToken: cancelToken,  // Pass to service
    );
    // Handle result
  } finally {
    _currentOperationCancel = null;
  }
}

@override
void dispose() {
  _currentOperationCancel?.cancel();  // Cancel any pending ops
  super.dispose();
}
```

- `lib/features/system_shell/pages/console_page.dart` — Handle cancellation:

```dart
@override
void dispose() {
  appState.cancelCurrentOperation();  // Method added to AppState
  super.dispose();
}
```

### Testing

```dart
test('generateResponseSafe returns cancelled error if token is cancelled', () async {
  final token = CancelToken();
  
  // Start request
  final future = aiService.generateResponseSafe(
    prompt: 'test',
    decision: testDecision,
    cancelToken: token,
  );
  
  // Cancel while pending
  token.cancel();
  
  final result = await future;
  expect(result.isErr, true);
  expect(result.failure!.message, contains('cancelled'));
});
```

### Validation

After implementation:
- ✅ Operations cancelled when widget disposed
- ✅ Response not shown if operation was cancelled
- ✅ No orphaned requests
- ✅ No token waste on cancelled requests

---

## 🔴 Issue #3: No Sign-Out Guards

**Status:** NOT IMPLEMENTED  
**Severity:** CRITICAL  
**Time:** 1-2 hours

### Problem

When user signs out during an operation, confusing error appears mid-flow:

```
Timeline:
1. User generates AI response (starts request)
2. User opens Settings → Account → Sign Out
3. User is signed out while AI request pending
4. AI request tries to get auth token; gets null
5. Request fails with: "AI request requires an authenticated session"
6. Error shown mid-page (confusing: user just signed out intentionally)
```

### Current Code (WRONG ❌)

**File:** `lib/data/services/si_ai_service.dart` (line 68)

```dart
final String? idToken = await _tokenProvider();
if (idToken == null) {
  // Shows generic error
  return Result.err(UnexpectedFailure('AI request requires an authenticated session.'));
}
```

User context is lost: did auth fail? Or is user signed out?

### Solution

**File:** `lib/data/services/si_ai_service.dart`

Add sign-out check and better error messaging:

```dart
Future<Result<String>> generateResponseSafe({...}) async {
  // Check BEFORE starting expensive operations
  if (FirebaseAuth.instance.currentUser == null) {
    return Result.err(UnexpectedFailure(
      'Session expired. Please sign in to continue.',
    ));
  }
  
  try {
    final String? idToken = await _tokenProvider();
    if (idToken == null) {
      // Check if signed out (more likely than token refresh failure)
      if (FirebaseAuth.instance.currentUser == null) {
        return Result.err(UnexpectedFailure(
          'Your session was closed. Please sign in again.',
        ));
      }
      return Result.err(UnexpectedFailure(
        'Could not authenticate request. Please try again.',
      ));
    }
    
    final response = await _makeRequest(idToken, prompt);
    
    // Check AFTER operation (user might have signed out during)
    if (FirebaseAuth.instance.currentUser == null) {
      return Result.err(UnexpectedFailure(
        'Your session was closed. Please sign in again.',
      ));
    }
    
    return response;
  } catch (e) {
    // Check if cause was sign-out
    if (FirebaseAuth.instance.currentUser == null) {
      return Result.err(UnexpectedFailure(
        'Your session was closed. Please sign in again.',
      ));
    }
    rethrow;
  }
}
```

Same pattern for:
- `paywall_receipt_verifier.dart`
- `auth_service.dart` methods

### Testing

```dart
test('generateResponseSafe detects sign-out and shows clear message', () async {
  // Sign in
  await authService.signIn(email: 'test@example.com', password: 'password');
  
  // Mock Firebase sign-out mid-operation
  FirebaseAuth.instance.signOut();  // User signs out
  
  // Request should detect and show clear message
  final result = await aiService.generateResponseSafe(
    prompt: 'test',
    decision: testDecision,
    cancelToken: CancelToken(),
  );
  
  expect(result.isErr, true);
  expect(
    result.failure!.message,
    contains('session was closed') || contains('sign in again'),
  );
});
```

### Validation

After implementation:
- ✅ Sign-out during operation detected immediately
- ✅ Clear "Session closed" message shown
- ✅ User knows to sign in again
- ✅ No confusing generic errors

---

## 📋 Implementation Checklist

### Phase 1 Tasks (Do in This Order)

- [ ] **Task 1: Add Token Expiration Check** (1-2 hrs)
  - [ ] Add `getTokenExpiration()` helper to `auth_service.dart`
  - [ ] Add `getValidIdToken()` method to `auth_service.dart`
  - [ ] Add import: `import 'dart:convert';` and `import 'package:crypto/crypto.dart';`
  - [ ] Update `si_ai_service.dart` to use new method
  - [ ] Update `paywall_receipt_verifier.dart` to use new method
  - [ ] Run tests: `dart test` (should pass 36/36)

- [ ] **Task 2: Add Operation Cancellation** (2-3 hrs)
  - [ ] Create `lib/core/utils/cancel_token.dart`
  - [ ] Update `si_ai_service.dart` to accept `cancelToken` parameter
  - [ ] Update `app_state.dart` to create/pass/cancel tokens
  - [ ] Update `paywall_service.dart` similarly
  - [ ] Add `@override void dispose()` in main shell to cancel ops
  - [ ] Run tests: `dart test` (should pass 36/36 + new cancellation tests)

- [ ] **Task 3: Add Sign-Out Guards** (1-2 hrs)
  - [ ] Update `si_ai_service.dart` to check `currentUser` before and after operation
  - [ ] Update error messages to say "session was closed" instead of generic
  - [ ] Update `paywall_receipt_verifier.dart` similarly
  - [ ] Update `auth_service.dart` methods
  - [ ] Run tests: `dart test` (should pass with sign-out detection tests)

### Validation Before Merge

- [ ] `dart analyze` — No errors or warnings
- [ ] `dart test` — All tests pass
- [ ] Manual testing: AI generation with expired token → retries ✅
- [ ] Manual testing: Navigate away mid-operation → response doesn't appear ✅
- [ ] Manual testing: Sign out mid-operation → clear message ✅

---

## 🎯 Success Criteria

After all 3 tasks complete:

✅ Token expiration never causes 401 (auto-refreshes)  
✅ Cancelled operations don't update UI  
✅ Sign-out mid-operation shows "session closed" message  
✅ No test failures  
✅ Code analyzer clean  
✅ First-time users understand what happened  

---

## 📚 Reference

- Detailed analysis: [docs/EDGE_CASES_AUDIT.md](../docs/EDGE_CASES_AUDIT.md)
- Pattern examples: [docs/EDGE_CASES_PATTERNS.md](../docs/EDGE_CASES_PATTERNS.md)
- Error patterns: [docs/ERROR_HANDLING_BEST_PRACTICES.md](../docs/ERROR_HANDLING_BEST_PRACTICES.md)
