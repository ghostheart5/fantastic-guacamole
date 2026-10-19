# Axiomara branch reconciliation — 2026-10-19

Baseline: `832d972e50eeaffdd03ce61d16655fdf57806527` (`4.2.5+2026101702`).

## Scope and preservation

The owner authorized reconciling still-needed fixes into main and testing before protected merges. Work is isolated in `codex/axiomara-branch-reconciliation-20261019`. Existing worktrees, dirty native/DataStore work, untracked assets and branch refs are preserved. No production backend, schema, app installation or Play release is changed by this reconciliation.

The live inventory contains 117 remote branches including main: 64 other branch tips are ancestors of main; 12 additional branches have equivalent patches under other commits; 40 branches have unmatched patches requiring the dispositions below. Those branches share 186 unique unmatched nonmerge commits. Commit/hash inequality alone is not a missing-feature finding. Local branch tips were also compared; their unmatched commits are included in these remote histories.

## Fixes carried forward

- `211af349`: QA Monkey package binding and immutable source/APK/seed/config checks, plus its 12 regression tests.
- `177d14c2`: encrypted full planning snapshots, Timeline date-only serialization, strict validation, account/CAS/local-edit guards, rollback and provider refresh, with matching English/Spanish scope disclosure and regressions.
- Selected `5bcdef1b` hunks: local profile welcome destination copy, bilingual widget tests and compatible QA journey selectors. Current guide pause behavior, Back semantics and profile seeding are retained.

## Validation

Pending final results. All required protected checks must succeed before merge. Host unit/widget tests and disposable backend tests are distinct from physical-device, production-backend and Play release acceptance.

## Complete remote branch disposition

