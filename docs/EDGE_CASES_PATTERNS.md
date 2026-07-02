# Edge Cases Handling Patterns

Quick reference guide for common edge case patterns in ChronoSpark.

---

## 1. Input Validation Pattern

```dart
// ✅ CORRECT: Trim, validate, provide feedback
Future<void> processUserInput(String input) async {
  final String value = input.trim();
  
  // Reject empty
  if (value.isEmpty) {
    runtimeError = 'Input cannot be empty.';
    notifyListeners();
    return;
  }
  
  // Optional: Check length
  if (value.length > 1000) {
    runtimeError = 'Input too long. Max 1000 characters.';
    notifyListeners();
    return;
  }
  
  // Process
  try {
    await doSomething(value);
  } catch (e) {
    runtimeError = 'Failed to process input.';
    notifyListeners();
  }
}

// ❌ WRONG: No validation, no feedback
void processUserInput(String input) {
  doSomething(input);  // Crashes if empty or null
}
```

---

## 2. Null-Coalescing Pattern

```dart
// ✅ CORRECT: Safe null handling
final String email = user.email?.trim() ?? '';
if (email.isEmpty) {
  throw Exception('Email not available');
}

// ❌ WRONG: Unguarded null
final String email = user.email!.trim();  // Crashes if null

// ❌ WRONG: Incomplete check
final String email = user.email ?? 'default@example.com';
if (email.isEmpty) {  // Never true; always has value
  return;
}
```

---

## 3. JSON Parsing with Recovery

```dart
// ✅ CORRECT: Parse with fallback
Future<List<T>> loadData() async {
  final String? raw = await storage.readString(key);
  if (raw == null || raw.trim().isEmpty) {
    return getDefaults();
  }
  
  try {
    final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
    return decoded.map((e) => T.fromJson(e as Map<String, dynamic>)).toList();
  } on FormatException catch (e) {
    Logger.error('JSON corrupt: $e');
    await saveDefaults();
    return getDefaults();
  } on TypeError catch (e) {
    Logger.error('Schema mismatch: $e');
    return getDefaults();
  }
}

// ❌ WRONG: No error handling
List<T> loadData() {
  final raw = storage.readString(key);
  return jsonDecode(raw).map(...).toList();  // Crashes on corrupt data
}
```

---

## 4. Token Refresh Pattern (Needs Implementation)

```dart
// ✅ RECOMMENDED: Check expiration; refresh if needed
Future<String?> getValidIdToken() async {
  String? token = await auth.currentUser?.getIdToken();
  if (token == null) return null;
  
  // Check if token expires within 5 minutes
  final DateTime? expiration = _getTokenExpiration(token);
  if (expiration != null && 
      DateTime.now().add(Duration(minutes: 5)).isAfter(expiration)) {
    // Force refresh
    token = await auth.currentUser?.getIdToken(forceRefresh: true);
  }
  return token;
}

// ❌ CURRENT: Doesn't check expiration
Future<String?> getIdToken() {
  return auth.currentUser?.getIdToken();  // May return stale token
}
```

---

## 5. Operation Cancellation Pattern (Needs Implementation)

```dart
// ✅ RECOMMENDED: Support cancellation
class CancelToken {
  bool _cancelled = false;
  bool get isCancelled => _cancelled;
  void cancel() => _cancelled = true;
}

Future<String> generateResponse({
  required CancelToken cancelToken,
}) async {
  if (cancelToken.isCancelled) {
    return Result.err(UnexpectedFailure('Cancelled'));
  }
  
  final result = await someAsyncWork();
  
  if (cancelToken.isCancelled) {
    return Result.err(UnexpectedFailure('Cancelled'));
  }
  
  return result;
}

// Caller:
@override
void dispose() {
  _cancelToken.cancel();  // Cancel any pending operations
  super.dispose();
}

// ❌ CURRENT: No cancellation support
Future<String> generateResponse() {
  return someAsyncWork();  // Can't cancel
}
```

---

## 6. Sign-Out Guard Pattern (Needs Implementation)

