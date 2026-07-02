# Production Readiness Audit

**Date:** June 24, 2026  
**Scope:** Google Play Compliance · Testing · Scalability · Code Quality · Missing Features · Refactoring  
**Status:** Audit Complete | Action Required

---

## Table of Contents

1. [Google Play Store Compliance](#1-google-play-store-compliance)
2. [Testing Coverage](#2-testing-coverage)
3. [Scalability & Concurrency](#3-scalability--concurrency)
4. [Code Quality & Best Practices](#4-code-quality--best-practices)
5. [Missing Production Features](#5-missing-production-features)
6. [Refactoring Suggestions](#6-refactoring-suggestions)
7. [Summary & Priority Matrix](#7-summary--priority-matrix)

---

## 1. Google Play Store Compliance

### 1.1 Privacy Policy ✅ Present

**Finding:** Privacy policy is linked from Settings and hosted on the web.

```dart
// settings_home.dart
onTap: () => _launchLegalUrl(context, AppUrls.privacyPolicy),
```

```dart
// app_urls.dart
static const String privacyPolicy = '...'; // hosted URL
```

**Assets present:**
- `assets/legal/privacy_policy.html` — local copy ✅
- `web/privacy.html` — web copy ✅

**Gap:** The Play Store's **Data Safety section** requires explicit categorization of *what data is collected, why, and whether it's shared*. This is a manual declaration in the Play Console — verify it's complete before submission.

**Checklist:**
- [ ] Play Console → App content → Data safety form fully completed
- [ ] Confirm Firebase Analytics data types declared
- [ ] Confirm Firebase Crashlytics crash data declared
- [ ] Confirm no undeclared user data (task content, AI prompts) is logged

---

### 1.2 Permissions ✅ Minimal

**AndroidManifest.xml declares:**
```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="com.android.vending.BILLING"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
```

**Assessment:**
- `INTERNET` — Required; justified ✅
- `BILLING` — Required for IAP; justified ✅
- `POST_NOTIFICATIONS` — Required for local notifications (Android 13+)

**⚠️ Gap — Runtime permission request for POST_NOTIFICATIONS:**

Android 13+ (API 33+) requires explicit runtime permission request for notifications. No runtime permission request found in codebase.

```dart
// ❌ Current: No runtime permission check found

// ✅ Required before scheduling notifications:
import 'package:permission_handler/permission_handler.dart'; // OR use flutter_local_notifications built-in

Future<bool> requestNotificationPermission() async {
  final NotificationDetails platformChannelSpecifics = ...;
  final bool? granted = await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.requestNotificationsPermission();
  return granted ?? false;
}
```

**Fix:** Call the above before scheduling any notification. `flutter_local_notifications` v17+ supports this natively.

---

### 1.3 Background Location ✅ Not Used

No `ACCESS_BACKGROUND_LOCATION`, `ACCESS_FINE_LOCATION`, or location packages found. ✅

---

### 1.4 Ads ✅ Not Present

No AdMob, Unity Ads, or ad SDK found. ✅

---

### 1.5 Account Deletion ✅ Implemented

```dart
// settings_home.dart line 75
Future<void> _deleteAccount() async { ... }

// settings_actions.dart line 28
Future<Result<void>> deleteAccount({required String password}) async { ... }
```

**Play Store Policy (since 2023):** Apps with account creation must support in-app account deletion. ✅ ChronoSpark complies.

**Verify:**
- [ ] Deletion removes all user data (local + Firestore)
- [ ] Deletion revokes auth token (Firebase Auth delete)
- [ ] Secure storage is cleared on deletion

---

### 1.6 Target SDK Compliance ✅

```kotlin
// app/build.gradle.kts
compileSdk = maxOf(flutter.compileSdkVersion, 34)
targetSdk  = maxOf(flutter.targetSdkVersion,  34)
```

Google Play requires `targetSdk >= 34` from August 2024. ✅ Compliant.

---

### 1.7 App Stability ⚠️ Partial Risk

**Crashlytics:** Installed and initialized ✅
```dart
// telemetry_service.dart
await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(...)
TelemetryService.instance.installGlobalErrorHandlers();
```

**Risks:**
- 9 missing assets will cause `FlutterError` at runtime (from prior Assets Audit)
- No widget tests for most screens — regressions undetected
- Trial counters in-memory — edge case state corruption possible

---

### 1.8 Data Handling ⚠️ Verify Encryption

**Firebase Auth:** Managed by Firebase SDK ✅  
**Secure storage:** `flutter_secure_storage` for premium flag, receipt queue ✅  
**SharedPreferences:** Used for settings — unencrypted on Android

**⚠️ Gap:** SharedPreferences stores app configuration in plaintext. For a health/productivity app with user behavior data, consider using `flutter_secure_storage` for all sensitive preferences.

```dart
// ⚠️ Risk: analyticsSharing preference in plaintext
await settingsController.read()  // SharedPreferences — not encrypted
```

---

## 2. Testing Coverage

### 2.1 Current Test Inventory

| File | Type | Tests |
|------|------|-------|
| `async_gate_test.dart` | Unit | ✅ |
| `deep_link_parser_test.dart` | Unit | ✅ |
| `network_resilience_test.dart` | Unit | ✅ |
| `paywall_receipt_verifier_test.dart` | Unit | ✅ |
| `settings_actions_test.dart` | Unit | ✅ |
| `si_ai_service_test.dart` | Unit | ✅ |
| `subscription_model_test.dart` | Unit | ✅ |
| `validators_test.dart` | Unit | ✅ |
| `workspace_store_service_test.dart` | Unit | ✅ |
| `app_state_lifecycle_persistence_test.dart` | Unit | ✅ |
| `auth_gate_widget_test.dart` | Widget | ✅ |
| `auth_flow_integration_test.dart` | Integration | ✅ |

**Total: 12 test files, 36+ test cases, 0 regressions**

---

### 2.2 Coverage Gaps

**Missing Test Areas:**

| Area | Gap | Risk |
|------|-----|------|
| `MainShell` widget | No widget test | HIGH |
| `TemporalOpsPage` | No widget test | HIGH |
| `SIConsolePage` | No widget test | HIGH |
| `PaywallService` IAP flow | No integration test | HIGH |
| `AppState.updateFromConsole()` | No unit test | MEDIUM |
| `consumeTemporalOpsTrialIfNeeded()` | No edge case test | MEDIUM |
| Premium feature gate | No widget test | MEDIUM |
| Notification delivery | No unit test | LOW |

---

### 2.3 Recommended Test Cases

**Unit Tests — AppState:**
```dart
// test/unit/app_state_console_test.dart
group('AppState.updateFromConsole', () {
  test('add: command creates task', () async { ... });
  test('overwhelmed keyword lowers energy', () async { ... });
  test('deadline keyword raises deadlinePressure', () async { ... });
  test('empty input is ignored', () async { ... });
  test('concurrent calls are serialized by AsyncGate', () async { ... });
});

group('Trial consumption', () {
  test('trial counter increments on each access', () async { ... });
  test('returns false when trial exhausted', () async { ... });
  test('premium users bypass trial gate', () async { ... });
  test('concurrent consume calls do not double-decrement', () async { ... });
});
```

**Widget Tests:**
```dart
// test/widget/main_shell_test.dart
testWidgets('Temporal Ops tab blocked when trial exhausted', (tester) async {
  final AppState state = AppState(bootstrapOnInit: false, ...);
  // Use all trials
  for (int i = 0; i < 5; i++) await state.consumeTemporalOpsTrialIfNeeded();
  
  await tester.pumpWidget(
    ChangeNotifierProvider.value(value: state, child: const MainShell()),
  );
  await tester.tap(find.byKey(const Key('tab_temporal')));
  await tester.pumpAndSettle();
  
  expect(find.text('Temporal Ops free testing is finished.'), findsOneWidget);
});
```

**Integration Tests:**
```dart
// integration_test/paywall_restore_test.dart
testWidgets('Restore purchases flow shows confirmation', (tester) async {
  await tester.pumpWidget(app);
  await tester.tap(find.text('Restore Purchases'));
  await tester.pumpAndSettle();
  expect(find.text('Purchase restore requested'), findsOneWidget);
});
```

---

## 3. Scalability & Concurrency

### 3.1 Current Patterns ✅ Mostly Good

**AsyncGate (console operations):**
```dart
// Serializes concurrent calls — correct pattern
final AsyncGate<void> _consoleUpdateGate = AsyncGate<void>();
await _consoleUpdateGate.run(() async { ... });
```

**In-flight deduplication (purchases):**
```dart
if (_isPurchasing) return;
_isPurchasing = true;
try { ... } finally { _isPurchasing = false; }
```

**Trial consume deduplication:**
```dart
if (_temporalTrialConsumeInFlight != null) {
  return _temporalTrialConsumeInFlight!;
}
```

✅ All correct and idiomatic.

---

### 3.2 Race Condition: Trial Counter State ⚠️

**Problem:** Trial counter modified in memory and persisted asynchronously. If `dispose()` fires during `_autoSave()`, counter incremented but never written.

```dart
// Current:
_temporalTrialUses += 1;   // Mutated immediately in memory
await _autoSave();          // Written async — can be interrupted
notifyListeners();          // UI updated
```

**Risk:** App killed after counter incremented in memory but before `_autoSave()` completes → trial used but count not persisted → user gets one extra free trial.

**Fix:** Write synchronously or verify persist-before-use ordering:
```dart
// ✅ Write before incrementing memory
final int newCount = _temporalTrialUses + 1;
await _autoSave(pendingTrialUses: newCount);  // Persist first
_temporalTrialUses = newCount;                // Update memory after persist
```

---

### 3.3 `_autoSave()` Queue ✅ Well Designed

```dart
Future<void> _saveQueue = Future<void>.value();

void _autoSave() {
  _saveQueue = _saveQueue.then((_) => _persistence.saveSnapshot(...));
}
```

Write operations are chained — no concurrent disk writes. ✅

---

### 3.4 Notification Scheduler ✅

`NotificationManager` with debounce/throttle pattern. Works correctly for single-user mobile scale.

---

### 3.5 Network Resilience ✅

```dart
// 3 attempts, exponential backoff, 12s timeout
NetworkResilience.runHttpWithRetry(request, maxAttempts: 3, timeout: 12s)
```

**Note:** No global HTTP client reuse — each request creates `http.Client()`. This is fine for mobile (no connection pool needed), but adds minor overhead on rapid sequential requests.

---

## 4. Code Quality & Best Practices

### 4.1 Overall Assessment ✅ Strong

- Clean layered architecture: `features/`, `core/`, `data/`, `domain/`
- Dependency injection via constructor parameters with sensible defaults
- Result<T> pattern for error propagation
- Immutable data models via `copyWith`
- Unmodifiable list getters on AppState

---

### 4.2 Issues Found

#### Issue 1: Logger Missing `warn` Level ⚠️

```dart
// logger.dart — Only 2 levels
class Logger {
  static void info(String message) { ... }
  static void error(String message) { ... }
  // ❌ Missing: warn(), debug(), verbose()
}
```

This means operational warnings that aren't errors (e.g., cache expired, trial limit approaching) all go through `error()`, polluting error logs.

**Fix:**
```dart
class Logger {
  static void debug(String message) {
    if (kDebugMode && Env.enableVerboseLogs) debugPrint('[DEBUG] $message');
  }

  static void info(String message) {
    if (Env.enableVerboseLogs) debugPrint('[INFO] $message');
  }

  static void warn(String message) {
    debugPrint('[WARN] $message');  // Always visible
  }

  static void error(String message) {
    debugPrint('[ERROR] $message');
  }
}
```

---

#### Issue 2: `Env.isProduction` Relies on Compile-Time String Comparison ⚠️

```dart
// env.dart
static bool get isProduction => appFlavor.toLowerCase() == 'prod';
```

`appFlavor` defaults to `'dev'` — meaning a production build that didn't explicitly pass `--dart-define=CHRONOSPARK_APP_FLAVOR=prod` runs as dev mode.

**Risk:** Production build goes out with crash reporting enabled and analytics correctly set, but `isProduction` returns `false` — bypassing the production readiness checks.

**Fix:**
```dart
// Use kReleaseMode as a ground-truth production signal
static bool get isProduction =>
    kReleaseMode && appFlavor.toLowerCase() == 'prod';

// OR: Flip the guard — block debug things in release, not vice versa
static bool get isMockLoginEnabled =>
    !kReleaseMode && enableMockLogin;  // Never in release, regardless of flag
```

---

#### Issue 3: Hard-Coded Seed Tasks in UserState ⚠️ Medium

```dart
// app_state.dart — Hard-coded task list
UserState currentState = const UserState(
  tasks: <SiTask>[
    SiTask(title: 'Finish strategic report', priority: 9, hasDeadline: true),
    SiTask(title: 'Review chronologs and summarize', priority: 7),
    SiTask(title: 'Design weekly temporal map', priority: 8),
    SiTask(title: 'Inbox triage', priority: 4),
  ],
  ...
);
```

New users see stale demo tasks on first launch. This should load from `assets/data/temporal_seed.json` or be empty on first launch.

**Fix:**
```dart
// On first launch: show onboarding/empty state
UserState currentState = UserState.empty();  // Or load from seed file

// In bootstrap:
if (snapshot == null) {
  currentState = await _loadSeedTasks();  // Load from assets/data/
}
```

---

#### Issue 4: Subscription Product IDs as Magic Strings ⚠️ Low

```dart
// paywall_service.dart (inferred)
const String productId = 'chronospark_premium_monthly';
```

Product IDs scattered in multiple places. A typo causes silent IAP failure.

**Fix:**
```dart
// lib/core/constants/product_ids.dart
abstract final class ProductIds {
  static const String premiumMonthly = 'chronospark_premium_monthly';
  static const String premiumYearly  = 'chronospark_premium_yearly';

  static const Set<String> all = <String>{premiumMonthly, premiumYearly};
}
```

---

#### Issue 5: MockBillingService Always Instantiated ⚠️

```dart
// app_state.dart
final MockBillingService _billingService = MockBillingService();
```

`MockBillingService` is unconditionally instantiated in `AppState` — even in production builds. The object is small, but the pattern is wrong: production code should not hold a reference to a mock.

**Fix:**
```dart
// Only allocate in debug/dev mode
final MockBillingService? _billingService =
    _allowMockBilling ? MockBillingService() : null;
```

---

#### Issue 6: `updateFromConsole()` Contains Keyword Matching at Parse Level ⚠️

```dart
if (lower.contains('overwhelmed') || lower.contains('drained')) {
  energy = Energy.low;
  workload = (workload + 0.08).clamp(0.0, 1.0);
}
if (lower.contains('deadline') || lower.contains('urgent')) {
  deadlinePressure = 0.85;
}
```

This is a minimal NLU layer inside the method body — making it untestable and rigid. If the keyword list grows, it becomes a maintenance burden.

**Refactor:**
```dart
// lib/core/si/console_intent_parser.dart
class ConsoleIntentParser {
  static ConsoleIntent parse(String input) {
    final String lower = input.toLowerCase();
    return ConsoleIntent(
      reducesEnergy:   lower.contains('overwhelmed') || lower.contains('drained'),
      raisesEnergy:    lower.contains('focus') || lower.contains('energized'),
      raisesDeadline:  lower.contains('deadline') || lower.contains('urgent'),
      isAddTask:       lower.startsWith('add:'),
      taskTitle:       lower.startsWith('add:') ? input.substring(4).trim() : null,
    );
  }
}
```

Now `updateFromConsole()` becomes:
```dart
final ConsoleIntent intent = ConsoleIntentParser.parse(value);
if (intent.reducesEnergy) { energy = Energy.low; }
if (intent.raisesDeadline) { deadlinePressure = 0.85; }
```

And `ConsoleIntentParser` is independently unit-testable.

---

## 5. Missing Production Features

### 5.1 Crashlytics & Error Reporting ✅ Implemented

```dart
// telemetry_service.dart
await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
TelemetryService.instance.installGlobalErrorHandlers();
FlutterError.onError = ... // Captures Flutter frame errors
PlatformDispatcher.instance.onError = ... // Captures platform errors
```

**Gaps:**
- `Logger.error()` does NOT route to Crashlytics — only `debugPrint` ❌
- Non-fatal errors not enriched with user context (plan, feature, version)

**Fix:**
```dart
static Future<void> error(String message, [Object? error, StackTrace? stack]) async {
  debugPrint('[ERROR] $message');
  if (error != null) {
    await TelemetryService.instance.recordError(
      error,
      stack ?? StackTrace.current,
      reason: message,
      fatal: false,
    );
  }
}
```

---

### 5.2 Analytics ✅ Implemented

```dart
await TelemetryService.instance.logEvent('app_start');
await TelemetryService.instance.logEvent('app_state_bootstrap_success');
await TelemetryService.instance.logEvent('app_state_bootstrap_failure');
```

**What's there:**
- App start, bootstrap success/failure
- User opt-out via settings

**Missing analytics events:**

| Event | Value |
|-------|-------|
| `tab_opened` (temporal, si_console, etc.) | Feature engagement |
| `trial_consumed` (feature, remaining_count) | Conversion funnel |
| `paywall_shown` | Conversion trigger |
| `purchase_started` / `purchase_success` / `purchase_failed` | Revenue tracking |
| `task_completed` / `task_skipped` | Core engagement |
| `console_input_submitted` | AI feature usage |
| `restore_purchases_tapped` | Support signal |
| `account_deleted` | Churn signal |
| `notification_permission_granted` / `denied` | Reach tracking |

**Template:**
```dart
// Track feature engagement consistently
await TelemetryService.instance.logEvent('trial_consumed', parameters: {
  'feature': 'temporal_ops',
  'remaining': temporalTrialRemaining,
  'plan': currentPlan.name,
});
```

---

### 5.3 Rate Limiting ⚠️ Missing

**AI proxy requests:** No client-side rate limiting. A user who floods the SI Console with rapid inputs creates N network calls.

**Fix:**
```dart
// lib/core/utils/debouncer.dart
class Debouncer {
  Debouncer({required this.delay});
  final Duration delay;
  Timer? _timer;

  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  void dispose() => _timer?.cancel();
}

// In SIConsolePage:
final Debouncer _inputDebouncer = Debouncer(delay: const Duration(milliseconds: 500));

void _onSubmit(String input) {
  _inputDebouncer.run(() => appState.updateFromConsole(input));
}
```

---

### 5.4 Firebase Performance Monitoring ❌ Not Present

```yaml
# Not in pubspec.yaml:
firebase_performance: ^x.x.x
```

Without `firebase_performance`, you have no visibility into:
- App startup time
- HTTP request latency (AI proxy, receipt verifier)
- Slow renders / frozen frames

**Add:**
```yaml
# pubspec.yaml
firebase_performance: ^0.10.0
```

```dart
// Trace critical operations
final Trace trace = FirebasePerformance.instance.newTrace('ai_response');
await trace.start();
final result = await _aiService.generateResponseSafe(...);
await trace.stop();
```

---

### 5.5 Remote Config ❌ Not Present

No `firebase_remote_config` found. This means:
- Trial limits (`_temporalFreeUses = 5`) are baked into APK
- Product IDs are baked in
- Feature flags cannot be toggled without a release

**Recommended fields for remote config:**

| Key | Default | Use |
|-----|---------|-----|
| `temporal_trial_limit` | 5 | A/B test trial counts |
| `si_console_trial_limit` | 8 | Adjust without release |
| `premium_cache_ttl_hours` | 72 | Tune verification frequency |
| `ai_request_debounce_ms` | 500 | Tune rate limiting |
| `maintenance_mode` | false | Emergency kill switch |

---

### 5.6 Monitoring & Alerting ❌ Not Set Up

No Firebase Alerts or uptime checks referenced. Recommended:

- **Crashlytics alert:** Email when crash-free sessions drop below 99%
- **Analytics funnel:** Track paywall shown → purchase started → success
- **BigQuery export:** For SQL-based cohort analysis after launch

---

### 5.7 Backup & Sync Strategy ⚠️ Local Only

**Current:** All user data (tasks, missions, logs) stored locally via `SharedPrefsRuntimePersistence`.

**Risk:** User reinstalls app → all data lost. No cloud backup.

**Recommended approach:**

```
Option A: Firebase Firestore sync (full cloud backup)
  - Bi-directional sync on app foreground
  - Works across devices
  - Effort: HIGH (6-10 hrs)

Option B: Firebase Firestore export-only on sign-out
  - Write snapshot to Firestore on sign-out/app close
  - Restore on next login
  - Effort: MEDIUM (3-5 hrs)

Option C: Document in Privacy Policy, add warning on delete
  - Tell users their data is local
  - Show confirmation on sign-out
  - Effort: LOW (1 hr)
```

Currently the codebase does **Option C** implicitly (no Firestore sync seen). Explicitly implement warning UI.

---

## 6. Refactoring Suggestions

### 6.1 Extract `ConsoleIntentParser` (High Value)

**Current:** `updateFromConsole()` is 100+ lines mixing NLU, state mutation, and AI calls.  
**Problem:** Untestable, violates single responsibility.

```dart
// ✅ NEW: lib/core/si/console_intent_parser.dart
enum ConsoleIntent {
  addTask,
  energyLow,
  energyHigh,
  deadlineRaise,
  workloadLight,
  workloadHeavy,
  general,
}

class ParsedIntent {
  const ParsedIntent({
    required this.intents,
    this.taskTitle,
  });
  final Set<ConsoleIntent> intents;
  final String? taskTitle;

  bool get has => (ConsoleIntent i) => intents.contains(i);
}

class ConsoleIntentParser {
  static ParsedIntent parse(String raw) {
    final String lower = raw.toLowerCase();
    final Set<ConsoleIntent> intents = <ConsoleIntent>{};

    if (lower.startsWith('add:')) {
      intents.add(ConsoleIntent.addTask);
      return ParsedIntent(intents: intents, taskTitle: raw.substring(4).trim());
    }
    if (lower.contains('overwhelmed') || lower.contains('drained')) {
      intents.add(ConsoleIntent.energyLow);
    }
    if (lower.contains('focus') || lower.contains('energized')) {
      intents.add(ConsoleIntent.energyHigh);
    }
    if (lower.contains('deadline') || lower.contains('urgent')) {
      intents.add(ConsoleIntent.deadlineRaise);
    }
    if (lower.contains('light workload')) intents.add(ConsoleIntent.workloadLight);
    if (lower.contains('heavy workload')) intents.add(ConsoleIntent.workloadHeavy);
    if (intents.isEmpty) intents.add(ConsoleIntent.general);

    return ParsedIntent(intents: intents);
  }
}
```

---

### 6.2 Persist Trial Counters (Critical)

**Current:** In-memory counters reset on app restart.  
**Fix:** Read/write from `RuntimePersistence` snapshot.

```dart
// In AppState._loadFromSnapshot():
_temporalTrialUses = (snapshot['temporalTrialUses'] as int?) ?? 0;
_siConsoleTrialUses = (snapshot['siConsoleTrialUses'] as int?) ?? 0;

// In AppState._buildSnapshot():
snapshot['temporalTrialUses'] = _temporalTrialUses;
snapshot['siConsoleTrialUses'] = _siConsoleTrialUses;
```

Since `_autoSave()` is already called after trial consume, this addition persists trials across restarts with no structural change.

---

### 6.3 Guard `_allowMockBilling` Against Release

```dart
// ❌ Current:
static const bool _allowMockBilling = bool.fromEnvironment(
  'CHRONOSPARK_ENABLE_MOCK_BILLING',
  defaultValue: false,
);

// ✅ Fixed: kReleaseMode always wins
static bool get _allowMockBilling {
  if (kReleaseMode) return false;  // Hard block in production
  return bool.fromEnvironment(
    'CHRONOSPARK_ENABLE_MOCK_BILLING',
    defaultValue: false,
  );
}
```

Same fix applies to `Env.isMockLoginEnabled`.

---

### 6.4 Structured Error with Severity

```dart
// ❌ Current: runtimeError is just a String
String? runtimeError;

// ✅ Better: typed with severity
enum ErrorSeverity { info, warn, error }

class AppError {
  const AppError(this.message, {this.severity = ErrorSeverity.error});
  final String message;
  final ErrorSeverity severity;
}

// In AppState:
AppError? runtimeError;

// UI renders differently per severity:
// info → blue snackbar
// warn → amber snackbar
// error → red snackbar
```

---

### 6.5 `ProductIds` Constants Class

```dart
// lib/core/constants/product_ids.dart
abstract final class ProductIds {
  static const String premiumMonthly = 'chronospark_premium_monthly';
  static const String premiumYearly  = 'chronospark_premium_yearly';
  static const Set<String> all = <String>{premiumMonthly, premiumYearly};
}
```

Replace all string literals referencing product IDs with `ProductIds.premiumMonthly`.

---

### 6.6 Add `kDebugMode` Guard to Logger

```dart
// ✅ Prevent debug prints leaking to production output
static void info(String message) {
  assert(() {
    if (Env.enableVerboseLogs) debugPrint('[INFO] $message');
    return true;
  }());
}
```

`assert` blocks are removed in release builds by the Dart compiler — zero-cost in production.

---

## 7. Summary & Priority Matrix

### 7.1 Critical (Fix Before Release)

| # | Issue | File | Effort |
|---|-------|------|--------|
| C1 | Trial counters not persisted (restart bypass) | `app_state.dart` | 1-2 hrs |
| C2 | Missing runtime notification permission request | `main.dart` or shell | 1 hr |
| C3 | `_allowMockBilling` not blocked in release | `app_state.dart` | 30 min |
| C4 | `Env.isMockLoginEnabled` not blocked in release | `env.dart` | 30 min |
| C5 | Logger.error() not routing to Crashlytics | `logger.dart` | 1 hr |
| C6 | Hard-coded seed tasks shown on first launch | `app_state.dart` | 1-2 hrs |

**Total: ~7-9 hours**

---

### 7.2 High Priority (This Sprint)

| # | Issue | File | Effort |
|---|-------|------|--------|
| H1 | Missing analytics events (trial, paywall, purchase) | multiple | 2-3 hrs |
| H2 | Add `warn` level to Logger | `logger.dart` | 30 min |
| H3 | Extract `ConsoleIntentParser` | new file | 1-2 hrs |
| H4 | Add widget tests for MainShell, TemporalOpsPage | new test files | 3-4 hrs |
| H5 | Rate-limit AI console input (debouncer) | `si_console_home.dart` | 1 hr |
| H6 | Add `ProductIds` constants class | new constants file | 30 min |
| H7 | Typed `AppError` with severity | `app_state.dart` | 1-2 hrs |

**Total: ~10-13 hours**

---

### 7.3 Medium Priority (Next Sprint)

| # | Issue | File | Effort |
|---|-------|------|--------|
| M1 | Add Firebase Performance Monitoring | `pubspec.yaml`, services | 2-3 hrs |
| M2 | Add Firebase Remote Config | `pubspec.yaml`, env config | 2-3 hrs |
| M3 | Data backup warning UI on sign-out | settings | 1 hr |
| M4 | Play Console Data Safety form | Play Console (manual) | 2 hrs |
| M5 | `MockBillingService` not instantiated in prod | `app_state.dart` | 30 min |
| M6 | Unit tests for `ConsoleIntentParser` | new test file | 1-2 hrs |
| M7 | `Env.isProduction` needs `kReleaseMode` guard | `env.dart` | 30 min |

**Total: ~10-12 hours**

---

### 7.4 Overall Effort Estimate

| Phase | Effort |
|-------|--------|
| Critical (pre-release blockers) | 7-9 hrs |
| High priority | 10-13 hrs |
| Medium priority | 10-12 hrs |
| **Total** | **27-34 hours** |

---

## Appendix: Quick Reference

**Files Reviewed:**

- [android/app/src/main/AndroidManifest.xml](../android/app/src/main/AndroidManifest.xml)
- [android/app/build.gradle.kts](../android/app/build.gradle.kts)
- [lib/core/config/env.dart](../lib/core/config/env.dart)
- [lib/core/system/telemetry_service.dart](../lib/core/system/telemetry_service.dart)
- [lib/core/utils/logger.dart](../lib/core/utils/logger.dart)
- [lib/core/utils/network_resilience.dart](../lib/core/utils/network_resilience.dart)
- [lib/core/state/app_state.dart](../lib/core/state/app_state.dart)
- [lib/core/system/mock_billing_service.dart](../lib/core/system/mock_billing_service.dart)
- [lib/features/settings/screens/settings_home.dart](../lib/features/settings/screens/settings_home.dart)
- [test/unit/\*](../test/unit/) (10 files)
- [test/widget/auth_gate_widget_test.dart](../test/widget/auth_gate_widget_test.dart)
- [integration_test/auth_flow_integration_test.dart](../integration_test/auth_flow_integration_test.dart)
