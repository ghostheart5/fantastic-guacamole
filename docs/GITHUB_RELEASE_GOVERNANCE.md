# GitHub Pages, PR Lockdown, and Android AAB Release

## 1. GitHub Pages connection

- Workflow: `.github/workflows/main.yml`
- Host URL: `https://ghostheart5.github.io/fantastic-guacamole`
- App URL constant is set in `lib/ui/constants/app_urls.dart`.

## 2. Stop pull requests from changing main

Two controls are configured in-repo:

1. `.github/CODEOWNERS` requires maintainer ownership review.
2. `.github/workflows/pr-policy.yml` fails PRs to `main` unless the immutable
   pull-request author ID belongs to `ghostheart5` or Copilot agent. A maintainer rerun cannot
   turn another author's PR into an authorized PR.

To enforce this in GitHub settings:

1. Open repository Settings -> Branches.
2. Add branch protection rule for `main`.
3. Enable:
   - Require a pull request before merging
   - Require review from Code Owners
   - Require status checks to pass before merging
4. Select required checks (use the exact current names shown in GitHub):
   - `enforce-maintainer-only`
   - `Analyze & Test`
   - `database`
   - `build` (the Pages/legal/App Links validation job; it now runs on every PR
     so the required check cannot remain pending on non-site changes)
5. Enable Restrict who can push to matching branches and allow only `ghostheart5`.

The repository files cannot prove or change those live GitHub settings. Read
back branch protection after any settings change; do not claim Code Owner or
push-restriction enforcement from `CODEOWNERS` alone.

## 3. Android AAB release

- Workflow: `.github/workflows/android-release.yml`
- Trigger: push a tag like `v1.2.3`
- Output: signed AAB, SHA-256 checksum, and CI evidence uploaded as workflow
  artifacts and GitHub release assets.
- The tag must match the `pubspec.yaml` semantic version. Missing production
  secrets fail the workflow; no development-readiness fallback is permitted.
  Publication also waits for the exact-source hosted-emulator QA smoke gate.
- Repository-side gates are documented in
  [`CI_CD_RELEASE_GATES.md`](CI_CD_RELEASE_GATES.md). Device, Play Console,
  and signed-artifact runtime checks remain separate release-phase evidence.

Required repository secrets:

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_STORE_PASSWORD`
- `ANDROID_KEY_PASSWORD`
- `ANDROID_KEY_ALIAS`
- Optional Firebase file:
  - `ANDROID_GOOGLE_SERVICES_JSON_BASE64` or `ANDROID_GOOGLE_SERVICES_JSON`
- Runtime defines used by release build:
  - `CHRONOSPARK_SUPABASE_URL`
  - `CHRONOSPARK_SUPABASE_ANON_KEY`
  - `CHRONOSPARK_RECEIPT_VERIFY_ENDPOINT`
  - `CHRONOSPARK_AI_PROXY_ENDPOINT`
  - `CHRONOSPARK_ACCOUNT_DELETE_ENDPOINT`
  - `CHRONOSPARK_ANDROID_SHA256_CERT`
  - `CHRONOSPARK_IOS_TEAM_ID`

Local AAB build command:

```powershell
./scripts/verify_android_upload_key.ps1
flutter build appbundle --release
```

Expected upload certificate SHA1:

`8A:24:D7:BA:AC:AB:52:F0:A3:77:7D:D0:47:C9:07:96:2E:82:FA:A5`

If verification fails, your local/CI keystore is not the Play Console upload key.
Replace `ANDROID_KEYSTORE_BASE64` (CI) and `android/app/key.jks` or the keystore pointed to by `android/key.properties` (local) with the correct upload keystore.
