# fantastic-guacamole

[![Dart](https://github.com/ghostheart5/fantastic-guacamole/actions/workflows/dart.yml/badge.svg)](https://github.com/ghostheart5/fantastic-guacamole/actions/workflows/dart.yml)
[![Deploy Flutter Web to GitHub Pages](https://github.com/ghostheart5/fantastic-guacamole/actions/workflows/main.yml/badge.svg)](https://github.com/ghostheart5/fantastic-guacamole/actions/workflows/main.yml)
[![CodeQL](https://github.com/ghostheart5/fantastic-guacamole/actions/workflows/codeql.yml/badge.svg)](https://github.com/ghostheart5/fantastic-guacamole/actions/workflows/codeql.yml)
[![ChronoSpark Linux Tester Release](https://github.com/ghostheart5/fantastic-guacamole/actions/workflows/linux-release.yml/badge.svg)](https://github.com/ghostheart5/fantastic-guacamole/actions/workflows/linux-release.yml)

ChronoSpark is a Flutter-based second brain for task planning, adaptive learning, time-blocking, and AI-driven decision support.

For the full architecture and subsystem reference, see [CHRONOSPARK.md](CHRONOSPARK.md).
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
