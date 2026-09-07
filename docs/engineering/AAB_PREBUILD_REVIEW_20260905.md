# ChronoSpark internal/closed-testing prebuild review

Date: September 5, 2026. Target: Google Play internal or closed testing.
The user requested audit, cleanup, and preparation, stopping before the actual
AAB build. No APK/AAB build, device installation, upload, deployment, signing-key
change, commit, or push is part of this review.

## Source and scope

- Checkout: `C:\Users\keegan radetski\Documents\Codex\2026-09-01\t\ChronoSpark-app-only-priority2`.
- Branch: `fix/app-only-readiness-priority2-20260902`.
- Starting HEAD: `d2f1bf934b5e3eeef7f26c9918e8954dc6318594`.
- Starting tracked source was clean. Existing untracked evidence and ignored
  local signing files were preserved. Cleanup changes remain an uncommitted
  working-tree patch across 24 reviewed files; historical CI does not certify
  that patch. The exact allowlist is `test-results/aab-prebuild-20260905/reviewed-files.txt`.
- Intended profile: existing default cloud production configuration for a
  contained test-track candidate. Mock QA and optional local-profile builds are
  separate profiles. No disabled capability was enabled.

## Findings and repairs

| Finding | Severity / evidence | Disposition |
| --- | --- | --- |
| An asynchronous task lookup could resume after an account transition and use the next account's mutation service; delayed creation could repopulate a cleared account. | High; executable regressions reproduced an A edit changing B's task and task recreation after clear. | TaskActions captures the account namespace and boundary generation, binds lookup/mutation services, and abandons stale continuations and side effects. CreateTask rechecks cancellation immediately before saving. Fourteen regressions cover switch, return, reset, creation, completion, skip, disposal, and late lookup failures. |
| Nexus promised queued changes would synchronize despite disabled capability or opt-in. | Medium; active provider source and focused provider tests. | Queue count is preserved with accurate local status and capability/preference-aware copy, including loading/error states. |
| Secret scanning crashed on Git-quoted Unicode paths and could skip bracketed names. | Medium; reproduced Windows failure, plus executable fixtures. | Shared UTF-8, NUL-delimited Git discovery; literal file checks; seven regression fixtures added to CI. Ignored files remain ignored by the content scan, and signing-path checks remain enforced. |
| Local production builder only checked setting presence before compilation. | Medium; source control flow. | Existing release and production configuration guards now validate the exact generated cloud defines and Android Firebase file before signing-file copies or Flutter compilation. Temporary JSON uses a unique filename and UTF-8 without BOM. |
| Three Dart files failed the non-writing format check. | Low; formatter result. | Formatted only the three identified files, plus changed test files. |
| Release checklist pointed to July evidence as a quick readiness gate. | Low; documentation contradiction. | July evidence is explicitly historical; checklist links here and preserves the older signed candidate's limited evidence. Obsolete Android Billing floor comment removed. |
| Existing terminology and billing source-contract expectations were stale. | Low; diagnostic host failures. | Reworded one internal deletion-recovery comment and updated the billing contract to require the stronger cloud-mode plus five-part launch-containment gate. No billing feature was enabled. |

Implementation evidence, relative to the exact checkout above:

- Task mutations: `lib/state/providers/task_provider.dart:100`, operation
  identity at `:755`; final creation guard at `lib/domain/usecases/create_task.dart:36`.
- Nexus synchronization status: `lib/state/providers/nexus_decision_provider.dart:84`
  and `:104`.
- Filename-safe scanning: `scripts/repository_scan_files.ps1:1`, consumed by
  `scripts/secret_content_guard.ps1:11` and `scripts/security_secret_guard.ps1:15`.
- Build guard ordering: `scripts/build_android_aab_prod_guarded.ps1:220` and `:222`.
- Contract cleanup: `test/release/production_billing_offer_contract_test.dart:153`
  and internal comment `lib/features/settings/ui/settings_screen.dart:965`.

These are high-confidence local findings and executed local regressions. Their
runtime frequency in a shipped artifact is unmeasured; no live data breach or
deployed-backend change is asserted by this review.

## Current local verification

Execution logs and machine-readable reports are under
`test-results/aab-prebuild-20260905/` (local ignored evidence).