```dart
// ✅ RECOMMENDED: Check session before and during operation
Future<Result<String>> generateResponse({...}) async {
  // Check before starting
  if (FirebaseAuth.instance.currentUser == null) {
    return Result.err(UnexpectedFailure('No active session.'));
  }
  
  try {
    final String? token = await getIdToken();
    if (token == null) {
      return Result.err(UnexpectedFailure('Session expired.'));
    }
    
    return await makeRequest(token);
  } catch (e) {
    // Check if sign-out occurred
    if (FirebaseAuth.instance.currentUser == null) {
      return Result.err(UnexpectedFailure('Session was closed.'));
    }
    rethrow;
  }
}

// ❌ CURRENT: No sign-out check
Future<Result<String>> generateResponse({...}) {
  final token = await getIdToken();
  return makeRequest(token);  // If user signs out, fails confusingly
}
```

---

## 7. Widget Lifecycle — mounted Check ✅ (Already Implemented)

```dart
// ✅ CORRECT: Check mounted before updating UI
Future<void> _loadData() async {
  final data = await fetchData();
  if (!mounted) return;  // Widget was disposed
  setState(() => this.data = data);
}

// ❌ WRONG: Update even if widget disposed
Future<void> _loadData() async {
  final data = await fetchData();
  setState(() => this.data = data);  // Crash if disposed
}
```

---

## 8. Stream Cleanup — dispose ✅ (Already Implemented)

```dart
// ✅ CORRECT: Cancel subscriptions in dispose
class MyWidget extends StatefulWidget {
  @override
  State<MyWidget> createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  late StreamSubscription<T> _subscription;
  
  @override
  void initState() {
    super.initState();
    _subscription = stream.listen((_) {});
  }
  
  @override
  void dispose() {
    _subscription.cancel();  // Clean up
    super.dispose();
  }
}

// ❌ WRONG: No cleanup
class _MyWidgetState extends State<MyWidget> {
  late StreamSubscription<T> _subscription;
  
  @override
  void initState() {
    _subscription = stream.listen((_) {});
    // Subscription leaks when widget disposed
  }
}
```

---

## 9. Concurrent Operation Safety — AsyncGate ✅ (Already Implemented)

```dart
// ✅ CORRECT: Serialize concurrent mutations
class MyService {
  final AsyncGate<void> _gate = AsyncGate<void>();
  
  Future<void> updateState(String value) {
    return _gate.run(() async {
      // Only one update runs at a time
      await doMutation(value);
    });
  }
}

// ❌ WRONG: Race condition
class MyService {
  Future<void> updateState(String value) async {
    // Multiple updates can run concurrently; state corruption
    await doMutation(value);
  }
}
```

---

## 10. Deep Link Validation ✅ (Already Implemented)

```dart
// ✅ CORRECT: Parse safely; validate target
void _handleDeepLink(String? payload) {
  if (payload == null || payload.trim().isEmpty) {
    Logger.info('Empty deep link');
    return;
  }
  
  final Uri? uri = Uri.tryParse(payload.trim());
  if (uri == null) {
    Logger.warning('Malformed URI: $payload');
    return;
  }
  
  final Uri? normalized = normalizeSupportedDeepLink(uri);
  if (normalized == null) {
    Logger.warning('Unsupported target: ${uri.host}');
    return;
  }
  
  handleDeepLink(normalized);
}

// ❌ WRONG: No validation
void _handleDeepLink(String payload) {
  final uri = Uri.parse(payload);  // Crash if malformed
  handleDeepLink(uri);
}
```

---

## Quick Checklist for New Features

- [ ] Trim user inputs before validation
- [ ] Check for null and empty before using
- [ ] Wrap JSON parsing in try-catch (FormatException, TypeError)
- [ ] Validate email/password before submission
- [ ] Check `mounted` before setState in async callbacks
- [ ] Cancel subscriptions in dispose()
- [ ] Use AsyncGate for concurrent state mutations
- [ ] Test empty/null/malformed inputs
- [ ] Test with user sign-out during operation
- [ ] Test with interrupted flows (e.g., navigate away)

---

## Files with Good Patterns

- ✅ `workspace_store_service.dart` — JSON parsing with recovery
- ✅ `auth_service.dart` — Input validation
- ✅ `async_gate.dart` — Concurrent op safety
- ✅ `main_shell.dart` — mounted checks, disposal
- ✅ `deep_link_parser.dart` — URI validation

## Files Needing Improvements

- ⚠️ `si_ai_service.dart` — Add token refresh, cancellation
- ⚠️ `paywall_receipt_verifier.dart` — Add token refresh, sign-out guard
- ⚠️ `auth_gate.dart` — Add sign-in timeout retry
- ⚠️ All services — Add operation cancellation support
