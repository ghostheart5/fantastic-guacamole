# Audit v2.0 Scorecard

**Audit date:** 2026-07-19  
**App version:** 4.0.0+2026071133  
**Flutter:** 3.44.0 · Dart 3.12.0  
**Scope:** Full second-pass audit covering security, session management, Phase 1 roadmap completion, feature coverage, testing, and Play Store readiness.

---

## Summary

| Domain | Status | Critical | High | Medium |
|---|---|---|---|---|
| Supabase Security | ⚠️ Fixed | 1 fixed | 1 fixed | 0 |
| Auth & Session | ✅ Mostly solid | 0 | 1 open | 1 open |
| Phase 1 Roadmap | ⚠️ Partial | 0 | 2 open | 1 open |
| Feature Coverage | ✅ Complete | 0 | 0 | 0 |
| Test Coverage | ⚠️ Gaps | 0 | 0 | 5 open |
| CI / Build | ✅ Green | 0 | 0 | 0 |
| Play Store Readiness | ⚠️ Pre-upload | 0 | 3 open | 2 open |

---

## 1. Supabase Security

### 1.1 user_daily_metrics SELECT policy — BOLA/IDOR ✅ Fixed (this PR)

**Finding:** Migration `202607110002_data_policies.sql` created:
```sql
create policy "user_daily_metrics_select_authenticated"
on public.user_daily_metrics
for select
to authenticated
using (true);
```
`using (true)` allowed every authenticated user to read every other user's daily metrics. BOLA vulnerability.

**Fix applied:** Migration `20260719000001_fix_user_daily_metrics_rls.sql` replaces this policy:
```sql
create policy "user_daily_metrics_select_own"
  on public.user_daily_metrics for select to authenticated
  using ((select auth.uid()) = user_id);
```

### 1.2 user_daily_metrics UPDATE USING clause — row hijack via null user_id ✅ Fixed (this PR)

**Finding:** Original UPDATE policy:
```sql
using (user_id is null or auth.uid() = user_id)
```
The `user_id is null` branch lets any authenticated user update rows that were inserted without a user_id (possible during sign-up edge cases).

**Fix applied:** Same migration tightens to:
```sql
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id)
```

### 1.3 handle_new_user reads raw_user_meta_data — ✅ Acceptable

The `handle_new_user` trigger (SECURITY DEFINER) copies `raw_user_meta_data->>'full_name'` into `profiles`. This is user-editable metadata, but it is used only for initial profile seeding, not for authorization decisions. Acceptable.

### 1.4 purchase_bindings — ✅ Correct

CRUD policies all use `auth.uid() = user_id` with proper `WITH CHECK` on INSERT and UPDATE. No issues.

### 1.5 Storage bucket chronospark-sync — ✅ Correct

SELECT, INSERT, UPDATE (with both USING and WITH CHECK), and DELETE policies all enforce `split_part(name, '/', 1) = auth.uid()::text`. No issues.

### 1.6 profiles — ✅ Correct

SELECT, INSERT, UPDATE policies all enforce `auth.uid() = id`. UPDATE has both USING and WITH CHECK. No issues.

---

## 2. Auth & Session Management

### 2.1 Credential-based sign-in rate limiting — ✅ Present

`AuthService` tracks `_failedSignInAttempts` and enforces exponential back-off up to 60 s. Effective local guard.

### 2.2 Token refresh — ✅ Present via SDK

`supabase_flutter ^2.16.0` auto-refreshes sessions. `AuthService.getIdToken(forceRefresh: true)` and `reloadCurrentUser()` both call `refreshSession()` when needed. The original Phase 1 concern about stale tokens is substantially mitigated by the SDK.

### 2.3 Pre-request JWT expiry check — ⚠️ Absent (HIGH)

No callers in `si_ai_service.dart`, `paywall_repository.dart`, or `workspace_store_service.dart` call `getIdToken(forceRefresh: true)` before making authenticated network requests. Supabase's SDK handles this transparently in most cases, but a manual pre-check guard would eliminate the edge case window.

**Recommendation:** Add `await authService.getIdToken(forceRefresh: true)` inside `AuthService._requireFreshToken()` helper and call it in network-critical paths.

