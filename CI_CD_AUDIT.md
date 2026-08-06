# ChronoSpark — CI/CD Audit

**Date:** 2026-08-06
**Workflows:** 6 · **Guard scripts:** ~35 PowerShell files in `scripts/`
**Runners:** `ubuntu-latest` (5), `macos-latest` (1)

---

## Summary

The release workflow contains one control most projects lack — it decodes the upload keystore and **verifies its SHA-1 fingerprint against an expected value before building**, catching a wrong-keystore mistake at the point it matters. Secrets are properly sourced from GitHub Secrets rather than committed, and the two most important workflows pin `subosito/flutter-action` to a commit SHA.

Against that, the security-scanning workflow analyzes a language the project doesn't meaningfully contain, the release path has no test or analysis gate, and no workflow pins a Flutter version.

| ID | Severity | Finding |
|---|---|---|
| CI-01 | HIGH | CodeQL analyzes only Swift — effectively zero coverage of a Dart codebase |
| CI-02 | HIGH | Release workflow runs no tests and no analysis |
| CI-03 | HIGH | Flutter version unpinned in all six workflows → non-reproducible builds |
| CI-04 | MEDIUM | Keystore decoded to disk, never cleaned up |
| CI-05 | MEDIUM | Secrets interpolated into shell command lines |
| CI-06 | MEDIUM | No `permissions:` block on most workflows → default token scope |
| CI-07 | MEDIUM | No automated dependency scanning (no Dependabot/Renovate) |
| CI-08 | MEDIUM | No publish path to the Play Console |
| CI-09 | LOW | `jekyll-docker.yml` is an unmodified template in a Flutter repo |
| CI-10 | LOW | Inconsistent action pinning (SHA vs `@v2` vs `@v4` vs `@v5`) |
| CI-11 | LOW | `continue-on-error: true` masks SARIF upload failures |
| CI-12 | LOW | Guard scripts are Windows-only; most never run in CI |
| CI-13 | INFO | No iOS build, no SBOM, no changelog automation |

---

## Per-workflow summary

| Workflow | Trigger | Runner | Purpose | Assessment |
|---|---|---|---|---|
| `android-release.yml` | `push` (tags) | ubuntu | Build signed AAB | Strong signing; **no test gate**, no publish |
| `dart.yml` | `push`, `pull_request` | ubuntu | Analyze, test, coverage | The real CI gate |
| `main.yml` | `push`, `workflow_dispatch` | ubuntu | Deploy Flutter web → GitHub Pages | Functional; asserts secrets present |
| `codeql.yml` | `push`, `pull_request`, `dispatch` | macos | Security scanning | **Scans nothing relevant** |
| `linux-release.yml` | `workflow_dispatch` | ubuntu | Linux tester build | Manual only; low risk |
| `pr-policy.yml` | `pull_request` | ubuntu | PR policy checks | Enforcement depends on unreadable branch protection |

---

## CI-01 · HIGH · CodeQL analyzes a language the project barely contains

**File:** `.github/workflows/codeql.yml:20-24`

```yaml
      matrix:
        include:
          - language: swift
            ...
            runner: macos-latest
```

The matrix declares exactly one language: **`swift`**. This is a Flutter application — 719 Dart files under `lib/`. CodeQL has **no Dart or Flutter analyzer**, and `ios/` is an unmodified `flutter create` scaffold, so the scan covers essentially nothing.

**Impact:** The repository advertises a passing CodeQL check and uploads SARIF results, implying the application has been statically analyzed for security defects. It has not. Not one line of the 719 Dart files, none of the SQL migrations, and neither TypeScript edge function is examined.

Note what this scan *would* have missed if anyone relied on it: `SUP-01`, the `using (true)` RLS policy that exposes every user's data. That is exactly the kind of finding a security pipeline exists to surface.

**Production risk:** False assurance. A reviewer, auditor, or compliance process reading "CodeQL: passing" reasonably concludes static analysis is in place.

