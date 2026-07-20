# GitHub Pages, PR Lockdown, and Android AAB Release

## 1. GitHub Pages connection

- Workflow: `.github/workflows/main.yml`
- Host URL: `https://ghostheart5.github.io/fantastic-guacamole`
- App URL constant is set in `lib/ui/constants/app_urls.dart`.

## 2. Stop pull requests from changing main

Two controls are configured in-repo:

1. `.github/CODEOWNERS` requires maintainer ownership review.
2. `.github/workflows/pr-policy.yml` fails PRs to `main` unless actor is `ghostheart5`.

To enforce this in GitHub settings:

1. Open repository Settings -> Branches.
2. Add branch protection rule for `main`.
3. Enable:
   - Require a pull request before merging
   - Require review from Code Owners
   - Require status checks to pass before merging
4. Select required checks:
   - `PR Policy / enforce-maintainer-only`
   - `Dart / build`
   - `Deploy Flutter Web to GitHub Pages / build`
5. Enable Restrict who can push to matching branches and allow only `ghostheart5`.

## 3. Android AAB release

- Workflow: `.github/workflows/android-release.yml`
- Trigger: push a tag like `v1.2.3`
- Output: signed AAB uploaded as workflow artifact and GitHub release asset.

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
flutter build appbundle --release `
  --dart-define=CHRONOSPARK_APP_FLAVOR=prod `
  --dart-define=CHRONOSPARK_ENFORCE_PROD_READINESS=true
```

Expected upload certificate SHA1:

`13:60:98:6B:E3:45:4F:75:52:56:2E:9A:97:CE:CE:37:74:E2:FD:46`

If verification fails, your local/CI keystore is not the Play Console upload key.
Replace `ANDROID_KEYSTORE_BASE64` (CI) and `android/app/key.jks` or the keystore pointed to by `android/key.properties` (local) with the correct upload keystore.