| Branch | Unmerged commits | Disposition |
| --- | ---: | --- |
| `build/register-candidate-tooling-20260904` | 0 | Tip already in main history. |
| `claude/first-run-guide-repairs` | 0 | Tip already in main history. |
| `codex/ai-refusal-policy-20260926` | 0 | Tip already in main history. |
| `codex/axiomara-2050` | 0 | Tip already in main history. |
| `codex/axiomara-3102-release-prep-20261002` | 0 | Tip already in main history. |
| `codex/axiomara-3102-tutorial-clock-fix-20261002` | 0 | Tip already in main history. |
| `codex/axiomara-3103-datastore-symbol-repair-20261004` | 0 | Tip already in main history. |
| `codex/axiomara-3103-release-version-20261003` | 0 | Tip already in main history. |
| `codex/axiomara-anr-state-parser-20261017` | 0 | Tip already in main history. |
| `codex/axiomara-aosp-smoke-20261017` | 0 | Tip already in main history. |
| `codex/axiomara-app-icon-20261017` | 0 | Tip already in main history. |
| `codex/axiomara-app-usability-repairs-20261017` | 0 | Tip already in main history. |
| `codex/axiomara-bundletool-diagnostics-20261004` | 0 | Tip already in main history. |
| `codex/axiomara-candidate-3090-20260926` | 0 | Tip already in main history. |
| `codex/axiomara-discovery-assets-20261010` | 0 | Tip already in main history. |
| `codex/axiomara-emulator-bootstrap-20261011` | 0 | Tip already in main history. |
| `codex/axiomara-es-learning-copy-20261003` | 0 | Tip already in main history. |
| `codex/axiomara-finished-docs-20261005` | 0 | Tip already in main history. |
| `codex/axiomara-free-route-handoff` | 2 | Covered by #155 / #157 and the current Planner handoff implementation. |
| `codex/axiomara-full-repair-retest-20261011` | 5 | Superseded by #173: current platform fallback, planner handoff validation and local-policy lane. |
| `codex/axiomara-guide-route-3100` | 0 | Tip already in main history. |
| `codex/axiomara-listing-clarity-20261006` | 0 | Tip already in main history. |
| `codex/axiomara-native-probe-identity-20261017` | 0 | Tip already in main history. |
| `codex/axiomara-next-play-3097` | 1 | All unmatched commits have patch-equivalent changes in main. |
| `codex/axiomara-pages-action-v5` | 1 | All unmatched commits have patch-equivalent changes in main. |
| `codex/axiomara-pages-actions-node24` | 1 | All unmatched commits have patch-equivalent changes in main. |
| `codex/axiomara-public-surface` | 3 | Covered by #117; later current listing assets/copy must remain. |
| `codex/axiomara-qa-runtime-local-profile-20261012` | 5 | Covered by #174 and subsequent Creator receipt/guide fixes in #183. |
| `codex/axiomara-recovery-completion-20261016` | 1 | Carry forward 177d14c2: validated full planning snapshot, Timeline round-trip, rollback, provider refresh and matching disclosures. |
| `codex/axiomara-release-gate-no-applinks` | 0 | Tip already in main history. |
| `codex/axiomara-release-permissions-20261017` | 0 | Tip already in main history. |
| `codex/axiomara-reply-recovery-evidence-4019136` | 5 | Covered by #165; source-bound historical evidence remains historical. |
| `codex/axiomara-tutorial-safety-20260930` | 5 | Covered by 281e96f8, #159 and #183. Retain current explicit guide pause/restart behavior and release version. |
| `codex/candidate-public-source-guard` | 0 | Tip already in main history. |
| `codex/checkout-timeout-cancel-repair-20260926` | 0 | Tip already in main history. |
| `codex/cloud-backup-first-use-20260927` | 0 | Tip already in main history. |
| `codex/cloud-validation-gate-20260926` | 5 | Covered by #137: disposable restore/deletion checks, storage diagnostics and response cleanup. |
| `codex/deletion-native-cors-20260927` | 0 | Tip already in main history. |
| `codex/deletion-owner-readback-20260927` | 1 | All unmatched commits have patch-equivalent changes in main. |
| `codex/device-registration-bounds-3089` | 4 | Covered by #133. Final branch migration and SQL tests are byte-identical to main. |
| `codex/google-account-chooser-repair-20260926` | 0 | Tip already in main history. |
| `codex/google-oauth-grant-repair` | 0 | Tip already in main history. |
| `codex/hosted-deletion-acceptance-20260927` | 0 | Tip already in main history. |
| `codex/intelligence-response-repair-3059` | 0 | Tip already in main history. |
| `codex/login-guide-modal-3084` | 4 | Covered by 729b3a64, #174 and newer guide/UI changes. |
| `codex/play-policy-parity-3086` | 1 | All unmatched commits have patch-equivalent changes in main. |
| `codex/production-3082` | 0 | Tip already in main history. |
| `codex/production-3083` | 2 | Covered by #126 and 729b3a64; preserve current version and callout behavior. |
| `codex/production-candidate-20260901` | 0 | Tip already in main history. |
| `codex/profile-provisioning-repair-20260927` | 0 | Tip already in main history. |
| `codex/public-ai-eligibility-3085` | 1 | All unmatched commits have patch-equivalent changes in main. |
| `codex/public-billing-eligibility-3085` | 0 | Tip already in main history. |
| `codex/public-candidate-gate-3086` | 5 | Historical release evidence; current release gates and newer evidence supersede these old snapshots. |
| `codex/public-capability-checkpoint-20260926` | 0 | Tip already in main history. |
| `codex/public-conversation-access-20260926` | 0 | Tip already in main history. |
| `codex/public-credit-license-qa-3092` | 0 | Tip already in main history. |
| `codex/public-evidence-upload-20260926` | 0 | Tip already in main history. |
| `codex/public-release-pipeline-20260926` | 0 | Tip already in main history. |
| `codex/public-release-profile-20260926` | 2 | Covered by #136 and subsequent public capability/evidence gates. Do not reintroduce obsolete blanket review booleans. |
| `codex/public-surface-2040-20260831` | 0 | Tip already in main history. |
| `codex/refresh-public-release-gate-3090` | 4 | Historical exact-source evidence already superseded by #134 and subsequent release receipts. |
| `codex/release-3069` | 0 | Tip already in main history. |
| `codex/release-3080` | 0 | Tip already in main history. |
| `codex/release-3081-structured` | 5 | Covered by #124 deterministic cited timing, IANA timezone and DST checks. |
| `codex/release-3081` | 19 | Superseded by #124 deterministic timing. Do not reinstate the older regex-only departure-repair path. |
| `codex/release-artifact-path-repair` | 0 | Tip already in main history. |
| `codex/release-readiness-3062` | 0 | Tip already in main history. |
| `codex/restore-rejection-message-20260926` | 0 | Tip already in main history. |
| `codex/restore-terminal-receipt-20260926` | 0 | Tip already in main history. |
| `codex/si-large-text-header-3088` | 4 | Covered by #132. Old screenshots are historical evidence. |
| `codex/spanish-claim-safety-20260926` | 1 | All unmatched commits have patch-equivalent changes in main. |
| `codex/task-due-free-route` | 1 | All unmatched commits have patch-equivalent changes in main. |
| `copilot/fix-database-action-failure` | 1 | All unmatched commits have patch-equivalent changes in main. |
| `copilot/fix-exact-build-qa-runtime` | 2 | Covered by #182; empty Initial plan commit needs no port. |
| `copilot/fix-exact-build-qa-smoke` | 0 | Tip already in main history. |
| `copilot/fix-exact-source-local-qa-apk` | 2 | Covered by #181; empty Initial plan commit needs no port. |
| `copilot/fix-failed-tests` | 0 | Tip already in main history. |
| `copilot/fix-failing-github-actions-job` | 0 | Tip already in main history. |
| `copilot/fix-github-actions-job` | 2 | Current backend-reconciliation workflow retains corrected endpoint/shell and later controls. |
| `fix/aab-prebuild-cleanup-20260905` | 1 | Historical candidate tooling; current candidate/release workflows replace this pinned test candidate. |
| `fix/app-links-release-gate-20260902` | 0 | Tip already in main history. |
| `fix/app-only-readiness-gate1-20260902` | 0 | Tip already in main history. |
| `fix/app-only-readiness-priority2-20260902` | 53 | Historical candidate 3025 native-validation/reviewer-cohort experiments. Current exact-build CI, native smoke and source-bound QA runners supersede these version-pinned workflows. |
| `fix/axiomara-build-tooling-regeneration-20261014` | 1 | All unmatched commits have patch-equivalent changes in main. |
| `fix/axiomara-candidate-signing-memory-20261014` | 1 | All unmatched commits have patch-equivalent changes in main. |
| `fix/axiomara-local-welcome-cta-20261016` | 8 | Carry forward local-mode welcome CTA and bilingual destination tests. Profile seeding and Back semantics are in #183; older automatic-resume pause copy is superseded by current explicit pause tests. |
| `fix/axiomara-monkey-qa-package-20261014` | 1 | Carry forward #180 / 211af349: derive only QA package identity, retain source/APK/seed/config provenance and reject altered config. |
| `fix/axiomara-signing-diagnostics-20261014` | 2 | Covered by #177. Current diagnostics have additional later controls. |
| `fix/axiomara-user-repairs-20261014` | 9 | Covered by #175; keep newer task/reminder and source-bound journey changes. |
| `fix/chronospark-2040-launch-readiness-20260829` | 0 | Tip already in main history. |
| `fix/maestro-planner-clarification-20260907` | 0 | Tip already in main history. |
| `fix/privacy-provider-disclosure-20260912` | 2 | Current canonical privacy and generated copies incorporate the later approved provider disclosures; do not restore old policy copy. |
| `fix/public-terms-billing-20260907` | 2 | Current generated legal surfaces supersede these internal-test policy drafts; no new terms introduced. |
| `fix/release-3059-main-sync` | 0 | Tip already in main history. |
| `fix/release-gate-planner-explanation-20260902` | 0 | Tip already in main history. |
| `fix/retain-billing-runtime-on-main-20260907` | 0 | Tip already in main history. |
| `fix/supabase-migration-inventory-parser-20260902` | 0 | Tip already in main history. |
| `fix/supabase-production-lineage-reconciliation-20260902` | 0 | Tip already in main history. |
| `fix/tagged-release-ref-fetch-20260902` | 0 | Tip already in main history. |
| `google-pub-bases` | 0 | Tip already in main history. |
| `main` | 0 | Current baseline. |
| `release/chronospark-production-candidate-20260821` | 0 | Tip already in main history. |
| `release/closed-test-20260902` | 0 | Tip already in main history. |
| `release/public-policy-20260910` | 2 | Current legal contracts and public-profile guards supersede internal-test-only disclosures. |
| `release/report-privacy-3035` | 1 | All unmatched commits have patch-equivalent changes in main. |
| `test/axiomara-back-candidate-ci-20261016` | 9 | Temporary source-pinned CI/QA review harness; keep current maintained workflows. Inherited app repairs are covered by #175/#183; carry forward missing local CTA via this reconciliation. |
| `test/axiomara-back-s2-qa-review-20261016` | 11 | Temporary source-pinned CI/QA review harness; keep current maintained workflows. Inherited app repairs are covered by #175/#183; carry forward missing local CTA via this reconciliation. |
| `test/axiomara-export-review-20261016` | 11 | Temporary source-pinned CI/QA review harness; keep current maintained workflows. Inherited app repairs are covered by #175/#183; carry forward missing local CTA via this reconciliation. |
| `test/axiomara-focused-welcome-ci-20261016` | 8 | Temporary source-pinned CI/QA review harness; keep current maintained workflows. Inherited app repairs are covered by #175/#183; carry forward missing local CTA via this reconciliation. |
| `test/axiomara-green-native-review-20261016` | 11 | Temporary source-pinned CI/QA review harness; keep current maintained workflows. Inherited app repairs are covered by #175/#183; carry forward missing local CTA via this reconciliation. |
| `test/axiomara-landscape-fixture-ci-20261016` | 11 | Temporary source-pinned CI/QA review harness; keep current maintained workflows. Inherited app repairs are covered by #175/#183; carry forward missing local CTA via this reconciliation. |
| `test/axiomara-qa-apk-build-only-20261015` | 10 | Temporary source-pinned CI/QA review harness; keep current maintained workflows. Inherited app repairs are covered by #175/#183; carry forward missing local CTA via this reconciliation. |
| `test/axiomara-stress-seed-handoff-20261014` | 8 | Temporary source-pinned CI/QA review harness; keep current maintained workflows. Inherited app repairs are covered by #175/#183; carry forward missing local CTA via this reconciliation. |
| `test/hosted-android-20260906-43b70655` | 8 | Historical frozen campaign fixtures; current maintained hosted journey/Monkey tooling supersedes them. Dialog/dropdown/notification repairs retained in current localized implementations. |
| `test/3022-qa-smoke-20260909` | 0 | Tip already in main history. |
| `upgrade/axiomara-memory-router-contracts` | 14 | Covered by 01d7ac0d and #157. Final memory/router files match except later added free due-task routing. |
| `validation/smoke-api34-3039` | 1 | One-off historical API34 smoke workflow override; current scoped API35/16KB runners supersede it. |
