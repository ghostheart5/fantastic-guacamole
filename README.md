# fantastic-guacamole

## Badges

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev/)
[![Dart](https://github.com/ghostheart5/fantastic-guacamole/actions/workflows/dart.yml/badge.svg)](https://github.com/ghostheart5/fantastic-guacamole/actions/workflows/dart.yml)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Android](https://img.shields.io/badge/Android-Supported-3DDC84?logo=android&logoColor=white)](android/)
[![Build Status](https://github.com/ghostheart5/fantastic-guacamole/actions/workflows/main.yml/badge.svg)](https://github.com/ghostheart5/fantastic-guacamole/actions/workflows/main.yml)
[![CodeQL](https://github.com/ghostheart5/fantastic-guacamole/actions/workflows/codeql.yml/badge.svg)](https://github.com/ghostheart5/fantastic-guacamole/actions/workflows/codeql.yml)
[![Security](https://img.shields.io/badge/Security-Best%20Practices-blue)](https://github.com/ghostheart5/fantastic-guacamole/security)

ChronoSpark is a Flutter-based second brain for task planning, adaptive learning, time-blocking, and AI-driven decision support.

For the full architecture and subsystem reference, see [CHRONOSPARK.md](CHRONOSPARK.md).
For the complete documentation index, see [docs/RELEASE_INDEX.md](docs/RELEASE_INDEX.md).
For the master release tracker and scope lock, see [docs/RELEASE_TRACKER.md](docs/RELEASE_TRACKER.md).
For the versioned release roadmap, see [docs/ROADMAP.md](docs/ROADMAP.md).
For contributing guidelines and commit conventions, see [CONTRIBUTING.md](CONTRIBUTING.md).
For the dependency direction contract, see [docs/LAYER_FLOW.md](docs/LAYER_FLOW.md).

## Highlights

- Material 3 Flutter UI with custom glassmorphic components
- Local persistence with `SharedPreferences`
- Adaptive task ranking and SI decision support
- Temporal Ops and SI Console premium trial gating
- Subscription tiers: Base, Premium, Ultimate

## Development

- `flutter analyze`
- `flutter test`
- `flutter run -d windows`

## Integration setup (Supabase, Firebase, Google, GitHub)

- Supabase is required for auth/session in production-style runs:
  - `--dart-define=CHRONOSPARK_SUPABASE_URL=https://<project-ref>.supabase.co`
  - `--dart-define=CHRONOSPARK_SUPABASE_ANON_KEY=<anon-key>`
- Local `.env` support is enabled too:
  - Put the same values in [/.env](.env) or copy [/.env.example](.env.example)
  - The app loads `.env` at startup and the Android build scripts read it as a fallback
- OAuth callback config:
  - `--dart-define=CHRONOSPARK_OAUTH_REDIRECT_URL=https://<your-domain>/app/auth/callback`
  - `--dart-define=CHRONOSPARK_GITHUB_OAUTH_REDIRECT_URL=https://<your-domain>/app/auth/callback`
- Android custom-scheme callback:
  - `chronospark://auth-callback`
  - Add the matching intent filter in `android/app/src/main/AndroidManifest.xml`
- Supabase redirect allowlist:
  - `chronospark://auth-callback`
  - `http://localhost:3000`
  - `http://localhost:8080`
  - `https://chronospark.ai`
  - `https://www.chronospark.ai`
- Firebase is bootstrapped from generated options in `lib/firebase_options.dart`.
  - Re-run FlutterFire CLI if you switch Firebase projects.
- Google and GitHub sign-in are routed through Supabase OAuth in app auth flow.
  - Configure Google and GitHub providers in Supabase Auth, and use matching callback URLs in both provider dashboards.

Supabase Auth console checklist:

1. Open Supabase Dashboard -> Authentication -> Providers.
2. Enable Google provider.
3. Paste the Google OAuth Client ID and Client Secret from Google Cloud.
4. Enable GitHub provider.
5. Paste the GitHub OAuth App Client ID and Client Secret from GitHub Developer Settings.
6. Add these redirect URLs in Authentication -> URL Configuration:
   - `chronospark://auth-callback`
   - `http://localhost:3000`
   - `http://localhost:8080`
   - `https://chronospark.ai`
   - `https://www.chronospark.ai`
7. Use `chronospark://auth-callback` for Android custom-scheme callback testing.
8. Keep `CHRONOSPARK_OAUTH_REDIRECT_URL` and `CHRONOSPARK_GITHUB_OAUTH_REDIRECT_URL` aligned with the same callback route.

Local PowerShell setup:

1. Copy [scripts/chronospark_env.example.ps1](scripts/chronospark_env.example.ps1) to a local-only file outside git tracking.
2. Fill in your real Supabase, OAuth, and release values.
3. Dot-source that file before running the guarded build scripts, or set the same variables in your shell session.

Example run:

- `flutter run --dart-define=CHRONOSPARK_SUPABASE_URL=https://<project-ref>.supabase.co --dart-define=CHRONOSPARK_SUPABASE_ANON_KEY=<anon-key> --dart-define=CHRONOSPARK_OAUTH_REDIRECT_URL=https://<your-domain>/app/auth/callback --dart-define=CHRONOSPARK_GITHUB_OAUTH_REDIRECT_URL=https://<your-domain>/app/auth/callback`

## Android release and tester access

- Play Store production builds should be built from the production flavor with release signing.
- Mock login is intentionally disabled in production. It is only available in non-production builds when `CHRONOSPARK_ENABLE_MOCK_LOGIN=true` or `CHRONOSPARK_ENABLE_MOCK_MODE=true` is passed.
- Tester builds should use the QA flavor so the app treats them as non-production.
- Typical tester launch command:
  - `flutter run -d emulator-5554 --dart-define=CHRONOSPARK_APP_FLAVOR=qa --dart-define=CHRONOSPARK_ENABLE_MOCK_LOGIN=true --dart-define=CHRONOSPARK_ENABLE_TESTER_FULL_ACCESS=true --dart-define=CHRONOSPARK_ENABLE_CLOUD_SYNC=false`
- Mock login defaults to `mock@chronospark.app` unless `CHRONOSPARK_MOCK_LOGIN_EMAIL` and `CHRONOSPARK_MOCK_LOGIN_PASSWORD` are supplied.
- For Google Play upload, build a release AAB with your signed release keystore and verify the bundle version increments before each upload.

## App links and indexing

- Android App Links are declared for:
  - `https://ghostheart5.github.io/fantastic-guacamole/app/*`
  - `https://chronospark.app/app/*`
  - `https://www.chronospark.app/app/*`
- Digital association files are in `web/.well-known/`.
- Replace the placeholder values in:
  - `web/.well-known/assetlinks.json`
  - `web/.well-known/apple-app-site-association`
  before production rollout.
- For production enforcement, set:
  - `--dart-define=CHRONOSPARK_ENFORCE_PROD_READINESS=true`
  - `--dart-define=CHRONOSPARK_RECEIPT_VERIFY_ENDPOINT=https://<your-domain>/verify-receipt`
  - `--dart-define=CHRONOSPARK_AI_PROXY_ENDPOINT=https://<your-domain>/ai-proxy`
  - `--dart-define=CHRONOSPARK_ANDROID_SHA256_CERT=<release-cert-sha256>`
  - `--dart-define=CHRONOSPARK_IOS_TEAM_ID=<apple-team-id>`
- Security note: keep provider API secrets on your backend only; mobile/web clients now use authenticated user tokens for AI and receipt verification requests.