| Check | Result and evidence limit |
| --- | --- |
| Final Flutter analysis | PASS; Flutter 3.44.6 / Dart 3.12.2, no issues. Follow-on comment/contract files also passed focused analysis. |
| Final formatting | PASS; 1,115 Dart files checked without changes. Final contract-test edit was separately formatted. |
| Final focused regressions | PASS; 54 tests across task actions, task usecases, creator mapping, Nexus, terminology, and billing contracts; zero failures/errors/skips. Covers every failure from the diagnostic full run. |
| Nexus provider regressions | PASS; eight tests. |
| Secret content scan | PASS on preserved repository/evidence filenames after repair. Not a historical secret scan or a credential rotation. |
| Secret scanner execution contract | PASS; seven disposable Git fixture cases. |
| Edge source/tests | PASS; 29 files formatted/linted, seven entrypoints type-checked, 83 tests across ten files, zero failures/errors/skips. Local fixtures only; no database replay or live backend request. |
| Workflow checks | PASS; actionlint and 12 workflow policy checks. |
| Maestro definitions | PASS; 21 files, static validation only. |
| Architecture | PASS; 738 production Dart files at initial scan. |
| PowerShell parse | PASS; 47 maintained scripts. |
| Golden comparison contract | PASS; eight logical comparisons and 16 platform masters. Actual Windows comparisons passed in the final full host test run; no new human visual review. |
| Coverage/version guard contracts | PASS. |
| Dependency inventory/resolver reports | PASS; lockfile/direct dependency/capability consistency, `flutter pub deps --json`, and `flutter pub outdated --json`. None of the 67 reported entries is discontinued or currently retracted. Updates are available; no packages were upgraded and the lockfile is unchanged. This is not a complete vulnerability-advisory audit. |
| QA compile-time configuration | PASS; 15 tests, zero skips. This does not produce a QA app. |
| Candidate artifact-verifier unit tests | PASS; ten Python/Java negative/format fixture tests. No real bundle was built or signed. |
| Diagnostic full host run | Completed 2,424 tests: 2,420 passed, three assertion failures, one error, zero skips. Two stale contracts and two task regressions compiled against earlier source were repaired and pass in the fresh 54-test run. Original manifest retained without relabeling it as a pass. |
| Diagnostic coverage | PASS against the ratchet: 71.8% overall; warnings for 29 files counted at zero and several higher aspirational targets. This coverage came from the diagnostic run. |
| Frozen-source full host suite | PASS; 2,424 tests, zero failures/errors/skips, terminal success and exit code 0. `flutter-final-tests-manifest.json` records the final run; the original diagnostic manifest remains separate. |
| Final coverage | PASS against the ratchet: 71.8% overall and 91.4% critical-only. Twenty-nine production files are conservatively counted at zero. Usecases, state, paywall, backup, and auth remain below their higher target percentages; all enforced floors pass. |
| Existing local signing-file guard | FAIL: ignored `android/key.properties` contains non-placeholder signing fields. It is not the known CI bootstrap. Values were not disclosed; file was preserved. This is a local build-environment blocker, not a confirmed committed-secret leak. |

## Build handoff and remaining gates

The working tree must not be described as ready to run the current local AAB
builder: it intentionally rejects untracked evidence, uncommitted changes, and
pre-existing temporary signing paths. This environment also has no `.env` and
none of the six required cloud settings in the checked process/user scopes.
Do not manufacture configuration, delete the evidence, replace signing identity,
enable mock/tester access, or relax the guards to obtain a pass.

The existing protected **Android Candidate Build Only** CI lane is the practical
candidate path. It uses separate source and tooling checkouts and existing
protected configuration. It currently pins historical app source `61c7331d` and
CI run `33939436515`; those values must not be relabeled as evidence for this
patch. Its signature/ELF validators still require a real built artifact later.

The next authorized preparation must:

1. Review/freeze this bounded patch and preserve an exact source commit.
2. Confirm an unused Play version code; source currently remains
   `4.1.0+2026083003`. The current Console high-water mark was not inspected.
3. Obtain passing required CI for that exact source and update the candidate
   source/CI pair truthfully, preserving protected signing/configuration.
4. Stop before dispatching the build-only workflow or running `flutter build`.

After a separately authorized build: verify signer, manifest, target API,
version, native alignment, symbols, and install the exact artifact through the
chosen test track. Authentication/recovery/deletion, account isolation,
offline/restart behavior, accessibility, and tester experience need final-build
runtime evidence. Store eligibility, declarations, reviewer access, release notes,
and public service checks remain separate. The prior physical candidate and
prior database CI passes apply only to their recorded source/scenarios.

Source configuration uses package `com.ghostheart5.chronospark`, API 36 floor,
AGP 8.11.1, Gradle 8.14.3, Java 17. The locked Android IAP plugin declares Billing
8.0.0 in its cached source; resolved final-artifact dependencies remain unverified.
API and Billing policy were checked against current official
[target API requirements](https://support.google.com/googleplay/android-developer/answer/11926878?hl=en)
and [Billing deprecation schedule](https://developer.android.com/google/play/billing/deprecation-faq).
Native-library readiness must follow current
[Android 16 KB guidance](https://developer.android.com/guide/practices/page-sizes)
and artifact/device inspection, not AGP version alone.

## Final evidence identity

`test-results/aab-prebuild-20260905/final-source-snapshot.json` records SHA-256
hashes for 1,477 relevant source/configuration/test/asset files. The final full
host run started after the last executable-source changes. The snapshot was
rechecked after the run with zero drift; HEAD and dependency lockfile are
unchanged. `test-results/aab-prebuild-20260905/prebuild-summary.json` records the
final local result and remaining gates. This working-source identity is not a
Git commit, signed bundle identity, or exact-commit CI result.

## Decision

Conditionally ready for source freeze and required CI. The local audit, bounded
cleanup, and host validation are complete. The source commit, matching CI result,
unused Play version, and clean protected build environment remain prerequisites
before invoking the actual AAB build. No actual build was started. Production
release approval, complete device UAT, and live backend correctness are not
established.
