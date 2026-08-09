# ChronoSpark

[![Flutter](https://img.shields.io/badge/Flutter-3.12%2B-02569B?logo=flutter&logoColor=white)](https://flutter.dev/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Android](https://img.shields.io/badge/Android-Supported-3DDC84?logo=android&logoColor=white)](android/)

ChronoSpark is the product experience behind fantastic-guacamole: a Flutter-based personal operating system for planning, reflection, and focused execution. It blends adaptive task intelligence, temporal planning, creator workflows, and premium coaching surfaces into a single futuristic daily planner.

## What this app does

- Helps you shape the day around priorities, momentum, and context
- Supports timeline-based planning, milestone tracking, and temporal ops
- Offers creator workflows for structured entries and richer planning loops
- Surfaces SI guidance and coaching insights when you need decision support
- Includes subscription-aware flows for premium capabilities and local-first persistence

## Quick start

### Prerequisites

- Flutter SDK 3.12 or newer
- A device or emulator for Android, Windows, or web

### Install and run

```bash
git clone <repo-url>
cd fantastic-guacamole
flutter pub get
cp .env.example .env
flutter run -d <device>
```

For Windows local runs, this is also a common entry point:

```bash
flutter run -d windows
```

## Configuration

The app reads runtime values from [.env](.env.example) and supports a few build-time defines for Supabase, OAuth, and feature flags. At minimum, configure:

- CHRONOSPARK_SUPABASE_URL
- CHRONOSPARK_SUPABASE_ANON_KEY
- CHRONOSPARK_OAUTH_REDIRECT_URL
- CHRONOSPARK_PASSWORD_RECOVERY_REDIRECT_URL
- CHRONOSPARK_GITHUB_OAUTH_REDIRECT_URL

See [.env.example](.env.example) for the expected shape.

### Supabase Auth production setup

In Supabase Dashboard, configure a production SMTP provider or Send Email Auth
Hook. The default email provider only delivers to organization members. Set the
Site URL and redirect allowlist to the exact production values for
`CHRONOSPARK_OAUTH_REDIRECT_URL` and
`CHRONOSPARK_PASSWORD_RECOVERY_REDIRECT_URL`, including both the HTTPS App Link
and `chronospark://auth-callback` when those builds are distributed. Verify
signup confirmation and password recovery callbacks on a signed release build.

## Supabase ownership contract

ChronoSpark uses a strict platform boundary to avoid Firebase/Supabase overlap:

- Auth/session owner: Supabase Auth
- Primary app data owner: Supabase Postgres
- Cloud file/backup owner: Supabase Storage (`chronospark-sync` bucket)
- Serverless owner: Supabase Edge Functions
- Notifications/telemetry owner: Firebase (FCM, Analytics, Crashlytics)

### Supabase sync precedence contract

To keep restore behavior deterministic across devices:

- `syncToCloud` replays queued Supabase row mutations first, then uploads a backup snapshot.
- `restoreFromCloud` treats the downloaded snapshot as canonical for local state.
- After a successful restore, pending Supabase mutation queue entries are cleared to prevent replaying stale pre-restore writes.

## Development commands

```bash
flutter analyze
flutter test
flutter test --coverage
```

Useful test and quality commands:

```bash
flutter test test/golden
flutter test integration_test/patrol_smoke_test.dart
```

Coverage output can be turned into HTML with:

```bash
genhtml coverage/lcov.info -o coverage/html
```

## Documentation map

- Architecture reference: [CHRONOSPARK.md](CHRONOSPARK.md)
- Layering and dependency direction: [docs/LAYER_FLOW.md](docs/LAYER_FLOW.md)
- Build and release checks: [docs/BUILD_AUDIT_COMMANDS.md](docs/BUILD_AUDIT_COMMANDS.md)
- Release scorecard: [docs/FINAL_AUDIT_SCORECARD.md](docs/FINAL_AUDIT_SCORECARD.md)
- Additional audits and planning notes live in [docs](docs)

## Project structure

- [lib](lib) contains the app implementation and feature modules
- [assets](assets) holds animations, icons, fonts, tutorial content, and seed data
- [supabase](supabase) contains edge function and integration assets
- [test](test) and [integration_test](integration_test) hold automated coverage and smoke tests

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.
