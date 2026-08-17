# ChronoSpark

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev/)
[![Dart](https://github.com/ghostheart5/fantastic-guacamole/actions/workflows/dart.yml/badge.svg)](https://github.com/ghostheart5/fantastic-guacamole/actions/workflows/dart.yml)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Android](https://img.shields.io/badge/Android-Supported-3DDC84?logo=android&logoColor=white)](android/)

ChronoSpark is a planning and decision-support system for people who want to understand the day, decide the next move, and maintain momentum through deliberate action and reflection.

It connects planning inputs, scheduled work, and available guidance without treating every signal as an automatic conclusion. The user remains responsible for the choices they make.

## Product flow

The first-use path is:

```text
Creator → Timeline → Nexus
```

After setup, ChronoSpark supports a flexible working cycle:

1. **Orient in Nexus** — review the connected context available now.
2. **Create in Creator** — capture and manage tasks, goals, Daily Rhythms, and notes.
3. **Plan in Timeline** — plan and review scheduled action.
4. **Act deliberately** — follow through on the commitment you chose.
5. **Reflect and adjust** — retain useful context and choose the next change intentionally.

This is a planning cycle, not a promise that every day will be predictable or optimized.

## Core features

| Feature | Purpose |
| --- | --- |
| **Nexus** | Home surface for the current operating state and next-best action. |
| **Smart Planner** | Explainable planning guidance and plan reconciliation. |
| **Creator** | Structured intake for tasks, goals, Daily Rhythms, and notes. |
| **SI Console** | Explainable recommendations and deeper decision investigation. |
| **Timeline** | Planning and review of scheduled action and operational history. |
| **Trajectory Engine** | Forward-looking scenario comparison, assumptions, and corrections. |
| **Progression** | Evidence-backed advancement and leverage-action review. |

Smart Planner, SI Console, Trajectory Engine, and Progression provide guidance or context to evaluate. They do not replace the user's judgment or guarantee an outcome.

## Documentation

The current product guides are maintained in the [ChronoSpark GitHub Wiki](https://github.com/ghostheart5/fantastic-guacamole/wiki):

- [Overview](https://github.com/ghostheart5/fantastic-guacamole/wiki/Overview)
- [Getting Started](https://github.com/ghostheart5/fantastic-guacamole/wiki/Getting-Started)
- [Core Concepts](https://github.com/ghostheart5/fantastic-guacamole/wiki/Core-Concepts)
- [Nexus](https://github.com/ghostheart5/fantastic-guacamole/wiki/Nexus)
- [Creator](https://github.com/ghostheart5/fantastic-guacamole/wiki/Creator)
- [Timeline](https://github.com/ghostheart5/fantastic-guacamole/wiki/Timeline)
- [Smart Planner](https://github.com/ghostheart5/fantastic-guacamole/wiki/Smart-Planner)
- [SI Console](https://github.com/ghostheart5/fantastic-guacamole/wiki/SI-CONSOLE)
- [Trajectory Engine](https://github.com/ghostheart5/fantastic-guacamole/wiki/Trajectory-Engine)
- [Progression](https://github.com/ghostheart5/fantastic-guacamole/wiki/Progression)

Repository architecture and engineering context is summarized in [CHRONOSPARK.md](CHRONOSPARK.md).

## Development

### First-time setup

Create the local `.env` asset before running Flutter commands:

```bash
cp .env.example .env
flutter pub get
```

Every key may remain blank for local offline tests. See [.env.example](.env.example) for production integration values and build-time alternatives.

### Common commands

```bash
flutter analyze
flutter test
flutter run -d windows
```

## Project structure

- `lib/` contains the application, feature, state, data, and domain layers.
- `assets/` contains governed visual, audio, font, tutorial, and data assets.
- `test/` and `integration_test/` contain automated verification.
- `supabase/` contains database and Edge Function integration sources.
- `web/` contains canonical public support, privacy, terms, and account-deletion pages.

## License

ChronoSpark is licensed under the [MIT License](LICENSE).
