# MERGE AUDIT REPORT
**Generated:** 2026-08-08  
**Repository:** ghostheart5/fantastic-guacamole  
**Base Branch:** `main` (f2585a2)  
**Operator:** Copilot Coding Agent

---

## PHASE 1 — BRANCH INSPECTION

### Branches Ahead of Main (at time of audit)

| Branch | Ahead | Behind | Conflicts | Status |
|---|---|---|---|---|
| `backup-before-form-and-ux-phase` | 90 | 41 | 228 | HIGH risk — conflicts |
| `fix/guard-mojibake-microbatch` | 24 | 41 | 176 | HIGH risk — conflicts |
| `backup-before-flow-cleanup` | 13 | 41 | 173 | HIGH risk — conflicts |
| `copilot/ensure-release-signing-safeguards` | 11 | 287 | 1 | HIGH risk — conflicts |
| `backup-before-onboarding-redesign` | 10 | 41 | 169 | HIGH risk — conflicts |
| `copilot/refactor-premium-access-check` | 7 | 287 | 0 | MEDIUM — far behind, core Dart |
| `copilot/chronospark-testing-api-keys-tokens` | 5 | 349 | 3 | HIGH risk — conflicts |
| `copilot/fix-dart-build-check` | 4 | 6 | 0 | ✅ LOW — test files |
| `copilot/add-gitignore-file` | 4 | 312 | 0 | ✅ LOW — .gitignore |
| `copilot/fix-prompt-injection-and-validation` | 3 | 287 | 0 | MEDIUM — far behind, core Dart |
| `copilot/clean-up-github-repo-structure` | 2 | 64 | 0 | MEDIUM — docs/CI, multiple files |
| `copilot/fix-failing-github-actions-job-another-one` | 2 | 43 | 0 | ✅ LOW — CI workflow |
| `rescue/chronospark-stabilization` | 2 | 41 | 62 | HIGH risk — conflicts |
| `copilot/audit-v2-0` | 2 | 41 | 0 | ⚠️ SKIPPED — Supabase migration |
| `copilot/rewrite-logs-for-clarity` | 2 | 287 | 0 | MEDIUM — far behind, core Dart |
| `copilot/implement-token-expiration-fix` | 2 | 287 | 1 | HIGH risk — conflicts |
| `copilot/google-play-store-compliance` | 2 | 287 | 0 | MEDIUM — far behind, core Dart |
| `copilot/analyze-widget-rebuilds` | 2 | 287 | 0 | MEDIUM — far behind, core Dart |
| `copilot/add-token-refresh-cancellation` | 2 | 287 | 9 | HIGH risk — conflicts |
| `copilot/webwell-knownapple-app-site-association` | 2 | 239 | 0 | MEDIUM — far behind, CI |
| `copilot/fix-github-actions-dart-build` | 1 | 6 | 0 | ✅ LOW — test support |
| `copilot/find-missing-secrets` | 1 | 44 | 0 | ✅ LOW — android CI |
| `copilot/add-supabase-flutter-package` | 1 | 43 | 0 | ⚠️ SKIPPED — Supabase migration |
| `copilot/fix-privacy-policy-page` | 1 | 314 | 0 | MEDIUM — far behind, HTML asset |
| `copilot/account-deletion` | 1 | 312 | 2 | HIGH risk — conflicts |
| `copilot/update-changelog-for-version-1-1-0` | 1 | 310 | 0 | ✅ LOW — CHANGELOG only |
| `copilot/upcoming-features-long-term-goals` | 1 | 310 | 0 | ✅ LOW — ROADMAP only |
| `copilot/security-reporting-vulnerabilities` | 1 | 310 | 1 | HIGH risk — conflicts |
| `copilot/requirements-txt-package-json-etc` | 1 | 310 | 0 | ✅ LOW — requirements.txt |
| `copilot/guidelines-for-contributors` | 1 | 310 | 0 | ✅ LOW — CONTRIBUTING.md |
| `copilot/github-templates` | 1 | 310 | 4 | HIGH risk — conflicts |
| `copilot/ci-cd-config` | 1 | 310 | 0 | ✅ LOW — CI config |
| `copilot/add-code-of-conduct` | 1 | 310 | 5 | HIGH risk — conflicts |
| `copilot/firebase-registration` | 1 | 290 | 3 | HIGH risk — conflicts |
| `copilot/fix-purchase-verification` | 1 | 287 | 0 | MEDIUM — far behind, core Dart |
| `copilot/check-dispose-controllers-streams` | 1 | 287 | 0 | MEDIUM — far behind, core Dart |
| `copilot/add-structured-debug-logs` | 1 | 287 | 0 | MEDIUM — far behind, core Dart |
| `copilot/firebase-configuration-file-generation` | 1 | 239 | 1 | HIGH risk — conflicts |
| `copilot/create-account-deletion-page` | 1 | 130 | 4 | HIGH risk — conflicts |

