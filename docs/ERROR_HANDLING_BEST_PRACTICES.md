# Error Handling Best Practices Guide

Quick reference for implementing reliable error handling in ChronoSpark.

---

## 1. Error Type Patterns

### Network Errors — Use Result<T> Type

```dart
// ✅ GOOD: Explicit success/failure handling
Future<Result<String>> fetchData() async {
  try {
    final response = await NetworkResilience.runHttpWithRetry(
      () => client.get(uri),
      timeout: const Duration(seconds: 12),
      maxAttempts: 3,
    );
    
    if (response.statusCode == 200) {
      return Result.ok(response.body);
    }
    return Result.err(
      NetworkFailure('Server returned ${response.statusCode}'),
    );
  } on TimeoutException catch (e) {
    return Result.err(NetworkFailure('Request timed out.'));
  } on http.ClientException catch (e) {
    return Result.err(NetworkFailure('Network unavailable.'));
  }
}

// Caller handles explicitly
final result = await fetchData();
if (result.isOk) {
  processData(result.value!);
} else {
  showError(result.failure!.message);
}
```

❌ **AVOID:**
```dart
// Caller has no way to distinguish network vs validation errors
Future<String> fetchData() async {
  return (await client.get(uri)).body; // Throws on network error
}
```

---

## 2. Sensitive Data Sanitization

### Always Sanitize Before Logging/Displaying

```dart
// ✅ GOOD: Use AppState's sanitization
void _setRuntimeError(Object error, {required String fallback}) {
  final String message = _sanitizeErrorMessage(error.toString());
  runtimeError = message.isEmpty ? fallback : message;
  // message now has emails, tokens, API keys redacted
}

// Or use the sanitizer directly
String safe = _sanitizeErrorMessage(rawError);
Logger.error(safe);
```

**What Gets Redacted:**
- `user@example.com` → `[redacted-email]`
- `Bearer eyJ...` → `Bearer [redacted-token]`
- `AIza...` → `[redacted-api-key]`
- `serverVerificationData=...` → `[redacted-sensitive-field]`

---

## 3. Offline Resilience: Deferred Queuing

### For Operations That Must Survive Network Loss

```dart
// ✅ GOOD: Queue on network failure, replay on recovery
class MyService {
  static const String _queueKey = 'my_pending_queue_v1';
  final SecureStore _store = SecureStore();
  
  // 1. Add to queue on failure
  Future<void> queueFailedOperation(Map<String, dynamic> payload) async {
    final List<Map<String, dynamic>> queue = await _readQueue();
    queue.add({
      ...payload,
      'timestamp': DateTime.now().toIso8601String(),
    });
    await _writeQueue(queue);
  }
  
  // 2. Replay when network recovers
  Future<void> replayPendingOperations() async {
    final List<Map<String, dynamic>> queue = await _readQueue();
    if (queue.isEmpty) return;
    
    final List<Map<String, dynamic>> remaining = [];
    for (final item in queue) {
      try {
        await _executeOperation(item);
      } on Exception {
        remaining.add(item); // Keep for retry
        break; // Stop; will retry rest next time
      }
    }
    await _writeQueue(remaining);
  }
  
  // 3. Integrate into service init and bootstrap
  // In PaywallService.initialize():
  // await paywallService.replayPendingVerifications();
  
  // In AppState._bootstrap():
  // await _myService.replayPendingOperations();
}
```

**Key Points:**
- Store queue in secure storage (not memory; survives app restart)
- Stop on first failure; retry rest next opportunity
- Replay on bootstrap AND after network recovery
- Deduplicate entries to avoid double-processing

---

## 4. User-Facing Error Messages

### Be Specific & Actionable

```dart
// ✅ GOOD: Context + Guidance
runtimeError = 'Verification deferred due to network conditions. '
    'Premium status will refresh automatically once connectivity stabilizes.';

// ✅ GOOD: Specific failure reason
return Result.err(RateLimitFailure(
  'AI service is temporarily overloaded. Retry in 15s.',
));

// ❌ AVOID: Vague or technical
runtimeError = 'Request failed.'; // What to do?
return Result.err(UnexpectedFailure('FirebaseException')); // User-unfriendly
```

**Pattern:**
```
1. What happened: "Verification timed out"
2. Why it happened: "due to network delay"
3. What will happen: "Your request will retry automatically"
4. Optional: "Or you can retry now" (with button)
```

---

## 5. Error Display Components

### Use These UI Patterns

**For Inline Errors (Settings, Paywall Screens):**
```dart
if ((appState.runtimeError ?? '').isNotEmpty) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(appState.runtimeError!),
      duration: Duration(seconds: 5),
      action: SnackBarAction(
        label: 'Retry',
        onPressed: () => /* retry operation */,
      ),
    ),
  );
}
```

**For Page-Level Errors (Console, Nexus):**
```dart
if (runtimeError.isNotEmpty) {
  Container(
    padding: EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.amber.withOpacity(0.2),
      border: Border.all(color: Colors.amber),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      runtimeError,
      style: TextStyle(color: Colors.amber.shade900),
    ),
  );
}
```

**For Startup Errors:** ⚠️ **NOT YET IMPLEMENTED**
```dart
// Recommended: Create ErrorRecoveryScreen
class ErrorRecoveryScreen extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  
  @override
  Widget build(BuildContext context) => /* ... */;
}
```

---

## 6. Rate Limiting & Backoff

### Progressive Backoff After Repeated Failures