### 2.4 Operation cancellation (CancelToken) — ⚠️ Not implemented (HIGH)

No `CancelToken` utility exists. Long-running AI or paywall calls cannot be cancelled when a widget is disposed. The user sees hanging UI or out-of-order responses.

**Recommendation:** Implement `CancelToken` in `lib/core/utils/cancel_token.dart` and integrate with the SI AI and paywall flows.

### 2.5 Sign-out mid-operation guards — ⚠️ Missing (MEDIUM)

`SIAIService` and `WorkspaceStoreService` do not check `currentUser != null` before writing results. A sign-out during an in-flight request will silently write orphaned data.

**Recommendation:** Add a `currentUser` guard before any write that targets user-scoped storage.

### 2.6 ExpiredSessionCleanup — ✅ Present

`state/services/expired_session_cleanup.dart` clears stale session tokens from `SecureStore` on startup by inspecting `expiresAt` or falling back to a `RetentionPolicy` timestamp. Addresses the cleanup concern from v1.

### 2.7 Mock auth gating — ✅ Correct

`AlwaysAuthenticatedAuthService` and `MockAuthService` are only activated when `mockMode` or `mockLoginEnabled` feature flags are set. Production builds cannot enable these without dart-define flags.

---

## 3. Phase 1 Roadmap Completion (from AUDIT_SUMMARY.md)

| Item | Status |
|---|---|
| Token freshness check | ✅ Substantially addressed via SDK; pre-request explicit guard still missing |
| CancelToken implementation | ❌ Not started |
| Sign-out guards | ❌ Not started |
| Prompt length validation | Check below |
| EventQueueService (telemetry) | ✅ Addressed via OfflineSyncQueueService |
| Error recovery UI | Not verified |
| Transient auth retry | Not verified |

### 3.1 Prompt length validation

```bash
grep -r "5000\|maxLength\|prompt.*length\|length.*prompt" lib/ --include="*.dart"
```
No explicit prompt character limit found in `si_ai_service.dart` or `SIInputPacket`. **Still missing.**

---

## 4. Feature Coverage

All 29 expected feature folders are present.

| Feature | Dart files | Status |
|---|---|---|
| auth | 3 | ✅ |
| goals | Present | ✅ |
| tasks | Present | ✅ |
| timeline | Present | ✅ |
| milestones | Present | ✅ |
| insights | Present | ✅ |
| progression | Present | ✅ |
| memories | Present | ✅ |
| soul_map | Present | ✅ |
| si_console | Present | ✅ |
| coach | Present | ✅ |
| paywall | Present | ✅ |
| notifications | Present | ✅ |
| settings | Present | ✅ |
| profile | Present | ✅ |
| onboarding | Present | ✅ |
| flowmap | Present | ✅ |
| nexus | Present | ✅ |
| logs | Present | ✅ |
| home | Present | ✅ |
| emotion | Present | ✅ |
| plan | Present | ✅ |
| admin | 1 | ✅ |
| creator | Present | ✅ |
| focus | Present | ✅ |
| help | Present | ✅ |
| permissions | Present | ✅ |
| support | Present | ✅ |

Smart Coach audit (2026-07-11): 16/16 topics PASS, 7/7 audit questions PASS.

---

## 5. Dependencies

| Package | Version | Notes |
|---|---|---|
| supabase_flutter | ^2.16.0 | Current; auto-refresh in place |
| flutter_riverpod | ^3.3.2 | Current |
| go_router | ^17.3.0 | Current |
| in_app_purchase | ^3.2.0 | Current |
| firebase_core | ^4.11.0 | Current |
| firebase_crashlytics | ^5.0.0 | Current |
| firebase_analytics | ^12.0.0 | Current |
| firebase_messaging | ^16.0.0 | Current |
| flutter_secure_storage | ^10.3.1 | Current |
| hive | ^2.2.3 | Stable; no known CVEs for this use |

Unused packages from v1 audit (`vibration`, `path_provider`, `riverpod_annotation`) are flagged by the project's own audit script but do not introduce security risk.

---

## 6. Test Coverage