---

## PHASE 2 — BACKUP

| Item | Status |
|---|---|
| Backup branch name | `copilot/backup-merge-audit-20260808` |
| Backup commit | `f2585a2` (matches `main` HEAD at audit start) |
| Remote verification | ✅ Exists on origin |

> **Note:** A local branch `backup-before-merge-20260808` was also created. Remote push of non-`copilot/` prefixed branches was blocked (HTTP 403). The pre-existing `copilot/backup-merge-audit-20260808` at the same SHA serves as the effective remote backup.

---

## PHASE 3 — MERGE RISK REPORT

### LOW Risk (eligible for automated merge)
Criteria: 0 git conflicts + changes limited to test files, docs, CI configs, or non-critical assets.

| Branch | Changed Files | Decision |
|---|---|---|
| `copilot/fix-dart-build-check` | `test/features/auth/login_screen_golden_test.dart`, `test/features/nexus/nexus_screen_golden_test.dart` | MERGE |
| `copilot/fix-github-actions-dart-build` | `test/support/golden_harness.dart` | MERGE |
| `copilot/fix-failing-github-actions-job-another-one` | `.github/workflows/main.yml` | MERGE |
| `copilot/find-missing-secrets` | `.github/workflows/android-release.yml` | MERGE |
| `copilot/update-changelog-for-version-1-1-0` | `CHANGELOG.md` | MERGE |
| `copilot/upcoming-features-long-term-goals` | `ROADMAP.md` | MERGE |
| `copilot/requirements-txt-package-json-etc` | `requirements.txt` | MERGE |
| `copilot/guidelines-for-contributors` | `CONTRIBUTING.md` | MERGE |
| `copilot/ci-cd-config` | `.github/workflows/ci.yml` | MERGE |
| `copilot/add-gitignore-file` | `.gitignore` | MERGE |

### MEDIUM Risk (requires manual review before merging)
Criteria: 0 conflicts but branch is 64–314 commits behind main OR touches core Dart/application files.

| Branch | Reason | Recommendation |
|---|---|---|
| `copilot/refactor-premium-access-check` | 287 commits behind; touches `paywall_service.dart`, `app_state.dart` | Manual review — logic may be stale |
| `copilot/fix-prompt-injection-and-validation` | 287 commits behind; touches `si_ai_service.dart`, `app_state.dart` | Manual review — security-sensitive |
| `copilot/clean-up-github-repo-structure` | 64 commits behind; 12 files changed incl. CI workflow | Manual review — workflow changes |
| `copilot/rewrite-logs-for-clarity` | 287 commits behind; touches `app_state.dart` | Manual review — staleness risk |
| `copilot/google-play-store-compliance` | 287 commits behind; touches `env.dart`, `paywall_service.dart` | Manual review — compliance changes |
| `copilot/analyze-widget-rebuilds` | 287 commits behind; touches `main_shell.dart`, UI components | Manual review — UI may have changed |
| `copilot/webwell-knownapple-app-site-association` | 239 commits behind; touches CI workflow | Manual review — CI may be outdated |
| `copilot/fix-privacy-policy-page` | 314 commits behind; touches `privacy_policy.html` | Manual review — asset update |
| `copilot/fix-purchase-verification` | 287 commits behind; touches `paywall_service.dart`, `app_state.dart` | Manual review — payment flow |
| `copilot/check-dispose-controllers-streams` | 287 commits behind; touches `chronocreator_page.dart` | Manual review — memory management |
| `copilot/add-structured-debug-logs` | 287 commits behind; touches `app_state.dart`, `logger.dart` | Manual review — logging changes |