**Fix — one of:**
- **Remove the workflow.** No scanning is more honest than scanning nothing, and it stops consuming macOS runner minutes (the most expensive tier).
- **Replace with tooling that covers this stack:** `dart analyze --fatal-infos`, a Dart security linter, `deno lint` for the edge functions, and a SQL policy review step. If CodeQL is retained for the edge functions, declare `javascript-typescript` — that at least covers `supabase/functions/`.

---

## CI-02 · HIGH · The release workflow has no quality gate

**File:** `.github/workflows/android-release.yml`

Steps, in order: checkout → Flutter → deps → security secret guard → decode keystore → write `key.properties` → verify upload-key fingerprint → Firebase config → validate production configuration → **build signed AAB** → upload artifact → create GitHub Release.

There is no `flutter test` and no `flutter analyze`.

**Impact:** A tag pushed on a commit that fails all 136 tests still produces a signed, shippable AAB and a published GitHub Release. `dart.yml` does run analysis and tests, but on `push`/`pull_request` — nothing makes the release job depend on its outcome. If a tag is pushed to a branch whose CI is red, or before CI completes, the release proceeds regardless.

**Production risk:** A broken build reaching a release artifact with no signal that anything is wrong.

**Fix:** Insert before the build step:

```yaml
- name: Analyze
  run: flutter analyze --fatal-infos
- name: Test
  run: flutter test
```

Better still, make the release job `needs:` the CI job so the gate cannot be bypassed by trigger timing.

---

## CI-03 · HIGH · Flutter version is unpinned everywhere

**Files:** `android-release.yml:21` · `dart.yml:26` · `main.yml:27` · `codeql.yml:59` · `linux-release.yml:20`

Every workflow specifies `channel: stable` with no `flutter-version`. Each run resolves whatever `stable` points to that day.

`android-release.yml:19` and `dart.yml:24` **do** pin the action itself to a commit SHA (`1a449444c387b1966244ae4d4f8c696479add0b2`) — correct supply-chain hygiene — and then let the SDK the action installs float freely. The pin protects against a compromised action but not against a changed compiler.

**Impact:** Release builds are not reproducible. Rebuilding a shipped tag weeks later can produce a different binary from different framework code. Stable-channel Flutter releases change plugin behaviour, Gradle requirements, and — critically for this project — **`flutter.targetSdkVersion`**.

That last point makes this a compliance issue, not just a hygiene one. `android/app/build.gradle.kts:65` sets `targetSdk = maxOf(flutter.targetSdkVersion, 34)`, so the app's Play-required target SDK is *whatever the Flutter version supplies* — 36 under the currently installed 3.44.6. An unpinned SDK means the Play compliance of the artifact is determined at build time by an uncontrolled input.

**Production risk:** Non-reproducible releases; inability to bisect a regression to a code change; silent shifts in Play-relevant build parameters.

**Fix:**

```yaml
- uses: subosito/flutter-action@1a449444c387b1966244ae4d4f8c696479add0b2
  with:
    flutter-version: '3.44.6'
    channel: stable
```

Add a `.fvmrc` or `.tool-versions` pinning the same version so local builds match, and treat SDK upgrades as deliberate, reviewed commits.

---

## CI-04 · MEDIUM · Keystore written to disk with no cleanup

**File:** `.github/workflows/android-release.yml:30-31`

```yaml
      - name: Decode keystore
        run: echo "${{ secrets.ANDROID_KEYSTORE_BASE64 }}" | base64 --decode > android/app/key.jks
```

The upload keystore is materialized at `android/app/key.jks` and `key.properties` is written alongside it. No later step removes either.

**Impact:** The signing key persists in the workspace for the remainder of the job. Concrete exposure paths:
- Any subsequent step — including a compromised third-party action — can read it.
- `actions/upload-artifact@v4` (line 131) is scoped to the AAB path, so it is not captured today; a future broadening of that path would publish the signing key.
- On self-hosted runners the workspace can outlive the job.

The upload key is not the app signing key under Play App Signing, which limits blast radius — but it is still the credential that authorizes uploads for this package, and its compromise requires a Play Console key reset.

