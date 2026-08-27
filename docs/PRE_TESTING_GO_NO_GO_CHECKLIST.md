# ChronoSpark Pre-Testing Go/No-Go Checklist

Use this checklist as the release gate before formal internal/closed testing.

Status legend:
- [x] Ready now (verified in repo/docs/workflows)
- [ ] Not ready (action required before go)
- [~] Partially ready (needs runtime/manual confirmation)

## 1) Scope and test goals
- [ ] Define explicit entry/exit criteria for the test cycle.
- [ ] Freeze the exact test scope (features, platforms, environments, integrations).
- [ ] Confirm required test types: unit, widget/UI, integration, smoke, regression, security, performance, accessibility.
- [ ] Set pass/fail thresholds (critical defects allowed, reopen policy, stop/go criteria).

## 2) Build and environment readiness
- [~] App build pipeline exists (Flutter CI and web deploy workflows are configured), but full tester build validation is still required.
- [~] Environment toggles/defines are documented for tester builds (`docs/CLOSED_TESTING_PREP.md`), but production enforcement alignment is still pending.
- [~] Runtime tester flags are documented, but final tester runbook is not yet centralized in one place.
- [ ] Signed Android test bundle flow must be executed and verified with real keystore materials.
- [ ] Validate test backend/service readiness for auth, billing verification, and account lifecycle endpoints.
- [ ] Confirm feature flags are deterministic and locked for the test cycle.

## 3) Dependency and config health
- [~] Dependency lockfile is present (`pubspec.lock`), but dependency install validation in this environment is blocked without Flutter SDK.
- [x] Lockfile is committed.
- [ ] Run an asset/localization integrity pass to confirm no missing runtime resources.
- [ ] Confirm test-environment endpoints/keys are correct and non-production where required.
- [ ] Re-run secret scanning before distribution.

## 4) Quality gates (must pass before test cycle)
- [ ] `flutter analyze` pass recorded on current branch and CI run.
- [ ] Unit/widget tests pass on current branch.
- [ ] Integration tests pass on target device/emulator matrix.
- [~] CI pipeline exists and runs on PR/main, but latest branch run must be confirmed green at go-time.
- [ ] Flaky-test check completed for critical-path suites.
- [ ] Clean-install smoke pass completed (startup/login/navigation/crash-free verification).

## 5) Test design and coverage
- [~] Smoke and closed-testing checklists exist, but full master test plan still needs final consolidation.
- [ ] Map requirements to test cases for traceability.
- [ ] Add explicit edge-case/failure-path checklist coverage.
- [ ] Add negative tests (invalid input, offline, timeout, auth-failure, billing-failure).
- [ ] Confirm permission coverage for deny/allow/revoke behavior.
- [ ] Confirm migration/upgrade path coverage between app versions.

## 6) Data and account setup
- [ ] Prepare tester accounts/roles (tester, standard user, admin/support if applicable).
- [ ] Prepare resettable seed data and environment reset process.
- [ ] Confirm no production PII is used in test datasets.
- [ ] Define billing/subscription test scenarios and expected outcomes.
- [~] Account lifecycle is partially testable; deletion backend endpoint remains a known blocker for full readiness.

## 7) UX/accessibility readiness
- [ ] Validate navigation, route guards, and deep links on test builds.
- [ ] Verify user-facing error messages are clear and actionable.
- [ ] Run accessibility pass (semantics, screen reader labels, text scaling, contrast, focus order).
- [ ] Validate responsive behavior on target device classes/screen sizes.

## 8) Reliability/performance/security basics
- [~] Error/crash telemetry appears wired, but runtime verification in tester build is still required.
- [ ] Confirm logs/diagnostics are sufficient for triage and support.
- [ ] Define and verify startup/performance budget targets.
- [ ] Validate offline/poor-network behavior across critical flows.
- [ ] Run security sanity checks for auth, token storage, transport, and input handling.
- [x] Vulnerability reporting path is now documented in `SECURITY.md`.

## 9) Release-channel test readiness
- [~] Internal/closed-testing guidance exists; final go/no-go upload run is still pending.
- [ ] Confirm store metadata for testers (notes, support contact, policy URLs, listing text/screenshots).
- [ ] Confirm build/version naming and traceability for test artifacts.
- [ ] Define rollback and rollback-trigger conditions for bad test drops.

## 10) Test execution operations
- [ ] Define defect workflow (severity, priority, owner, SLA, reopen rules).
- [ ] Set triage cadence and meeting owner.
- [ ] Define daily test status dashboard/reporting format.
- [ ] Define retest and regression execution policy.
- [ ] Prepare a test-exit report template.

---

## Repo-specific feedback summary

### Already good
- Flutter CI workflow uses `flutter pub get`, `flutter analyze`, and `flutter test`.
- Both `test/` and `integration_test/` directories exist in the repository.
- Closed-testing and smoke-readiness docs already exist.

### Fix now (high priority)
- Keep checklist docs in sync with repository reality (example stale item corrected in `docs/google_play_release_checklist.md`).
- Complete signed Android tester bundle path with real keystore/key.properties handling.
- Validate and close known backend gaps for billing/entitlements/account deletion before wider testing.

### Go/No-Go decision rule

Only mark **GO** when all mandatory blockers in sections 2, 4, 6, and 9 are complete and verified with a fresh test build.