### HIGH Risk — STOP, REQUIRE MANUAL REVIEW
Criteria: 1+ merge conflicts OR touches Supabase (policy exclusion).

| Branch | Conflicts | Action |
|---|---|---|
| `backup-before-form-and-ux-phase` | 228 | STOP — manual resolution required |
| `fix/guard-mojibake-microbatch` | 176 | STOP — manual resolution required |
| `backup-before-flow-cleanup` | 173 | STOP — manual resolution required |
| `backup-before-onboarding-redesign` | 169 | STOP — manual resolution required |
| `rescue/chronospark-stabilization` | 62 | STOP — manual resolution required |
| `copilot/add-token-refresh-cancellation` | 9 | STOP — manual resolution required |
| `copilot/add-code-of-conduct` | 5 | STOP — manual resolution required |
| `copilot/github-templates` | 4 | STOP — manual resolution required |
| `copilot/create-account-deletion-page` | 4 | STOP — manual resolution required |
| `copilot/chronospark-testing-api-keys-tokens` | 3 | STOP — manual resolution required |
| `copilot/firebase-registration` | 3 | STOP — manual resolution required |
| `copilot/account-deletion` | 2 | STOP — manual resolution required |
| `copilot/ensure-release-signing-safeguards` | 1 | STOP — manual resolution required |
| `copilot/implement-token-expiration-fix` | 1 | STOP — manual resolution required |
| `copilot/security-reporting-vulnerabilities` | 1 | STOP — manual resolution required |
| `copilot/firebase-configuration-file-generation` | 1 | STOP — manual resolution required |

### Supabase-Excluded Branches (policy: DO NOT MODIFY SUPABASE)

| Branch | Supabase File | Action |
|---|---|---|
| `copilot/audit-v2-0` | `supabase/migrations/20260719000001_fix_user_daily_metrics_rls.sql` | SKIPPED |
| `copilot/add-supabase-flutter-package` | `supabase/migrations/20260714000001_quickstart_todos.sql` | SKIPPED |

---

## PHASE 4 — SAFE MERGE RESULTS

All 10 LOW-risk branches merged into `main` using `--no-ff` (true merge commits, no squash, no force-push, no history rewrite).

| Branch | Result | Validation Note |
|---|---|---|
| `copilot/fix-dart-build-check` | ✅ MERGED | `flutter` not in agent sandbox — CI will validate |
| `copilot/fix-github-actions-dart-build` | ✅ MERGED | `flutter` not in agent sandbox — CI will validate |
| `copilot/fix-failing-github-actions-job-another-one` | ✅ MERGED | `flutter` not in agent sandbox — CI will validate |
| `copilot/find-missing-secrets` | ✅ MERGED | `flutter` not in agent sandbox — CI will validate |
| `copilot/update-changelog-for-version-1-1-0` | ✅ MERGED | `flutter` not in agent sandbox — CI will validate |
| `copilot/upcoming-features-long-term-goals` | ✅ MERGED | `flutter` not in agent sandbox — CI will validate |
| `copilot/requirements-txt-package-json-etc` | ✅ MERGED | `flutter` not in agent sandbox — CI will validate |
| `copilot/guidelines-for-contributors` | ✅ MERGED | `flutter` not in agent sandbox — CI will validate |
| `copilot/ci-cd-config` | ✅ MERGED | `flutter` not in agent sandbox — CI will validate |
| `copilot/add-gitignore-file` | ✅ MERGED | `flutter` not in agent sandbox — CI will validate |