**Fix:** Add an `if: always()` cleanup step so it runs even when the build fails:

```yaml
- name: Clean up signing material
  if: always()
  run: rm -f android/app/key.jks android/key.properties
```

---

## CI-05 · MEDIUM · Secrets interpolated into shell command lines

**File:** `.github/workflows/android-release.yml:67, 118-127`

```yaml
ACTUAL_SHA1=$(keytool -list -v -keystore android/app/key.jks -storepass "${{ secrets.ANDROID_STORE_PASSWORD }}" -alias "$(awk ...)" ...)
```

```yaml
flutter build appbundle --release
  --dart-define=CHRONOSPARK_SUPABASE_ANON_KEY=${{ secrets.CHRONOSPARK_SUPABASE_ANON_KEY }}
  ...
```

`${{ secrets.* }}` expressions are substituted into the command string before execution, placing secret values in process arguments.

**Impact:** GitHub masks secret values in log output, so the primary leak channel is closed. The residual risks are real but narrower: process arguments are visible via `/proc/<pid>/cmdline` to anything else on the runner; masking fails if a value is transformed (base64, substring) before printing; and a non-zero exit that echoes the failing command can defeat masking in some tool output.

Severity is tempered by context — the Supabase anon key is publishable by design, and the endpoint URLs are not secrets. `ANDROID_STORE_PASSWORD` at line 67 is the value that genuinely matters.

**Fix:** Pass secrets through the environment rather than the command line:

```yaml
- name: Verify upload key fingerprint
  env:
    STORE_PASSWORD: ${{ secrets.ANDROID_STORE_PASSWORD }}
  run: |
    ACTUAL_SHA1=$(keytool -list -v -keystore android/app/key.jks -storepass "$STORE_PASSWORD" ...)
```

The workflow already uses this pattern correctly at lines 35-37 and 80-81 — it is simply not applied consistently.

---

## CI-06 · MEDIUM · Missing `permissions:` blocks

Only `main.yml` requires elevated permissions (`pages: write`, `id-token: write` for Pages deployment). The others show no `permissions:` block, so they inherit the repository default — which, unless the org has changed it, is read/write across contents, issues, pull requests, and packages.

`android-release.yml` needs `contents: write` for its GitHub Release step; `dart.yml` and `codeql.yml` need far less (`codeql.yml` needs `security-events: write` for SARIF upload).

**Impact:** Any compromised or malicious action in these workflows receives a broadly-scoped `GITHUB_TOKEN`. Since `codeql.yml`, `main.yml`, and `linux-release.yml` use floating action tags (CI-10), a compromised upstream tag would inherit write access to repository contents.

**Fix:** Add least-privilege blocks:

```yaml
# dart.yml
permissions:
  contents: read
# android-release.yml
permissions:
  contents: write
# codeql.yml
permissions:
  contents: read
  security-events: write
```

---

## CI-07 · MEDIUM · No automated dependency scanning

No `.github/dependabot.yml`, no Renovate configuration, no `osv-scanner` step.

**Impact:** With ~50 direct and several hundred transitive Dart packages, plus Gradle and Deno dependencies, a published CVE reaches this project only if a maintainer happens to read about it. `DEPENDENCY_AUDIT.md` DEP-09 identifies `hive` 2.2.3 as discontinued upstream — exactly the kind of drift automated scanning surfaces continuously.

**Fix:**

```yaml
# .github/dependabot.yml
version: 2
updates:
  - package-ecosystem: "pub"
    directory: "/"
    schedule: { interval: "weekly" }
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule: { interval: "weekly" }
  - package-ecosystem: "gradle"
    directory: "/android"
    schedule: { interval: "weekly" }
```

The `github-actions` entry also fixes CI-10 on an ongoing basis.

---

## CI-08 · MEDIUM · No publish path to the Play Console

`android-release.yml` ends at `actions/upload-artifact@v4` and a GitHub Release. There is no `r0adkll/upload-google-play`, no Fastlane, and no Play Developer API step.

