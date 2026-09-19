# AXIOMARA

> **The Human Decision OS** — decide with evidence, act with control.

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev/)
[![Dart](https://github.com/ghostheart5/fantastic-guacamole/actions/workflows/dart.yml/badge.svg)](https://github.com/ghostheart5/fantastic-guacamole/actions/workflows/dart.yml)
[![Android](https://img.shields.io/badge/Android-API%2036-3DDC84?logo=android&logoColor=white)](android/)
[![License](https://img.shields.io/badge/License-MIT-5cf2b5.svg)](LICENSE)

Axiomara is a connected planning and decision-support system for real life. It brings tasks, goals, Daily Rhythms, notes, schedules, operating-state signals, strategic questions, possible trajectories, and visible progress into one user-controlled loop.

The product is currently in invited closed testing. Its public product site and required account information are available at **[ghostheart5.github.io/fantastic-guacamole](https://ghostheart5.github.io/fantastic-guacamole/)**.

## The operating model

```text
Capture → Connect → Decide → Execute → Reflect
```

Axiomara does not force every situation through one rigid workflow. Its systems remain connected so a person can enter where the real problem is:

| System | Role |
| --- | --- |
| **Nexus** | Current operating state, relevant signals, and a next move to review. |
| **Creator** | Structured capture for tasks, goals, Daily Rhythms, and notes. |
| **Timeline** | Scheduled action, sequence, conflicts, and history across time. |
| **Smart Planner** | Contextual planning assistance grounded in selected work and constraints. |
| **SI Console** | Deeper strategic investigation through intent, evidence, assumptions, and scenarios. |
| **Trajectory** | Forward-looking path comparison with visible uncertainty and trade-offs. |
| **Progression** | Evidence-backed XP, levels, streaks, momentum, and reflection. |
| **Signal Center** | Reviewable reminders, notifications, and system events. |
| **Control Layer** | Consent, privacy, account, notification, billing, and AI-credit boundaries. |

## Intelligence contract

Axiomara's intelligence surfaces are expected to:

1. understand the actual question;
2. use only relevant, permitted context;
3. separate evidence, assumptions, and uncertainty;
4. provide a concrete and realistic response;
5. preserve the person's authority to revise, reject, or act.

Guidance is decision support. It is not a guarantee, diagnosis, prediction, or substitute for qualified medical, legal, financial, mental-health, or emergency help.

## Trust principles

- **No ads.** Axiomara does not display ads or require anyone to watch an ad.
- **Explicit AI actions.** Enabled external AI actions identify what is sent and the expected credit cost before confirmation.
- **Human authority.** Recommendations remain reviewable guidance.
- **Clear account control.** Privacy, support, billing guidance, and deletion routes remain publicly available.
- **Evidence before release claims.** Source checks, build evidence, store state, and physical-device results are reported separately.

## Documentation

The product guide lives in the **[Axiomara Wiki](https://github.com/ghostheart5/fantastic-guacamole/wiki)**:

- [Overview](https://github.com/ghostheart5/fantastic-guacamole/wiki/Overview)
- [Getting Started](https://github.com/ghostheart5/fantastic-guacamole/wiki/Getting-Started)
- [Core Concepts](https://github.com/ghostheart5/fantastic-guacamole/wiki/Core-Concepts)
- [Nexus](https://github.com/ghostheart5/fantastic-guacamole/wiki/Nexus)
- [Creator](https://github.com/ghostheart5/fantastic-guacamole/wiki/Creator)
- [Timeline](https://github.com/ghostheart5/fantastic-guacamole/wiki/Timeline)
- [Smart Planner](https://github.com/ghostheart5/fantastic-guacamole/wiki/Smart-Planner)
- [SI Console](https://github.com/ghostheart5/fantastic-guacamole/wiki/SI-CONSOLE)
- [Trajectory](https://github.com/ghostheart5/fantastic-guacamole/wiki/Trajectory-Engine)
- [Progression](https://github.com/ghostheart5/fantastic-guacamole/wiki/Progression)

Architecture and engineering context are summarized in [AXIOMARA.md](AXIOMARA.md). Incident response and evidence boundaries are defined in [docs/INCIDENT_RESPONSE_RUNBOOK.md](docs/INCIDENT_RESPONSE_RUNBOOK.md).

## Development

Create the git-ignored local configuration file, install dependencies, and run the verified checks:

```bash
cp .env.example .env
flutter pub get
dart format --output=none --set-exit-if-changed lib test integration_test tool scripts
flutter analyze --fatal-infos
flutter test
flutter run -d windows --dart-define-from-file=.env
```

The repository contains the Flutter application, governed product assets, automated verification, backend integration sources, public policy pages, and release tooling.

## Compatibility identifiers

The existing Android application ID, deep links, database names, environment keys, and some internal paths retain legacy identifiers so installed tester builds can update safely and backend integrations remain compatible. Those identifiers are implementation contracts; the current public product name is **Axiomara**. Changing them requires a separately planned migration and cannot be treated as a cosmetic rename.

## License

Axiomara is licensed under the [MIT License](LICENSE).