---

## PHASE 5 — FINAL REPORT

### Merged Branches (10)

1. `copilot/fix-dart-build-check`
2. `copilot/fix-github-actions-dart-build`
3. `copilot/fix-failing-github-actions-job-another-one`
4. `copilot/find-missing-secrets`
5. `copilot/update-changelog-for-version-1-1-0`
6. `copilot/upcoming-features-long-term-goals`
7. `copilot/requirements-txt-package-json-etc`
8. `copilot/guidelines-for-contributors`
9. `copilot/ci-cd-config`
10. `copilot/add-gitignore-file`

### Unmerged — MEDIUM Risk (11): Require Manual Review

- `copilot/refactor-premium-access-check` — 287 behind, touches paywall/app_state
- `copilot/fix-prompt-injection-and-validation` — 287 behind, security-sensitive
- `copilot/clean-up-github-repo-structure` — 64 behind, 12 files
- `copilot/rewrite-logs-for-clarity` — 287 behind
- `copilot/google-play-store-compliance` — 287 behind, touches env/paywall
- `copilot/analyze-widget-rebuilds` — 287 behind, UI files
- `copilot/webwell-knownapple-app-site-association` — 239 behind, CI
- `copilot/fix-privacy-policy-page` — 314 behind, HTML
- `copilot/fix-purchase-verification` — 287 behind, payment flow
- `copilot/check-dispose-controllers-streams` — 287 behind
- `copilot/add-structured-debug-logs` — 287 behind

### Unmerged — HIGH Risk (16): Conflicts — STOP

- `backup-before-form-and-ux-phase` — **228 conflicts**
- `fix/guard-mojibake-microbatch` — **176 conflicts**
- `backup-before-flow-cleanup` — **173 conflicts**
- `backup-before-onboarding-redesign` — **169 conflicts**
- `rescue/chronospark-stabilization` — **62 conflicts**
- `copilot/add-token-refresh-cancellation` — 9 conflicts
- `copilot/add-code-of-conduct` — 5 conflicts
- `copilot/github-templates` — 4 conflicts
- `copilot/create-account-deletion-page` — 4 conflicts
- `copilot/chronospark-testing-api-keys-tokens` — 3 conflicts
- `copilot/firebase-registration` — 3 conflicts
- `copilot/account-deletion` — 2 conflicts
- `copilot/ensure-release-signing-safeguards` — 1 conflict
- `copilot/implement-token-expiration-fix` — 1 conflict
- `copilot/security-reporting-vulnerabilities` — 1 conflict
- `copilot/firebase-configuration-file-generation` — 1 conflict

### Policy-Excluded (2): Supabase

- `copilot/audit-v2-0`
- `copilot/add-supabase-flutter-package`

### Build Blockers

- `flutter` toolchain absent from agent sandbox — GitHub Actions CI on `main` push will validate the 10 merged branches
- 16 conflict branches require human conflict resolution before merging
- `backup-before-*` branches (169–228 conflicts) represent major historical divergence — recommend cherry-picking over full merge

### Recommended Next Actions

1. **Merge this PR** to land the 10 LOW-risk merges + audit report on `main`
2. **Monitor CI** — the GitHub Actions pipeline will run `flutter analyze` and `flutter test` on `main` after merge
3. **MEDIUM branches** — rebase each on current `main`, review diff for staleness, submit as PRs
4. **HIGH-conflict branches** — assign a developer per branch for manual conflict resolution; then rebase + PR
5. **Supabase branches** — apply migrations via Supabase dashboard/CLI after human review
6. **Do NOT delete any branches** — preserve all for history and potential cherry-picks

---

*This report was generated automatically. No branches were deleted. No history was rewritten. No force pushes were performed. All conflicts resulted in STOP.*