**Impact:** Every release requires a human to download an artifact and hand-upload it — a manual step at the most consequential point in the process, with no track management, staged rollout, or release-note automation.

**Fix:** See `GOOGLE_PLAY_AUDIT.md` GP-02. Note this needs a **separate** service account from the one used by `verify-receipt`.

---

## CI-09 · LOW · Unmodified Jekyll template in a Flutter repository

**File:** `.github/workflows/jekyll-docker.yml`

GitHub's default Jekyll starter workflow, triggered on `push` and `pull_request`. This project has no Jekyll site — web deployment is handled by `main.yml` building Flutter web.

**Impact:** Runner minutes consumed on every push and PR for nothing, plus a check in the PR status list that carries no information. Persistent no-signal checks are actively harmful: they train reviewers to ignore the status list, which is where genuine failures appear.

**Fix:** Delete the file.

---

## CI-10 · LOW · Inconsistent action pinning

| Action | Version | Used in |
|---|---|---|
| `subosito/flutter-action` | `@1a449444c387…` **(SHA)** | `android-release.yml:19`, `dart.yml:24` |
| `subosito/flutter-action` | `@v2` (floating) | `codeql.yml:57`, `linux-release.yml:18`, `main.yml:25` |
| `actions/checkout` | `@v5` | `android-release.yml:16`, `main.yml:22` |
| `actions/checkout` | `@v4` | `codeql.yml:27`, `dart.yml:19`, `jekyll-docker.yml:18`, `linux-release.yml:15` |
| `actions/upload-artifact` | `@v4` | `android-release.yml:131` |
| `github/codeql-action/*` | `@v4` | `codeql.yml:51, 80, 90` |
| `codecov/codecov-action` | `@v4` | `dart.yml:47` |
| `actions/upload-pages-artifact` | `@v3` | `main.yml:88` |
| `actions/deploy-pages` | `@v4` | `main.yml:101` |

**Good news:** no deprecated versions are in use. `actions/upload-artifact@v3` — shut down in January 2025 and now a hard failure — is **not** present; the repo correctly uses `@v4`. `actions/checkout@v2`/`v3` are absent.

**Impact:** Mutable tags mean a compromised or breaking upstream release is consumed automatically. The inconsistency is the real signal: the same action is SHA-pinned in the release workflow and floating in three others, so the security intent exists but was not applied uniformly. Combined with CI-06's permissive default token, a compromised floating action would run with write access.

**Fix:** SHA-pin all third-party actions (`subosito/flutter-action`, `codecov/codecov-action`). GitHub-owned `actions/*` and `github/*` are lower risk, but pin them too for reproducibility. Dependabot's `github-actions` ecosystem keeps SHA pins updated automatically.

---

## CI-11 · LOW · `continue-on-error` masks SARIF upload failures

**File:** `.github/workflows/codeql.yml:90-91`

```yaml
        uses: github/codeql-action/upload-sarif@v4
        continue-on-error: true
```

If the SARIF upload fails, the job still reports success. Combined with CI-01, the security workflow can pass while both scanning nothing *and* failing to upload the nothing it found.

**Fix:** Remove `continue-on-error: true`. If uploads are genuinely flaky, add a retry rather than suppressing the result. This is the only `continue-on-error`/`|| true` masking found across all six workflows — otherwise the workflows do not hide failures.

---

## CI-12 · LOW · Guard scripts are Windows-only and mostly unreferenced

`scripts/` holds ~35 PowerShell files, including `release_guard.ps1`, `strict_gate.ps1`, `strict_android_runtime_gate.ps1`, `security_secret_guard.ps1`, `verify_android_upload_key.ps1`, `verify_protected_files.ps1`, and `coverage_guard.ps1`.

