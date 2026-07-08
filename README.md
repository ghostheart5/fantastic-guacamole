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