```dart
// ✅ GOOD: AI Service pattern
int _consecutiveFailures = 0;
DateTime? _temporarilyBlockedUntil;

Future<Result<String>> generateResponse(...) async {
  final now = DateTime.now();
  if (_temporarilyBlockedUntil != null && now.isBefore(_temporarilyBlockedUntil)) {
    return Result.err(RateLimitFailure(
      'AI service is temporarily overloaded. Retry in '
      '${_temporarilyBlockedUntil.difference(now).inSeconds + 1}s.',
    ));
  }
  
  // ... attempt request ...
  
  if (attempt.failed) {
    _registerFailure(); // Increment counter; set block time
  }
}

void _registerFailure() {
  _consecutiveFailures += 1;
  final seconds = switch (_consecutiveFailures) {
    1 || 2 => 5,
    3 => 10,
    4 => 20,
    _ => 60,
  };
  _temporarilyBlockedUntil = DateTime.now().add(Duration(seconds: seconds));
}
```

---

## 7. Testing Error Scenarios

### Unit Test Pattern for Deferred Queues

```dart
test('queues deferred request on network failure', () async {
  final service = MyService(client: fakeClient);
  fakeClient.respondWith(status: 429); // Rate limited
  
  final result = await service.processRequest(...);
  
  expect(result.failure, isA<NetworkFailure>());
  expect(await service.hasPendingRequests(), isTrue);
});

test('replays deferred queue and clears entries', () async {
  // Setup: offline, queue requests
  final service = MyService(client: offlineClient);
  await service.queueRequest(...);
  expect(await service.hasPendingRequests(), isTrue);
  
  // Network recovers
  service = MyService(client: fakeClient);
  fakeClient.respondWith(status: 200);
  
  // Replay
  await service.replayPendingRequests();
  
  // Queue cleared
  expect(await service.hasPendingRequests(), isFalse);
});
```

---

## 8. Anti-Patterns ❌

### Don't Do These

```dart
// ❌ Silent failures
try {
  await operation();
} catch (_) {
  // Silently ignore; user never knows what failed
}

// ❌ Vague error wrapping
try {
  await operation();
} catch (e) {
  throw Exception(e); // Lost context
}

// ❌ Throwing in UI layer
if (something.isEmpty) {
  throw ArgumentError('Invalid input'); // Should return Result.err
}

// ❌ Blocking user on network
Future<void> saveData() async {
  // No timeout; app might hang indefinitely
  await client.post(uri);
}

// ❌ Logging sensitive data
Logger.error('Auth failed: $authException'); // May log tokens
// Should use sanitized version instead
```

---

## 9. Checklist for New Features

When adding a new API call or async operation:

- [ ] Wrap in `try-catch` or use `Result<T>`
- [ ] Handle network timeouts (add to NetworkResilience or set timeout)
- [ ] Handle auth failures (token expired, no user)
- [ ] Distinguish retryable vs permanent failures
- [ ] If critical, implement deferred queue + replay
- [ ] Sanitize error message before user display
- [ ] Display error with actionable guidance ("Retry" button?)
- [ ] Log error event to telemetry (with sanitized message)
- [ ] Write unit tests for failure scenarios
- [ ] Test on slow/offline network (iOS Simulator Network Link Conditioner)

---

## 10. Useful Utilities

### Use These Built-in Services

```dart
// Network resilience
import 'package:core/utils/network_resilience.dart';
final response = await NetworkResilience.runHttpWithRetry(
  () => client.get(uri),
  timeout: const Duration(seconds: 12),
  maxAttempts: 3,
);

// Error sanitization
import 'package:core/state/app_state.dart'; // Has _sanitizeErrorMessage
// Or create your own; see AppState implementation

// Secure storage for queues
import 'package:data/storage/secure_store.dart';
final store = SecureStore();
await store.writeString(key, jsonEncode(data));

// Rate limiting
import 'package:core/utils/rate_limiter.dart';
final limiter = SlidingWindowRateLimiter(maxRequests: 6, window: Duration(minutes: 1));
if (!limiter.tryAcquire()) {
  // Rate limited
}

// Logging
import 'package:core/utils/logger.dart';
Logger.info('Message');
Logger.error('Error: $sanitizedError');
```

---

## 11. Error Handling Patterns by Feature

### Paywall & In-App Purchase

```dart
// Verify purchase
final status = await verifier.verifyPurchaseStatus(purchase);
switch (status) {
  case ReceiptVerificationStatus.verified:
    // Premium access granted
    break;
  case ReceiptVerificationStatus.deferred:
    // Network failed; queued for retry
    showMessage('Verification deferred. Premium will activate when connectivity recovers.');
    break;
  case ReceiptVerificationStatus.invalid:
    // Permanent failure
    showError('Purchase could not be verified. Contact support if problem persists.');
    break;
}
```

### AI Service

```dart
// Generate response
final result = await aiService.generateResponseSafe(
  prompt: userInput,
  decision: decision,
);

if (result.isOk) {
  display(result.value!);
} else {
  final failure = result.failure!;
  if (failure is RateLimitFailure) {
    showError(failure.message); // "Temporarily overloaded. Retry in 15s."
  } else if (failure is NetworkFailure) {
    showError(failure.message); // "Request queued for retry."
  } else {
    showError('AI service unavailable. Try again shortly.');
  }
}
```

### Authentication

```dart
// Sign in
try {
  final credential = await auth.signIn(email: email, password: password);
  // Success
} on FirebaseAuthException catch (e) {
  if (e.code == 'too-many-requests') {
    showError('Too many attempts. Please wait before trying again.');
  } else if (e.code == 'wrong-password' || e.code == 'user-not-found') {
    showError('Email or password is incorrect. Try again or reset your password.');
  } else {
    showError('Sign-in failed. Please try again.');
  }
}
```

---

For questions or examples, see:
- **Current patterns:** lib/data/services/paywall_*.dart, si_ai_service.dart
- **Audit details:** docs/ERROR_HANDLING_RELIABILITY_AUDIT.md