**Only one is invoked by CI:** `android-release.yml:26` runs the security secret guard. The rest are runnable only on a Windows developer machine, while every CI runner is `ubuntu-latest` (except CodeQL's macOS).

**Impact:** A guard that CI never executes provides no enforcement — it is documentation of an intended control, not the control. `release_guard.ps1` and `strict_gate.ps1` in particular sound like exactly the release-blocking checks CI-02 is missing, but they cannot block anything they are not wired into.

There is also a **cross-platform gap**: several scripts assume Windows paths and PowerShell semantics, so porting them to CI is not a matter of adding an invocation.

**Fix:** Decide per script — promote to CI (rewriting in `bash` or invoking via `pwsh`, which is preinstalled on GitHub runners), or delete. The `security_secret_guard.ps1` precedent shows PowerShell *can* run on the ubuntu runners, so the port is tractable. Its pattern coverage should be reviewed against the key formats in use (`sk-ant-`, `eyJ`, `AIza`, `-----BEGIN`) — see `SECURITY_AUDIT.md` SEC-05.

---

## CI-13 · INFO · Coverage gaps

| Missing | Consequence |
|---|---|
| iOS build/test workflow | iOS regressions invisible; `ios/` appears to be an unmodified scaffold |
| SBOM generation | No dependency inventory for compliance or CVE response |
| Changelog automation | Release notes are manual |
| Integration-test execution | `integration_test/` exists; no workflow runs it |
| `dart format --set-exit-if-changed` | Formatting drift unchecked |

`dart.yml` does run analysis, tests, and Codecov upload — verify the coverage threshold is actually **enforced** rather than merely reported, or coverage regressions pass silently.

---

## Secrets inventory

Referenced across workflows:

| Secret | Used in | Purpose |
|---|---|---|
| `ANDROID_KEYSTORE_BASE64` | android-release | Upload keystore |
| `ANDROID_STORE_PASSWORD` | android-release | Keystore password |
| `ANDROID_KEY_PASSWORD` | android-release | Key password |
| `ANDROID_KEY_ALIAS` | android-release | Key alias |
| `ANDROID_GOOGLE_SERVICES_JSON_BASE64` / `_JSON` | android-release | Firebase config |
| `CHRONOSPARK_SUPABASE_URL` | android-release, main | Supabase endpoint |
| `CHRONOSPARK_SUPABASE_ANON_KEY` | android-release, main | Publishable anon key |
| `CHRONOSPARK_RECEIPT_VERIFY_ENDPOINT` | android-release | Edge function URL |
| `CHRONOSPARK_AI_PROXY_ENDPOINT` | android-release | Edge function URL |
| `CHRONOSPARK_ACCOUNT_DELETE_ENDPOINT` | android-release | Edge function URL — **function does not exist** (`SECURITY_AUDIT.md` SEC-08) |
| `CHRONOSPARK_ANDROID_SHA256_CERT` | android-release | App Links (`GOOGLE_PLAY_AUDIT.md` GP-03) |
| `CHRONOSPARK_IOS_TEAM_ID` | android-release | Universal Links |
| `CODECOV_TOKEN` | dart | Coverage upload |
| `GITHUB_TOKEN` | codeql | Built-in |

**Not present, and needed for CI-08:** a Play Console publishing service account.

The workflow handles missing secrets **well**: `android-release.yml:110-115` disables production-readiness enforcement when Supabase secrets are absent and emits `::warning::` rather than failing silently, and `main.yml:31` hard-fails the web deploy if Supabase secrets are missing. That is the right instinct — it just needs extending to Firebase config (`FIREBASE_AUDIT.md` FB-01), where absence currently produces a silently Firebase-less release build.

---

## Priority

1. **CI-01** — remove or replace CodeQL. It currently provides negative value by implying coverage that does not exist.
2. **CI-02** — add the test/analysis gate to the release path.
3. **CI-03** — pin `flutter-version` everywhere; this also stabilizes the Play `targetSdk` guarantee.
4. **CI-04, CI-05, CI-06** — signing-material cleanup, env-based secrets, least-privilege tokens.
5. **CI-07** — Dependabot, which also resolves CI-10 continuously.
6. **CI-09, CI-11, CI-12** — remove noise, unmask failures, resolve the guard-script backlog.