| Area | Tests | Status |
|---|---|---|
| Domain value objects | 8 | ✅ |
| Domain policies | 6 | ✅ |
| Domain usecases | Present | ✅ |
| Auth error messages | 1 | ✅ |
| Session recovery | 2 | ✅ |
| Deep link parsing | Present | ✅ |
| Paywall deferred queue | Present | ✅ |
| AI deferred queue | Present | ✅ |
| Token expiration scenarios | 0 | ❌ Missing |
| Sign-out during operation | 0 | ❌ Missing |
| CancelToken | 0 | ❌ Missing (feature not built) |
| Prompt length limits | 0 | ❌ Missing |
| Concurrent SecureStore access | 0 | ❌ Missing |

Total test files: 98 (up from 36 covered at v1 time).

---

## 7. CI / Build

| Check | Status |
|---|---|
| `flutter analyze` | ✅ PASS (2026-07-11) |
| `flutter test` | ✅ PASS (2026-07-11) |
| `flutter build apk --debug` | ✅ PASS (2026-07-11) |
| `flutter build appbundle` | ✅ PASS (2026-07-11) |
| CodeQL workflow | ✅ Present |
| Dart workflow | ✅ Present |
| PR policy enforced | ✅ Maintainer-only |
| GitHub Pages deploy | ✅ Automated |
| Android AAB release | ✅ Tag-triggered, signed |

---

## 8. Google Play Readiness

| Gate | Status |
|---|---|
| Package ID aligned | ✅ `com.ghostheart5.chronospark` |
| Privacy policy URL | ✅ Hosted and linked |
| Delete account URL | ✅ Hosted |
| Support email | ⚠️ Needs Play Console entry |
| Signed AAB produced | ⚠️ Not yet uploaded |
| Data Safety form | ⚠️ Manual action required |
| Closed testing notes | ⚠️ Draft in PLAY_CLOSED_TESTING_AUDIT.md |
| Upload keystore | ⚠️ Requires `android/key.properties` |
| Firebase options verified | ⚠️ Needs re-verification |
| Runtime POST_NOTIFICATIONS permission | ⚠️ Not implemented (Android 13+) |

---

## 9. Remaining Open Items by Priority

### 🔴 Must Fix Before Play Upload

1. **POST_NOTIFICATIONS runtime permission** — Android 13+ (API 33) requires an explicit runtime permission request before scheduling local notifications. Without it, notifications are silently dropped on new devices.
2. **Data Safety form** — Manual Play Console action; no code required.
3. **Upload keystore** — Create `android/key.properties` and place `key.jks`.

### 🟠 High Priority (Next Sprint)

4. **CancelToken** — Implement in `lib/core/utils/cancel_token.dart`; integrate into SI AI and paywall flows. Prevents orphaned requests and UX confusion on widget dispose.
5. **Pre-request token freshness helper** — `AuthService._requireFreshToken()` → call before any Supabase-authenticated network operation. Eliminates rare 401 edge case not covered by SDK auto-refresh.

### 🟡 Medium Priority

6. **Sign-out guards** — Add `currentUser != null` checks before user-scoped writes in `WorkspaceStoreService` and `SIAIService`.
7. **Prompt length limit** — Cap `SIInputPacket.text` at 5,000 chars to prevent over-length API payloads.
8. **Edge case tests** — Token expiration, sign-out mid-op, prompt limit, concurrent SecureStore access.

---

## 10. References

- [`AUDIT_SUMMARY.md`](AUDIT_SUMMARY.md) — v1 audit roadmap and Phase 1/2/3 plan
- [`SMART_COACH_AUDIT.md`](SMART_COACH_AUDIT.md) — Coach topic coverage (all PASS)
- [`PLAY_CLOSED_TESTING_AUDIT.md`](PLAY_CLOSED_TESTING_AUDIT.md) — Play upload gate checklist
- [`SECURITY_PRIVACY_AUDIT.md`](SECURITY_PRIVACY_AUDIT.md) — Security controls checklist
- [`FINAL_AUDIT_SCORECARD.md`](FINAL_AUDIT_SCORECARD.md) — Master checklist (update after each sprint)
- Supabase migration fixed in this PR: `supabase/migrations/20260719000001_fix_user_daily_metrics_rls.sql`
